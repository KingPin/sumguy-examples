// Command monolith serves the shop API with direct calls between domain packages.
package main

import (
	"shopbench/api"
	"shopbench/cart"
	"shopbench/catalog"
	"shopbench/internal/run"
	"shopbench/orders"
)

func main() {
	run.Start("monolith")
	pool := run.Pool(30)
	cat := &catalog.Store{DB: pool}
	crt := &cart.Store{DB: pool, Prices: cat}
	ord := &orders.Service{DB: pool, Prices: cat, Carts: crt, SharedDB: true}
	run.HTTP(api.Handler(api.Local{Catalog: cat, Cart: crt, Orders: ord}))
	run.PoolStats("shop", pool)
}
