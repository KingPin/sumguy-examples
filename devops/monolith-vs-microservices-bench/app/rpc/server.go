package rpc

import (
	"context"
	"errors"
	"log"
	"net"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"shopbench/cart"
	"shopbench/catalog"
	"shopbench/internal/run"
	"shopbench/orders"
)

// Serve runs a gRPC server on LISTEN (default :9090) until SIGTERM or SIGINT.
func Serve(register func(*grpc.Server)) {
	lis, err := net.Listen("tcp", run.Env("LISTEN", ":9090"))
	if err != nil {
		log.Fatal(err)
	}
	s := grpc.NewServer()
	register(s)
	go func() {
		if err := s.Serve(lis); err != nil {
			log.Fatal(err)
		}
	}()
	run.Wait()
	s.GracefulStop()
}

// toStatus turns domain errors into gRPC codes. Client-side, fromStatus turns them back.
func toStatus(err error) error {
	var up *upstreamError
	switch {
	case errors.Is(err, catalog.ErrNotFound):
		return status.Error(codes.NotFound, err.Error())
	case errors.Is(err, cart.ErrBadQty):
		return status.Error(codes.InvalidArgument, err.Error())
	case errors.Is(err, orders.ErrEmptyCart):
		return status.Error(codes.FailedPrecondition, err.Error())
	case errors.As(err, &up): // a hop further down failed in transport: keep it a 502 at the gateway
		return status.Error(codes.Unavailable, err.Error())
	}
	return status.Error(codes.Internal, err.Error())
}

func productPB(p catalog.Product) *Product {
	return &Product{Id: p.ID, Name: p.Name, Description: p.Description, PriceCents: p.PriceCents, Stock: p.Stock}
}

func linePB(l cart.Line) *CartLine { return &CartLine{ProductId: l.ProductID, Qty: l.Qty} }

type CatalogService struct {
	UnimplementedCatalogServer
	Store *catalog.Store
}

func (s *CatalogService) ListProducts(ctx context.Context, r *ListProductsRequest) (*ProductList, error) {
	ps, err := s.Store.List(ctx, int(r.Page))
	if err != nil {
		return nil, toStatus(err)
	}
	out := &ProductList{Products: make([]*Product, len(ps))}
	for i, p := range ps {
		out.Products[i] = productPB(p)
	}
	return out, nil
}

func (s *CatalogService) GetProduct(ctx context.Context, r *GetProductRequest) (*Product, error) {
	p, err := s.Store.Get(ctx, r.Id)
	if err != nil {
		return nil, toStatus(err)
	}
	return productPB(p), nil
}

func (s *CatalogService) GetPrices(ctx context.Context, r *GetPricesRequest) (*Prices, error) {
	m, err := s.Store.GetPrices(ctx, r.Ids)
	if err != nil {
		return nil, toStatus(err)
	}
	return &Prices{Cents: m}, nil
}

type CartService struct {
	UnimplementedCartServer
	Store *cart.Store
}

func (s *CartService) AddItem(ctx context.Context, r *AddItemRequest) (*CartLine, error) {
	l, err := s.Store.Add(ctx, r.User, r.ProductId, r.Qty)
	if err != nil {
		return nil, toStatus(err)
	}
	return linePB(l), nil
}

func (s *CartService) GetLines(ctx context.Context, r *UserRequest) (*CartLines, error) {
	lines, err := s.Store.Get(ctx, r.User)
	if err != nil {
		return nil, toStatus(err)
	}
	out := &CartLines{Lines: make([]*CartLine, len(lines))}
	for i, l := range lines {
		out.Lines[i] = linePB(l)
	}
	return out, nil
}

func (s *CartService) GetCart(ctx context.Context, r *UserRequest) (*PricedCart, error) {
	c, err := s.Store.Priced(ctx, r.User)
	if err != nil {
		return nil, toStatus(err)
	}
	out := &PricedCart{TotalCents: c.TotalCents, Items: make([]*PricedLine, len(c.Items))}
	for i, l := range c.Items {
		out.Items[i] = &PricedLine{ProductId: l.ProductID, Qty: l.Qty, PriceCents: l.PriceCents}
	}
	return out, nil
}

func (s *CartService) Clear(ctx context.Context, r *UserRequest) (*Empty, error) {
	if err := s.Store.Clear(ctx, r.User); err != nil {
		return nil, toStatus(err)
	}
	return &Empty{}, nil
}

type OrdersService struct {
	UnimplementedOrdersServer
	Svc *orders.Service
}

func (s *OrdersService) Checkout(ctx context.Context, r *UserRequest) (*CheckoutResult, error) {
	res, err := s.Svc.Checkout(ctx, r.User)
	if err != nil {
		return nil, toStatus(err)
	}
	return &CheckoutResult{OrderId: res.OrderID, TotalCents: res.TotalCents}, nil
}
