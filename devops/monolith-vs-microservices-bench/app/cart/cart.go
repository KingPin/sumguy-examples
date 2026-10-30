// Package cart owns the cart_items table.
package cart

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrBadQty = errors.New("qty must be 1-10")

type Line struct {
	ProductID int64 `json:"product_id"`
	Qty       int32 `json:"qty"`
}

type PricedLine struct {
	ProductID  int64 `json:"product_id"`
	Qty        int32 `json:"qty"`
	PriceCents int64 `json:"price_cents"`
}

type Cart struct {
	Items      []PricedLine `json:"items"`
	TotalCents int64        `json:"total_cents"`
}

// PriceLookup is the catalog seam: the catalog package in the monolith, a gRPC client in the microservices.
type PriceLookup interface {
	GetPrices(ctx context.Context, ids []int64) (map[int64]int64, error)
}

// Querier is satisfied by *pgxpool.Pool and pgx.Tx, so the monolith can read and clear inside its checkout transaction.
type Querier interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

type Store struct {
	DB     *pgxpool.Pool
	Prices PriceLookup
}

// Add adds qty to the user's line for product and returns the new total qty.
func (s *Store) Add(ctx context.Context, user, product int64, qty int32) (Line, error) {
	if qty < 1 || qty > 10 {
		return Line{}, ErrBadQty
	}
	l := Line{ProductID: product}
	err := s.DB.QueryRow(ctx, `INSERT INTO cart_items (user_id, product_id, qty) VALUES ($1, $2, $3)
		ON CONFLICT (user_id, product_id) DO UPDATE SET qty = cart_items.qty + EXCLUDED.qty
		RETURNING qty`, user, product, qty).Scan(&l.Qty)
	return l, err
}

func GetLines(ctx context.Context, q Querier, user int64) ([]Line, error) {
	rows, err := q.Query(ctx, `SELECT product_id, qty FROM cart_items WHERE user_id = $1 ORDER BY product_id`, user)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByPos[Line])
}

func ClearLines(ctx context.Context, q Querier, user int64) error {
	_, err := q.Exec(ctx, `DELETE FROM cart_items WHERE user_id = $1`, user)
	return err
}

func (s *Store) Get(ctx context.Context, user int64) ([]Line, error) {
	return GetLines(ctx, s.DB, user)
}
func (s *Store) Clear(ctx context.Context, user int64) error { return ClearLines(ctx, s.DB, user) }

// Priced returns the cart with current prices. An empty cart skips the price lookup.
func (s *Store) Priced(ctx context.Context, user int64) (Cart, error) {
	c := Cart{Items: []PricedLine{}}
	lines, err := s.Get(ctx, user)
	if err != nil || len(lines) == 0 {
		return c, err
	}
	ids := make([]int64, len(lines))
	for i, l := range lines {
		ids[i] = l.ProductID
	}
	prices, err := s.Prices.GetPrices(ctx, ids)
	if err != nil {
		return Cart{}, err
	}
	for _, l := range lines {
		p := prices[l.ProductID]
		c.Items = append(c.Items, PricedLine{ProductID: l.ProductID, Qty: l.Qty, PriceCents: p})
		c.TotalCents += p * int64(l.Qty)
	}
	return c, nil
}
