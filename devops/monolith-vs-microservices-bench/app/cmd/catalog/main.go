// Command catalog serves the catalog domain over gRPC.
package main

import (
	"google.golang.org/grpc"

	"shopbench/catalog"
	"shopbench/internal/run"
	"shopbench/rpc"
)

func main() {
	run.Start("catalog")
	pool := run.Pool(10)
	rpc.Serve(func(s *grpc.Server) {
		rpc.RegisterCatalogServer(s, &rpc.CatalogService{Store: &catalog.Store{DB: pool}})
	})
	run.PoolStats("catalog", pool)
}
