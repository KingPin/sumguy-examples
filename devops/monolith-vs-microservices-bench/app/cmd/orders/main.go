// Command orders serves checkout over gRPC, calling the catalog and cart services.
package main

import (
	"google.golang.org/grpc"

	"shopbench/internal/run"
	"shopbench/orders"
	"shopbench/rpc"
)

func main() {
	run.Start("orders")
	pool := run.Pool(10)
	svc := &orders.Service{
		DB:     pool,
		Prices: rpc.CatalogRemote{C: rpc.NewCatalogClient(rpc.MustDial("CATALOG_ADDR"))},
		Carts:  rpc.CartRemote{C: rpc.NewCartClient(rpc.MustDial("CART_ADDR"))},
	}
	rpc.Serve(func(s *grpc.Server) { rpc.RegisterOrdersServer(s, &rpc.OrdersService{Svc: svc}) })
	run.PoolStats("orders", pool)
}
