// Package catalog owns the products table.
package catalog

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("product not found")

const PageSize = 20

type Product struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	PriceCents  int64  `json:"price_cents"`
	Stock       int32  `json:"stock"`
}

type Store struct{ DB *pgxpool.Pool }

func (s *Store) List(ctx context.Context, page int) ([]Product, error) {
	rows, err := s.DB.Query(ctx, `SELECT id, name, description, price_cents, stock
		FROM products ORDER BY id LIMIT $1 OFFSET $2`, PageSize, (page-1)*PageSize)
	if err != nil {
		return nil, err
	}
	ps, err := pgx.CollectRows(rows, pgx.RowToStructByPos[Product])
	if ps == nil {
		ps = []Product{}
	}
	return ps, err
}

func (s *Store) Get(ctx context.Context, id int64) (Product, error) {
	rows, _ := s.DB.Query(ctx, `SELECT id, name, description, price_cents, stock FROM products WHERE id = $1`, id)
	p, err := pgx.CollectExactlyOneRow(rows, pgx.RowToStructByPos[Product])
	if errors.Is(err, pgx.ErrNoRows) {
		return Product{}, ErrNotFound
	}
	return p, err
}

// GetPrices returns price_cents by id. Unknown ids are left out.
func (s *Store) GetPrices(ctx context.Context, ids []int64) (map[int64]int64, error) {
	return PricesIn(ctx, s.DB, ids)
}

// PricesIn is GetPrices on q: the pool, or the monolith's checkout transaction, so a
// checkout never needs a second connection while it holds one.
func PricesIn(ctx context.Context, q interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
}, ids []int64) (map[int64]int64, error) {
	rows, err := q.Query(ctx, `SELECT id, price_cents FROM products WHERE id = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	m := make(map[int64]int64, len(ids))
	for rows.Next() {
		var id, cents int64
		if err := rows.Scan(&id, &cents); err != nil {
			return nil, err
		}
		m[id] = cents
	}
	return m, rows.Err()
}
