package rpc_test

import (
	"context"
	"errors"
	"net"
	"net/http/httptest"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	"shopbench/api"
	"shopbench/cart"
	"shopbench/catalog"
	"shopbench/internal/pgtest"
	"shopbench/orders"
	"shopbench/rpc"
)

var ctx = context.Background()

func serve(t *testing.T, register func(*grpc.Server)) *grpc.ClientConn {
	lis := bufconn.Listen(1 << 20)
	s := grpc.NewServer()
	register(s)
	go s.Serve(lis)
	t.Cleanup(s.Stop)
	opts := append(rpc.DialOpts(), grpc.WithContextDialer(func(ctx context.Context, _ string) (net.Conn, error) {
		return lis.DialContext(ctx)
	}))
	cc, err := grpc.NewClient("passthrough:///bufnet", opts...)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cc.Close() })
	return cc
}

// gateway wires the full microservice graph over bufconn on one test database.
func gateway(t *testing.T) rpc.Gateway {
	pool := pgtest.New(t, "catalog.sql", "cart.sql", "orders.sql")
	catCC := serve(t, func(s *grpc.Server) {
		rpc.RegisterCatalogServer(s, &rpc.CatalogService{Store: &catalog.Store{DB: pool}})
	})
	prices := rpc.CatalogRemote{C: rpc.NewCatalogClient(catCC)}
	cartCC := serve(t, func(s *grpc.Server) {
		rpc.RegisterCartServer(s, &rpc.CartService{Store: &cart.Store{DB: pool, Prices: prices}})
	})
	ordCC := serve(t, func(s *grpc.Server) {
		rpc.RegisterOrdersServer(s, &rpc.OrdersService{Svc: &orders.Service{
			DB: pool, Prices: prices, Carts: rpc.CartRemote{C: rpc.NewCartClient(cartCC)}}})
	})
	return rpc.Gateway{Catalog: rpc.NewCatalogClient(catCC), Cart: rpc.NewCartClient(cartCC), Orders: rpc.NewOrdersClient(ordCC)}
}

func TestGatewayFlow(t *testing.T) {
	g := gateway(t)
	ps, err := g.ListProducts(ctx, 1)
	if err != nil || len(ps) != 20 || ps[0].ID != 1 {
		t.Fatalf("ListProducts = %d, %v", len(ps), err)
	}
	if ps, err := g.ListProducts(ctx, 501); err != nil || ps == nil || len(ps) != 0 {
		t.Fatalf("page 501 = %v, %v", ps, err)
	}
	if p, err := g.GetProduct(ctx, 42); err != nil || p.PriceCents != 1654 {
		t.Fatalf("GetProduct = %+v, %v", p, err)
	}
	g.AddItem(ctx, 900001, 42, 2)
	if l, err := g.AddItem(ctx, 900001, 42, 3); err != nil || l.Qty != 5 {
		t.Fatalf("AddItem = %+v, %v", l, err)
	}
	if c, err := g.GetCart(ctx, 900001); err != nil || c.TotalCents != 8270 || len(c.Items) != 1 {
		t.Fatalf("GetCart = %+v, %v", c, err)
	}
	if r, err := g.Checkout(ctx, 900001); err != nil || r.TotalCents != 8270 {
		t.Fatalf("Checkout = %+v, %v", r, err)
	}
	if c, err := g.GetCart(ctx, 900001); err != nil || c.Items == nil || len(c.Items) != 0 {
		t.Fatalf("cart after checkout = %+v, %v", c, err)
	}
}

func TestErrorMapping(t *testing.T) {
	g := gateway(t)
	if _, err := g.GetProduct(ctx, 99999); !errors.Is(err, catalog.ErrNotFound) {
		t.Errorf("GetProduct(99999) = %v", err)
	}
	if _, err := g.AddItem(ctx, 1, 1, 0); !errors.Is(err, cart.ErrBadQty) {
		t.Errorf("AddItem qty 0 = %v", err)
	}
	if _, err := g.Checkout(ctx, 2); !errors.Is(err, orders.ErrEmptyCart) {
		t.Errorf("empty Checkout = %v", err)
	}
}

func is502(t *testing.T, err error) {
	t.Helper()
	var hs interface{ HTTPStatus() int }
	if !errors.As(err, &hs) || hs.HTTPStatus() != 502 {
		t.Fatalf("err = %v, want an HTTPStatus() 502 error", err)
	}
}

func TestUnreachableIs502(t *testing.T) {
	cc, err := rpc.Dial("127.0.0.1:1")
	if err != nil {
		t.Fatal(err)
	}
	defer cc.Close()
	start := time.Now()
	_, err = rpc.Gateway{Catalog: rpc.NewCatalogClient(cc)}.GetProduct(ctx, 1)
	is502(t, err)
	if d := time.Since(start); d > 3*time.Second {
		t.Fatalf("took %v", d)
	}
}

type hang struct{ rpc.UnimplementedCatalogServer }

func (hang) GetProduct(ctx context.Context, _ *rpc.GetProductRequest) (*rpc.Product, error) {
	<-ctx.Done()
	return nil, ctx.Err()
}

func TestDeadlineIs502(t *testing.T) {
	cc := serve(t, func(s *grpc.Server) { rpc.RegisterCatalogServer(s, hang{}) })
	start := time.Now()
	_, err := rpc.Gateway{Catalog: rpc.NewCatalogClient(cc)}.GetProduct(ctx, 1)
	is502(t, err)
	if d := time.Since(start); d < 1900*time.Millisecond || d > 2500*time.Millisecond {
		t.Fatalf("took %v, want about 2 s", d)
	}
}

// failClear is a cart service whose Clear always fails, after the order has committed.
type failClear struct{ rpc.UnimplementedCartServer }

func (failClear) GetLines(context.Context, *rpc.UserRequest) (*rpc.CartLines, error) {
	return &rpc.CartLines{Lines: []*rpc.CartLine{{ProductId: 42, Qty: 2}}}, nil
}

func (failClear) Clear(context.Context, *rpc.UserRequest) (*rpc.Empty, error) {
	return nil, status.Error(codes.Unavailable, "cart down")
}

// A failed clear after commit is a 500 (ErrClearFailed), not a 502, and the order row stays.
func TestClearFailureAfterCommitIs500(t *testing.T) {
	pool := pgtest.New(t, "catalog.sql", "orders.sql")
	catCC := serve(t, func(s *grpc.Server) {
		rpc.RegisterCatalogServer(s, &rpc.CatalogService{Store: &catalog.Store{DB: pool}})
	})
	cartCC := serve(t, func(s *grpc.Server) { rpc.RegisterCartServer(s, failClear{}) })
	ordCC := serve(t, func(s *grpc.Server) {
		rpc.RegisterOrdersServer(s, &rpc.OrdersService{Svc: &orders.Service{
			DB: pool, Prices: rpc.CatalogRemote{C: rpc.NewCatalogClient(catCC)}, Carts: rpc.CartRemote{C: rpc.NewCartClient(cartCC)}}})
	})
	g := rpc.Gateway{Orders: rpc.NewOrdersClient(ordCC)}

	rec := httptest.NewRecorder()
	api.Handler(g).ServeHTTP(rec, httptest.NewRequest("POST", "/checkout/7", nil))
	if rec.Code != 500 {
		t.Fatalf("checkout status = %d (%s), want 500", rec.Code, rec.Body)
	}
	var n int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM orders WHERE user_id = 7`).Scan(&n); err != nil || n != 1 {
		t.Fatalf("orders rows = %d, %v, want 1", n, err)
	}
}
