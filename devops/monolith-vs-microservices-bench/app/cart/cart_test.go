package cart_test

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"shopbench/cart"
	"shopbench/internal/pgtest"
)

var ctx = context.Background()

type countingPrices struct {
	calls int
	m     map[int64]int64
}

func (c *countingPrices) GetPrices(context.Context, []int64) (map[int64]int64, error) {
	c.calls++
	return c.m, nil
}

func TestAddIncrements(t *testing.T) {
	s := &cart.Store{DB: pgtest.New(t, "cart.sql")}
	if l, err := s.Add(ctx, 7, 42, 2); err != nil || l != (cart.Line{ProductID: 42, Qty: 2}) {
		t.Fatalf("first add = %+v, %v", l, err)
	}
	if l, err := s.Add(ctx, 7, 42, 3); err != nil || l.Qty != 5 {
		t.Fatalf("second add = %+v, %v; want qty 5", l, err)
	}
}

func TestAddRejectsBadQty(t *testing.T) {
	s := &cart.Store{DB: pgtest.New(t, "cart.sql")}
	for _, q := range []int32{0, -1, 11} {
		if _, err := s.Add(ctx, 7, 42, q); !errors.Is(err, cart.ErrBadQty) {
			t.Fatalf("qty %d: err = %v, want ErrBadQty", q, err)
		}
	}
	if lines, _ := s.Get(ctx, 7); len(lines) != 0 {
		t.Fatalf("bad adds wrote rows: %v", lines)
	}
}

func TestPriced(t *testing.T) {
	p := &countingPrices{m: map[int64]int64{7: 359, 42: 1654}}
	s := &cart.Store{DB: pgtest.New(t, "cart.sql"), Prices: p}
	c, err := s.Priced(ctx, 5)
	if err != nil || c.Items == nil || len(c.Items) != 0 || c.TotalCents != 0 || p.calls != 0 {
		t.Fatalf("empty cart = %+v, %v, %d price calls", c, err, p.calls)
	}
	s.Add(ctx, 5, 42, 2)
	s.Add(ctx, 5, 7, 1)
	c, err = s.Priced(ctx, 5)
	want := cart.Cart{Items: []cart.PricedLine{{ProductID: 7, Qty: 1, PriceCents: 359}, {ProductID: 42, Qty: 2, PriceCents: 1654}}, TotalCents: 359 + 2*1654}
	if err != nil || !reflect.DeepEqual(c, want) {
		t.Fatalf("Priced = %+v, %v; want %+v", c, err, want)
	}
}

func TestClear(t *testing.T) {
	s := &cart.Store{DB: pgtest.New(t, "cart.sql")}
	s.Add(ctx, 3, 1, 1)
	if err := s.Clear(ctx, 3); err != nil {
		t.Fatal(err)
	}
	if lines, _ := s.Get(ctx, 3); len(lines) != 0 {
		t.Fatalf("cart not cleared: %v", lines)
	}
}
