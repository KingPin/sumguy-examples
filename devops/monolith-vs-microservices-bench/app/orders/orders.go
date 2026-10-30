// Package orders owns the orders and order_items tables.
package orders

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"shopbench/cart"
	"shopbench/catalog"
)

var (
	ErrEmptyCart   = errors.New("cart is empty")
	ErrClearFailed = errors.New("order saved but cart clear failed")
)

type PriceLookup interface {
	GetPrices(ctx context.Context, ids []int64) (map[int64]int64, error)
}

// CartStore is the cart seam: the cart package in the monolith, a gRPC client in the microservices.
type CartStore interface {
	Get(ctx context.Context, user int64) ([]cart.Line, error)
	Clear(ctx context.Context, user int64) error
}

type Result struct {
	OrderID    int64 `json:"order_id"`
	TotalCents int64 `json:"total_cents"`
}

type Service struct {
	DB     *pgxpool.Pool
	Prices PriceLookup
	Carts  CartStore
	// SharedDB is the monolith: cart_items sits in the same database, so the cart is
	// read and cleared inside the order transaction instead of through Carts.
	SharedDB bool
}

func (s *Service) Checkout(ctx context.Context, user int64) (Result, error) {
	if s.SharedDB {
		return s.checkoutShared(ctx, user)
	}
	lines, err := s.Carts.Get(ctx, user)
	if err != nil {
		return Result{}, err
	}
	if len(lines) == 0 {
		return Result{}, ErrEmptyCart
	}
	prices, err := s.Prices.GetPrices(ctx, ids(lines))
	if err != nil {
		return Result{}, err
	}
	var res Result
	err = pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) (err error) {
		res, err = insertOrder(ctx, tx, user, lines, prices)
		return err
	})
	if err != nil {
		return Result{}, err
	}
	// The order is committed. No retry: a failed clear leaves the cart and reports an error.
	if err := s.Carts.Clear(ctx, user); err != nil {
		return res, fmt.Errorf("%w: %v", ErrClearFailed, err)
	}
	return res, nil
}

func (s *Service) checkoutShared(ctx context.Context, user int64) (res Result, err error) {
	err = pgx.BeginFunc(ctx, s.DB, func(tx pgx.Tx) error {
		lines, err := cart.GetLines(ctx, tx, user)
		if err != nil {
			return err
		}
		if len(lines) == 0 {
			return ErrEmptyCart
		}
		prices, err := catalog.PricesIn(ctx, tx, ids(lines)) // same connection: no second acquire
		if err != nil {
			return err
		}
		if res, err = insertOrder(ctx, tx, user, lines, prices); err != nil {
			return err
		}
		return cart.ClearLines(ctx, tx, user)
	})
	return res, err
}

func insertOrder(ctx context.Context, tx pgx.Tx, user int64, lines []cart.Line, prices map[int64]int64) (Result, error) {
	var r Result
	for _, l := range lines {
		r.TotalCents += prices[l.ProductID] * int64(l.Qty)
	}
	if err := tx.QueryRow(ctx, `INSERT INTO orders (user_id, total_cents) VALUES ($1, $2) RETURNING id`,
		user, r.TotalCents).Scan(&r.OrderID); err != nil {
		return Result{}, err
	}
	for _, l := range lines {
		if _, err := tx.Exec(ctx, `INSERT INTO order_items (order_id, product_id, qty, price_cents) VALUES ($1, $2, $3, $4)`,
			r.OrderID, l.ProductID, l.Qty, prices[l.ProductID]); err != nil {
			return Result{}, err
		}
	}
	return r, nil
}

func ids(lines []cart.Line) []int64 {
	out := make([]int64, len(lines))
	for i, l := range lines {
		out[i] = l.ProductID
	}
	return out
}
