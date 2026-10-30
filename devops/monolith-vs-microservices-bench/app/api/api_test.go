package api_test

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"shopbench/api"
	"shopbench/cart"
	"shopbench/catalog"
	"shopbench/orders"
)

type fake struct{ err error }

func (f fake) ListProducts(context.Context, int) ([]catalog.Product, error) { return nil, f.err }
func (f fake) GetProduct(context.Context, int64) (catalog.Product, error) {
	return catalog.Product{ID: 1}, f.err
}
func (f fake) AddItem(_ context.Context, _, p int64, q int32) (cart.Line, error) {
	return cart.Line{ProductID: p, Qty: q}, f.err
}
func (f fake) GetCart(context.Context, int64) (cart.Cart, error) {
	return cart.Cart{Items: []cart.PricedLine{}}, f.err
}
func (f fake) Checkout(context.Context, int64) (orders.Result, error) {
	return orders.Result{OrderID: 1, TotalCents: 5}, f.err
}

type badGateway struct{}

func (badGateway) Error() string   { return "upstream" }
func (badGateway) HTTPStatus() int { return http.StatusBadGateway }

func TestRoutes(t *testing.T) {
	const bad = `{"error":"Bad Request"}`
	cases := []struct {
		err                error
		method, path, body string
		code               int
		want               string
	}{
		{nil, "GET", "/products?page=1", "", 200, `{"products":[]}`},
		{nil, "GET", "/products?page=0", "", 400, bad},
		{nil, "GET", "/products?page=x", "", 400, bad},
		{nil, "GET", "/products", "", 400, bad},
		{nil, "GET", "/products?page=1000001", "", 400, bad},
		{nil, "GET", "/products/abc", "", 400, bad},
		{catalog.ErrNotFound, "GET", "/products/9", "", 404, `{"error":"Not Found"}`},
		{nil, "POST", "/cart/7/items", `{"product_id":42,"qty":2}`, 200, `{"product_id":42,"qty":2}`},
		{nil, "POST", "/cart/7/items", `not json`, 400, bad},
		{nil, "POST", "/cart/7/items", `{"product_id":0,"qty":2}`, 400, bad},
		{nil, "POST", "/cart/0/items", `{"product_id":1,"qty":2}`, 400, bad},
		{cart.ErrBadQty, "POST", "/cart/7/items", `{"product_id":42,"qty":11}`, 400, bad},
		{nil, "GET", "/cart/7", "", 200, `{"items":[],"total_cents":0}`},
		{nil, "POST", "/checkout/7", "", 201, `{"order_id":1,"total_cents":5}`},
		{orders.ErrEmptyCart, "POST", "/checkout/7", "", 409, `{"error":"Conflict"}`},
		{fmt.Errorf("%w: x", orders.ErrClearFailed), "POST", "/checkout/7", "", 500, `{"error":"Internal Server Error"}`},
		{badGateway{}, "GET", "/products/1", "", 502, `{"error":"Bad Gateway"}`},
	}
	for _, c := range cases {
		w := httptest.NewRecorder()
		api.Handler(fake{c.err}).ServeHTTP(w, httptest.NewRequest(c.method, c.path, strings.NewReader(c.body)))
		if got := strings.TrimSpace(w.Body.String()); w.Code != c.code || got != c.want {
			t.Errorf("%s %s (err %v): got %d %s, want %d %s", c.method, c.path, c.err, w.Code, got, c.code, c.want)
		}
	}
}
