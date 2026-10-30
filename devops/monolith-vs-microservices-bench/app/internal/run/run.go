// Package run holds the process plumbing every binary shares.
package run

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"strconv"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func Env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// Start logs the GOMAXPROCS the Go runtime picked (cgroup-aware since Go 1.25).
func Start(name string) { log.Printf("%s: GOMAXPROCS=%d", name, runtime.GOMAXPROCS(0)) }

// Pool connects to PG_URL with POOL_MAX connections (default def).
func Pool(def int) *pgxpool.Pool {
	url := os.Getenv("PG_URL")
	if url == "" {
		log.Fatal("PG_URL is not set")
	}
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		log.Fatal(err)
	}
	max, err := strconv.Atoi(Env("POOL_MAX", strconv.Itoa(def)))
	if err != nil {
		log.Fatal(err)
	}
	cfg.MaxConns = int32(max)
	p, err := pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		log.Fatal(err)
	}
	return p
}

// PoolStats prints the pool counters bench.sh keeps from the container log.
func PoolStats(name string, p *pgxpool.Pool) {
	s := p.Stat()
	log.Printf("pool %s: max=%d acquires=%d empty_acquires=%d acquire_ms=%d",
		name, s.MaxConns(), s.AcquireCount(), s.EmptyAcquireCount(), s.AcquireDuration().Milliseconds())
}

// Wait blocks until SIGTERM or SIGINT.
func Wait() {
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGTERM, os.Interrupt)
	<-c
}

// HTTP serves h on LISTEN (default :8080) until SIGTERM or SIGINT, then drains for up to 5 s.
func HTTP(h http.Handler) {
	srv := &http.Server{Addr: Env("LISTEN", ":8080"), Handler: h}
	go func() {
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()
	Wait()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
}
