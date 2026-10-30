package catalog_test

import (
	"context"
	"errors"
	"maps"
	"testing"

	"shopbench/catalog"
	"shopbench/internal/pgtest"
)

var ctx = context.Background()

func TestList(t *testing.T) {
	s := &catalog.Store{DB: pgtest.New(t, "catalog.sql")}
	ps, err := s.List(ctx, 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(ps) != 20 {
		t.Fatalf("page 1: %d rows, want 20", len(ps))
	}
	if ps[0].ID != 1 || ps[19].ID != 20 || len(ps[0].Description) != 200 {
		t.Fatalf("page 1: first id %d, last id %d, desc len %d", ps[0].ID, ps[19].ID, len(ps[0].Description))
	}
	ps, err = s.List(ctx, 501)
	if err != nil || ps == nil || len(ps) != 0 {
		t.Fatalf("page 501 = %v, %v; want empty non-nil slice", ps, err)
	}
}

func TestGet(t *testing.T) {
	s := &catalog.Store{DB: pgtest.New(t, "catalog.sql")}
	p, err := s.Get(ctx, 42)
	if err != nil || p.PriceCents != 1654 || p.Name != "Product 42" {
		t.Fatalf("Get(42) = %+v, %v", p, err)
	}
	if _, err := s.Get(ctx, 99999); !errors.Is(err, catalog.ErrNotFound) {
		t.Fatalf("Get(99999) err = %v, want ErrNotFound", err)
	}
}

func TestGetPrices(t *testing.T) {
	s := &catalog.Store{DB: pgtest.New(t, "catalog.sql")}
	m, err := s.GetPrices(ctx, []int64{1, 42, 99999})
	if want := map[int64]int64{1: 137, 42: 1654}; err != nil || !maps.Equal(m, want) {
		t.Fatalf("GetPrices = %v, %v; want %v", m, err, want)
	}
}
