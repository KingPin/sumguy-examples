// Package pgtest gives each test a fresh database loaded from the kit's sql/ files.
package pgtest

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// New creates a database, runs the named sql/ files in it, and drops it when the test ends.
// PGURL must point at a superuser connection (see app/testpg.sh).
func New(t *testing.T, files ...string) *pgxpool.Pool {
	t.Helper()
	admin := os.Getenv("PGURL")
	if admin == "" {
		t.Fatal("PGURL is not set: run `. ./testpg.sh` in app/ first")
	}
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, admin)
	if err != nil {
		t.Fatal(err)
	}
	name := fmt.Sprintf("t_%d_%d", os.Getpid(), time.Now().UnixNano())
	if _, err := conn.Exec(ctx, "CREATE DATABASE "+name); err != nil {
		t.Fatal(err)
	}
	cfg, err := pgxpool.ParseConfig(admin)
	if err != nil {
		t.Fatal(err)
	}
	cfg.ConnConfig.Database = name
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		pool.Close()
		conn.Exec(ctx, "DROP DATABASE "+name+" WITH (FORCE)")
		conn.Close(ctx)
	})
	_, here, _, _ := runtime.Caller(0)
	for _, f := range files {
		b, err := os.ReadFile(filepath.Join(filepath.Dir(here), "..", "..", "..", "sql", f))
		if err != nil {
			t.Fatal(err)
		}
		// No arguments, so pgx uses the simple protocol and multi-statement files work.
		if _, err := pool.Exec(ctx, string(b)); err != nil {
			t.Fatalf("%s: %v", f, err)
		}
	}
	return pool
}
