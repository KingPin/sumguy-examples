// Package api is the HTTP/JSON layer shared by cmd/monolith and cmd/gateway.
package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"shopbench/cart"
	"shopbench/catalog"
	"shopbench/orders"
)

// Shop is what the handlers call: Local in the monolith, rpc.Gateway in the microservices.
type Shop interface {
	ListProducts(ctx context.Context, page int) ([]catalog.Product, error)
	GetProduct(ctx context.Context, id int64) (catalog.Product, error)
	AddItem(ctx context.Context, user, product int64, qty int32) (cart.Line, error)
	GetCart(ctx context.Context, user int64) (cart.Cart, error)
	Checkout(ctx context.Context, user int64) (orders.Result, error)
}

// Local wires the handlers straight to the domain packages (the monolith).
type Local struct {
	Catalog *catalog.Store
	Cart    *cart.Store
	Orders  *orders.Service
}

var _ Shop = Local{}

func (l Local) ListProducts(ctx context.Context, page int) ([]catalog.Product, error) {
	return l.Catalog.List(ctx, page)
}
func (l Local) GetProduct(ctx context.Context, id int64) (catalog.Product, error) {
	return l.Catalog.Get(ctx, id)
}
func (l Local) AddItem(ctx context.Context, user, product int64, qty int32) (cart.Line, error) {
	return l.Cart.Add(ctx, user, product, qty)
}
func (l Local) GetCart(ctx context.Context, user int64) (cart.Cart, error) {
	return l.Cart.Priced(ctx, user)
}
func (l Local) Checkout(ctx context.Context, user int64) (orders.Result, error) {
	return l.Orders.Checkout(ctx, user)
}

const maxPage = 1_000_000

func Handler(s Shop) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /products", func(w http.ResponseWriter, r *http.Request) {
		page, err := strconv.Atoi(r.URL.Query().Get("page"))
		if err != nil || page < 1 || page > maxPage {
			reply(w, 0, nil, errBadInput)
			return
		}
		ps, err := s.ListProducts(r.Context(), page)
		if ps == nil {
			ps = []catalog.Product{}
		}
		reply(w, http.StatusOK, map[string]any{"products": ps}, err)
	})
	mux.HandleFunc("GET /products/{id}", func(w http.ResponseWriter, r *http.Request) {
		id, ok := pathID(w, r, "id")
		if !ok {
			return
		}
		p, err := s.GetProduct(r.Context(), id)
		reply(w, http.StatusOK, p, err)
	})
	mux.HandleFunc("POST /cart/{user}/items", func(w http.ResponseWriter, r *http.Request) {
		user, ok := pathID(w, r, "user")
		if !ok {
			return
		}
		var body struct {
			ProductID int64 `json:"product_id"`
			Qty       int32 `json:"qty"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.ProductID < 1 {
			reply(w, 0, nil, errBadInput)
			return
		}
		l, err := s.AddItem(r.Context(), user, body.ProductID, body.Qty)
		reply(w, http.StatusOK, l, err)
	})
	mux.HandleFunc("GET /cart/{user}", func(w http.ResponseWriter, r *http.Request) {
		user, ok := pathID(w, r, "user")
		if !ok {
			return
		}
		c, err := s.GetCart(r.Context(), user)
		reply(w, http.StatusOK, c, err)
	})
	mux.HandleFunc("POST /checkout/{user}", func(w http.ResponseWriter, r *http.Request) {
		user, ok := pathID(w, r, "user")
		if !ok {
			return
		}
		res, err := s.Checkout(r.Context(), user)
		reply(w, http.StatusCreated, res, err)
	})
	return mux
}

var errBadInput = errors.New("bad input")

func pathID(w http.ResponseWriter, r *http.Request, name string) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue(name), 10, 64)
	if err != nil || id < 1 {
		reply(w, 0, nil, errBadInput)
		return 0, false
	}
	return id, true
}

func status(err error) int {
	var hs interface{ HTTPStatus() int }
	switch {
	case errors.As(err, &hs):
		return hs.HTTPStatus()
	case errors.Is(err, errBadInput), errors.Is(err, cart.ErrBadQty):
		return http.StatusBadRequest
	case errors.Is(err, catalog.ErrNotFound):
		return http.StatusNotFound
	case errors.Is(err, orders.ErrEmptyCart):
		return http.StatusConflict
	}
	return http.StatusInternalServerError
}

// reply writes v with code, or {"error": StatusText} when err is set, so both designs return identical bodies.
func reply(w http.ResponseWriter, code int, v any, err error) {
	if err != nil {
		code = status(err)
		v = map[string]string{"error": http.StatusText(code)}
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}
