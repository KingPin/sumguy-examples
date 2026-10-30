package rpc

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"

	"shopbench/api"
	"shopbench/cart"
	"shopbench/catalog"
	"shopbench/orders"
)

const callTimeout = 2 * time.Second

// upstreamError is a transport failure (unreachable, deadline, unavailable). The api layer answers 502.
type upstreamError struct{ err error }

func (e *upstreamError) Error() string   { return "upstream: " + e.err.Error() }
func (e *upstreamError) HTTPStatus() int { return http.StatusBadGateway }

func fromStatus(err error) error {
	switch status.Code(err) {
	case codes.NotFound:
		return catalog.ErrNotFound
	case codes.InvalidArgument:
		return cart.ErrBadQty
	case codes.FailedPrecondition:
		return orders.ErrEmptyCart
	case codes.Internal:
		return errors.New(status.Convert(err).Message())
	}
	return &upstreamError{err}
}

// DialOpts: plaintext, and a 2 s deadline on every call. No retries.
func DialOpts() []grpc.DialOption {
	return []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithUnaryInterceptor(func(ctx context.Context, method string, req, reply any,
			cc *grpc.ClientConn, invoker grpc.UnaryInvoker, opts ...grpc.CallOption) error {
			ctx, cancel := context.WithTimeout(ctx, callTimeout)
			defer cancel()
			return invoker(ctx, method, req, reply, cc, opts...)
		}),
	}
}

// Dial opens one lazily connected ClientConn per target; HTTP/2 multiplexes the calls.
func Dial(addr string) (*grpc.ClientConn, error) { return grpc.NewClient(addr, DialOpts()...) }

// MustDial dials the address in env var key or exits.
func MustDial(key string) *grpc.ClientConn {
	addr := os.Getenv(key)
	if addr == "" {
		log.Fatalf("%s is not set", key)
	}
	cc, err := Dial(addr)
	if err != nil {
		log.Fatal(err)
	}
	return cc
}

func productFromPB(p *Product) catalog.Product {
	return catalog.Product{ID: p.Id, Name: p.Name, Description: p.Description, PriceCents: p.PriceCents, Stock: p.Stock}
}

func lineFromPB(l *CartLine) cart.Line { return cart.Line{ProductID: l.ProductId, Qty: l.Qty} }

// CatalogRemote is the gRPC PriceLookup used by the cart and orders services.
type CatalogRemote struct{ C CatalogClient }

func (r CatalogRemote) GetPrices(ctx context.Context, ids []int64) (map[int64]int64, error) {
	p, err := r.C.GetPrices(ctx, &GetPricesRequest{Ids: ids})
	if err != nil {
		return nil, fromStatus(err)
	}
	return p.Cents, nil
}

// CartRemote is the gRPC CartStore used by the orders service.
type CartRemote struct{ C CartClient }

func (r CartRemote) Get(ctx context.Context, user int64) ([]cart.Line, error) {
	ls, err := r.C.GetLines(ctx, &UserRequest{User: user})
	if err != nil {
		return nil, fromStatus(err)
	}
	out := make([]cart.Line, len(ls.Lines))
	for i, l := range ls.Lines {
		out[i] = lineFromPB(l)
	}
	return out, nil
}

func (r CartRemote) Clear(ctx context.Context, user int64) error {
	if _, err := r.C.Clear(ctx, &UserRequest{User: user}); err != nil {
		return fromStatus(err)
	}
	return nil
}

// Gateway implements api.Shop over gRPC (the microservices).
type Gateway struct {
	Catalog CatalogClient
	Cart    CartClient
	Orders  OrdersClient
}

var _ api.Shop = Gateway{}

func (g Gateway) ListProducts(ctx context.Context, page int) ([]catalog.Product, error) {
	r, err := g.Catalog.ListProducts(ctx, &ListProductsRequest{Page: int32(page)})
	if err != nil {
		return nil, fromStatus(err)
	}
	out := make([]catalog.Product, len(r.Products))
	for i, p := range r.Products {
		out[i] = productFromPB(p)
	}
	return out, nil
}

func (g Gateway) GetProduct(ctx context.Context, id int64) (catalog.Product, error) {
	p, err := g.Catalog.GetProduct(ctx, &GetProductRequest{Id: id})
	if err != nil {
		return catalog.Product{}, fromStatus(err)
	}
	return productFromPB(p), nil
}

func (g Gateway) AddItem(ctx context.Context, user, product int64, qty int32) (cart.Line, error) {
	l, err := g.Cart.AddItem(ctx, &AddItemRequest{User: user, ProductId: product, Qty: qty})
	if err != nil {
		return cart.Line{}, fromStatus(err)
	}
	return lineFromPB(l), nil
}

func (g Gateway) GetCart(ctx context.Context, user int64) (cart.Cart, error) {
	c, err := g.Cart.GetCart(ctx, &UserRequest{User: user})
	if err != nil {
		return cart.Cart{}, fromStatus(err)
	}
	out := cart.Cart{TotalCents: c.TotalCents, Items: make([]cart.PricedLine, len(c.Items))}
	for i, l := range c.Items {
		out.Items[i] = cart.PricedLine{ProductID: l.ProductId, Qty: l.Qty, PriceCents: l.PriceCents}
	}
	return out, nil
}

func (g Gateway) Checkout(ctx context.Context, user int64) (orders.Result, error) {
	r, err := g.Orders.Checkout(ctx, &UserRequest{User: user})
	if err != nil {
		return orders.Result{}, fromStatus(err)
	}
	return orders.Result{OrderID: r.OrderId, TotalCents: r.TotalCents}, nil
}
