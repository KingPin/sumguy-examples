package orders_test

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"shopbench/cart"
	"shopbench/catalog"
	"shopbench/internal/pgtest"
	"shopbench/orders"
)

var ctx = context.Background()

func setup(t *testing.T) (*pgxpool.Pool, *catalog.Store, *cart.Store) {
	pool := pgtest.New(t, "catalog.sql", "cart.sql", "orders.sql")
	cat := &catalog.Store{DB: pool}
	return pool, cat, &cart.Store{DB: pool, Prices: cat}
}

func count(t *testing.T, pool *pgxpool.Pool, sql string, args ...any) int {
	var n int
	if err := pool.QueryRow(ctx, sql, args...).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func TestCheckout(t *testing.T) {
	for _, shared := range []bool{true, false} {
		t.Run(fmt.Sprint("shared=", shared), func(t *testing.T) {
			pool, cat, crt := setup(t)
			o := &orders.Service{DB: pool, Prices: cat, Carts: crt, SharedDB: shared}
			if _, err := o.Checkout(ctx, 9); !errors.Is(err, orders.ErrEmptyCart) {
				t.Fatalf("empty checkout err = %v", err)
			}
			if n := count(t, pool, `SELECT count(*) FROM orders`); n != 0 {
				t.Fatalf("empty checkout wrote %d orders", n)
			}
			crt.Add(ctx, 9, 42, 2)
			r, err := o.Checkout(ctx, 9)
			if err != nil || r.OrderID == 0 || r.TotalCents != 3308 {
				t.Fatalf("checkout = %+v, %v", r, err)
			}
			if n := count(t, pool, `SELECT count(*) FROM order_items WHERE order_id = $1 AND product_id = 42 AND qty = 2 AND price_cents = 1654`, r.OrderID); n != 1 {
				t.Fatalf("order_items rows = %d", n)
			}
			if n := count(t, pool, `SELECT count(*) FROM cart_items WHERE user_id = 9`); n != 0 {
				t.Fatalf("cart still has %d rows", n)
			}
		})
	}
}

type failClear struct{ *cart.Store }

func (failClear) Clear(context.Context, int64) error { return errors.New("cart service down") }

func TestClearFailureKeepsOrder(t *testing.T) {
	pool, cat, crt := setup(t)
	o := &orders.Service{DB: pool, Prices: cat, Carts: failClear{crt}}
	crt.Add(ctx, 9, 42, 1)
	r, err := o.Checkout(ctx, 9)
	if !errors.Is(err, orders.ErrClearFailed) {
		t.Fatalf("err = %v, want ErrClearFailed", err)
	}
	if n := count(t, pool, `SELECT count(*) FROM orders WHERE id = $1`, r.OrderID); n != 1 {
		t.Fatalf("order rows = %d, want 1", n)
	}
}

// More concurrent monolith checkouts than pool connections must all finish: a checkout
// that took a second connection inside its transaction would deadlock here.
func TestSharedCheckoutSmallPool(t *testing.T) {
	pool, _, crt := setup(t)
	cfg := pool.Config()
	cfg.MaxConns = 2
	small, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer small.Close()
	o := &orders.Service{DB: small, Prices: &catalog.Store{DB: small}, Carts: crt, SharedDB: true}
	c, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	errs := make(chan error, 8)
	for u := int64(100); u < 108; u++ {
		crt.Add(ctx, u, 42, 1)
		go func() { _, err := o.Checkout(c, u); errs <- err }()
	}
	for range 8 {
		if err := <-errs; err != nil {
			t.Fatalf("checkout with pool max 2: %v", err)
		}
	}
}
