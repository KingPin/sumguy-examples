// Command gateway serves the shop API by calling the catalog, cart, and orders services over gRPC.
package main

import (
	"shopbench/api"
	"shopbench/internal/run"
	"shopbench/rpc"
)

func main() {
	run.Start("gateway")
	run.HTTP(api.Handler(rpc.Gateway{
		Catalog: rpc.NewCatalogClient(rpc.MustDial("CATALOG_ADDR")),
		Cart:    rpc.NewCartClient(rpc.MustDial("CART_ADDR")),
		Orders:  rpc.NewOrdersClient(rpc.MustDial("ORDERS_ADDR")),
	}))
}
