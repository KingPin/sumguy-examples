// Command cart serves the cart domain over gRPC. Prices come from the catalog service.
package main

import (
	"google.golang.org/grpc"

	"shopbench/cart"
	"shopbench/internal/run"
	"shopbench/rpc"
)

func main() {
	run.Start("cart")
	pool := run.Pool(10)
	prices := rpc.CatalogRemote{C: rpc.NewCatalogClient(rpc.MustDial("CATALOG_ADDR"))}
	rpc.Serve(func(s *grpc.Server) {
		rpc.RegisterCartServer(s, &rpc.CartService{Store: &cart.Store{DB: pool, Prices: prices}})
	})
	run.PoolStats("cart", pool)
}
