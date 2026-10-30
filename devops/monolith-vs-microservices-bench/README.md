# Monolith vs microservices: benchmark kit

The test kit behind [Monolith vs Microservices, Measured](https://sumguy.com/monolith-vs-microservices-benchmark/), a SumGuy's Lab post.
One Go shop app built two ways: a monolith, and a gateway plus three gRPC services (catalog, cart, orders).
Both share the same domain code and SQL. Every test pins each part to its own CPU cores
and starts fresh containers.

## What it tests

| Scenario | What it measures |
|---|---|
| `browse-max`, `cart-max`, `checkout-max` | one path at a fixed VU count, no think time |
| `mix-max` | 80% browse, 15% cart, 5% checkout at the same VU count |
| `mix-fixed` | the mix at a fixed arrival rate, for latency |
| `mix-ramp` | 10 steps of 20 s from `RAMP_LO` to `RAMP_HI` iterations/s (set from the calibration), for load capacity |
| `mix-sustained` | the mix for 90 s, once per design. Skip with `SUSTAINED=0` |

Designs (`PHASE=matrix`, `DESIGNS=`): `monolith` and `micro`. Neither has a CPU quota.

CPU-quota configs (`PHASE=scaling`, `B=2` or `B=3`, where B is the total CPU budget in cores):

| Config | What it is |
|---|---|
| `mono` | the monolith with a quota of B cores |
| `micro-even` | each of the four micro containers gets B/4 cores |
| `micro-tuned` | quotas split by each service's measured share of app CPU, written by `tune_split.py` to `tuned-B2.env` and `tuned-B3.env` |

`mix-max` runs at B=2 and B=3. `mix-ramp` runs at B=3 only. The budget stops at 3 because the app gets 3 CPUs.
A CPU quota models a resource budget, not replicas.

## Prerequisites

- Linux with Docker and cgroup v2 (`/sys/fs/cgroup/system.slice/docker-<id>.scope` must exist). The script reads container cgroup files, so run it as a user that can read them (root works).
- Python 3 and curl
- At least 8 CPUs for the default split: OS 0, k6 1-2, Postgres 3-4, app 5-7. If your CPU has SMT, put the sibling threads of a core in the same group. Check `lscpu -e=CPU,CORE` and set `OS_CPUS`, `K6_CPUS`, `PG_CPUS`, `APP_CPUS` to match.
- Network access to pull the images named in `bench.env`. `buf` and `k6` run as Docker images, so install neither.

Tested with: Intel Core i7-9700 (8 cores, no SMT), Ubuntu 26.04.1 LTS, kernel 7.0.0-38-generic, Docker 29.9.1, golang 1.27.3, postgres 18.6, grafana/k6 2.3.0, distroless static-debian13 (nonroot), buf 1.75.0. Kit revision 02d821b.

## Run it

Run everything from this directory on the test box. Use a new `results-YYYY-MM-DD` name for each run; `bench.sh` refuses to write into an existing phase directory.

1. Check that both designs return identical responses:

   ```bash
   ./bench.sh contract
   ```

2. Smoke test (20 s per test, 1 run, no sustained test):

   ```bash
   OUT=results-smoke SUSTAINED=0 ./bench.sh 20 1
   ```

3. Sweep VU counts and calibrate. The sweep runs `mix-max` at 16, 32, 64, 128, and 256 VUs once per design. Then `calibrate` prints the knee and the values to use:

   ```bash
   PHASE=sweep OUT=results-calib ./bench.sh 30 1
   python3 summarize.py calibrate results-calib
   ```

   Copy the printed `VUS`, `FIXED_RATE`, `RAMP_LO`, and `RAMP_HI` into `bench.env`. A `# WARN ... Postgres` line means Postgres is the limit (see Limits). A `# WARN ... k6` line means the load generator is.

   Calibrated values in `bench.env`: `VUS=16`, `FIXED_RATE=3428`, ramp 1371-10285 iter/s (`RAMP_LO`, `RAMP_HI`).

4. Full matrix (30 s per test, 3 runs, plus the 90 s sustained test):

   ```bash
   OUT=results-YYYY-MM-DD ./bench.sh
   ```

5. Compute the micro-tuned quotas from the matrix runs (writes `tuned-B2.env` and `tuned-B3.env`):

   ```bash
   python3 tune_split.py results-YYYY-MM-DD
   ```

6. CPU-quota scaling, one invocation per budget:

   ```bash
   PHASE=scaling B=2 OUT=results-YYYY-MM-DD ./bench.sh
   PHASE=scaling B=3 OUT=results-YYYY-MM-DD ./bench.sh
   ```

7. Median tables in Markdown:

   ```bash
   python3 summarize.py results-YYYY-MM-DD > results-YYYY-MM-DD/summary.md
   ```

`bench.sh [duration_seconds] [runs]` defaults to 30 s and 3 runs. Other variables it reads: `DESIGNS`, `SCENARIOS`, `CONFIGS`, `SWEEP_VUS`, `APP_PORT`, `STEP_S`, `NOISE_LIMIT`, and the image tags and calibration values in `bench.env`. `./bench.sh contract record` rewrites `expected/contract.json` from the monolith.

### The noise gate

Before a phase, `bench.sh` measures background CPU for 10 s. It refuses to start if the average is above `NOISE_LIMIT` (0.05 cores) or if a system service exits in that window. It excludes its own session and `docker.service` and `containerd.service`.
The same reading is taken around every test, and a test above the limit is marked `noisy` and kept out of the medians.
Periodic system timers, such as a sysstat collector that fires every 10 minutes, can trip the gate. Start the phase again at a different minute.

## Files

| Path | What it is |
|---|---|
| `app/` | Go module `shopbench` and its Dockerfile |
| `app/catalog/`, `app/cart/`, `app/orders/` | domain logic and SQL access, with tests; shared by both designs |
| `app/api/` | HTTP/JSON handlers, shared by the monolith and the gateway |
| `app/rpc/` | `shop.proto`, generated gRPC code (`buf.gen.yaml`), servers and clients |
| `app/cmd/monolith/` | monolith entry point, direct calls into the domain packages |
| `app/cmd/gateway/` | HTTP front end that calls the three services over gRPC |
| `app/cmd/catalog/`, `app/cmd/cart/`, `app/cmd/orders/` | gRPC server for each service |
| `app/internal/pgtest/`, `app/internal/run/` | test database helper, shared service startup |
| `app/testpg.sh` | starts a throwaway Postgres for `go test` and exports `PGURL` |
| `k6/shop.js` | flows and scenarios, picked with the `SCENARIO` variable |
| `seed.sql`, `sql/` | schema and seed data for the monolith database and the per-service databases (10,000 products) |
| `contract.py`, `expected/contract.json` | contract check client and the recorded requests and responses |
| `bench.env` | image tags, core split, calibration values, noise limit |
| `bench.sh` | contract check, noise gate, sweep, matrix, and scaling phases |
| `tune_split.py` | micro-tuned quotas from the matrix runs |
| `summarize.py` | median tables (2xx only, ok runs only) and the `calibrate` report |
| `test_tools.py` | tests for the Python tools |
| `tuned-B2.env`, `tuned-B3.env` | micro-tuned quotas written by `tune_split.py` |
| `results-2026-10-30/` | raw results behind the post: `matrix/`, `scaling-B2/`, `scaling-B3/`, each with an `env.txt`, plus `summary.md` |
| `results-calib/` | the calibration sweep and `calibrate.txt` |

Each result is one JSON file per run: `<phase>/<config>/<scenario>-r<run>.json`.

## Limits

- One host. The load generator, Postgres, and the app share one 8-core machine, split by CPU pinning. The network is a local Docker bridge.
- GOMAXPROCS as logged in each `env.txt`: 3 everywhere in the matrix; 2 for every container at B=2 and for every microservices container at B=3; 3 for the monolith at B=3.
- Postgres data lives on tmpfs, so there is no disk I/O.
- Postgres capped both designs in `mix-max` and `browse-max` on this split. `results-calib/calibrate.txt` shows Postgres at 1.94 cores (monolith) and 1.83 cores (micro) of its 2 CPUs at 16 VUs in `mix-max`. In `cart-max` and `checkout-max` the microservices app used about 2.8 of its 3 cores while Postgres used about 1.1 to 1.2 (from `results-2026-10-30/summary.md`), so those loads were app-bound.
- CPU quotas model a resource budget, not replicas. There is no horizontal scaling and no cross-host network.
- No stock reservation: checkout does not decrement stock.
- Microservices checkout is not atomic: the cart is cleared after the order commits, so a failed clear leaves the order in place. The monolith clears the cart inside its transaction.
- No auth and no cache.
- `bench.sh` accepts k6 exit code 99 as a pass. The thresholds in `k6/shop.js` are no-ops (`count>=0`, `max>=0`) that only keep submetrics in the summary, and the only way to cross one is an empty `max` trend, which happens when a run has no 2xx responses at all. Read the non-2xx column in `summary.md`: a run that returned only errors is not caught by the exit code.
- Lab numbers describe this rig, this split, and these versions. Treat them as measurements, not as a prediction for your system.

Post: <https://sumguy.com/monolith-vs-microservices-benchmark/>
