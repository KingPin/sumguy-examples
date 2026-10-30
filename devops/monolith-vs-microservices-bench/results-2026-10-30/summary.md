## Throughput at fixed concurrency (closed loop, median [min-max] of 3 runs)

| scenario | design | 2xx req/s | p99 ms | app CPU-s / 1k | Postgres CPU-s / 1k | non-2xx | k6 cores | verdict |
|---|---|---|---|---|---|---|---|---|
| browse-max | monolith | 6,318 [6,235-6,545] | 9.6 [9.1-9.8] | 0.14 [0.13-0.14] | 0.32 [0.31-0.32] | 0 | 0.70 [0.69-0.70] |  |
| browse-max | micro | 5,683 [5,651-5,730] | 8.1 [8.0-8.2] | 0.34 [0.34-0.34] | 0.35 [0.35-0.35] | 0 | 0.71 [0.71-0.71] | monolith by 11% |
| cart-max | monolith | 14,689 [14,682-14,986] | 4.5 [4.5-4.5] | 0.11 [0.11-0.11] | 0.12 [0.11-0.12] | 0 | 1.24 [1.23-1.26] |  |
| cart-max | micro | 9,204 [9,161-9,206] | 4.3 [4.2-4.3] | 0.30 [0.29-0.30] | 0.12 [0.12-0.12] | 0 | 0.96 [0.96-0.96] | monolith by 60% |
| checkout-max | monolith | 9,936 [9,799-9,964] | 4.0 [4.0-4.1] | 0.17 [0.17-0.18] | 0.20 [0.20-0.20] | 0 | 0.96 [0.96-0.96] |  |
| checkout-max | micro | 5,318 [5,242-5,331] | 7.9 [7.9-7.9] | 0.52 [0.52-0.53] | 0.23 [0.23-0.24] | 0 | 0.61 [0.61-0.61] | monolith by 87% |
| mix-max | monolith | 6,998 [6,941-7,060] | 9.6 [9.4-9.7] | 0.14 [0.14-0.14] | 0.28 [0.28-0.29] | 0 | 0.77 [0.77-0.78] |  |
| mix-max | micro | 5,824 [5,749-5,866] | 9.1 [9.1-9.3] | 0.42 [0.42-0.43] | 0.32 [0.32-0.33] | 0 | 0.76 [0.75-0.76] | monolith by 20% |

checkout-max completed checkouts/s: monolith 4,968 [4,900-4,982], micro 2,659 [2,621-2,665]

## Latency at equal load (mix-fixed)

| design | 2xx req/s | p50 ms | p95 ms | p99 ms | non-2xx | verdict (p99) |
|---|---|---|---|---|---|---|
| monolith | 3,597 [3,594-3,598] | 0.38 [0.38-0.39] | 1.76 [1.68-1.81] | 9.75 [8.73-10.26] | 0 |  |
| micro | 3,598 [3,598-3,600] | 0.72 [0.71-0.76] | 2.44 [2.39-2.87] | 5.03 [4.27-16.93] | 0 | tie |

## Load capacity (matrix, mix-ramp): p99 < 50 ms, non-2xx < 0.1%, dropped < 0.1%

| config | capacity, 2xx req/s | verdict |
|---|---|---|
| monolith | 4,556 [4,553-4,558] |  |
| micro | 4,555 [3,518-4,558] | tie |

| step | offered iter/s | monolith p99 ms / non-2xx % / dropped % | micro p99 ms / non-2xx % / dropped % |
|---|---|---|---|
| step01 | 1371 | 5.5 / 0.00 / 0.00 | 3.1 / 0.00 / 0.00 |
| step02 | 2361 | 9.4 / 0.00 / 0.00 | 2.5 / 0.00 / 0.00 |
| step03 | 3352 | 14.6 / 0.00 / 0.00 | 5.2 / 0.00 / 0.00 |
| step04 | 4342 | 7.2 / 0.00 / 0.00 | 24.1 / 0.00 / 0.00 |
| step05 | 5333 | 131.8 / 0.00 / 0.00 | 224.7 / 0.00 / 0.00 |
| step06 | 6323 | 310.4 / 0.00 / 0.00 | 940.0 / 0.00 / 7.88 |
| step07 | 7314 | 1268.0 / 0.00 / 9.46 | 1585.5 / 0.00 / 23.48 |
| step08 | 8304 | 1887.1 / 0.00 / 23.06 | 1582.8 / 0.00 / 33.27 |
| step09 | 9295 | 2124.6 / 0.00 / 32.10 | 2078.9 / 0.00 / 41.10 |
| step10 | 10285 | 2715.1 / 0.00 / 38.15 | 2021.9 / 82.86 / 45.41 |

## Memory (cgroup, MiB, mix-max) and image size

| design | idle | peak | images MiB |
|---|---|---|---|
| monolith | 3.5 [3.4-4.1] | 12.1 [12.1-12.2] | 20.8 |
| micro | 15.8 [15.0-15.9] | 37.2 [36.8-37.2] | 106.3 |

## Sustained (mix-sustained, 90 s, one run)

| design | 2xx req/s | p99 ms | non-2xx | peak MiB |
|---|---|---|---|---|
| monolith | 6,906 | 9.7 | 0 | 12.4 |
| micro | 5,764 | 9.2 | 0 | 37.1 |

## Pool waits (pgxpool at shutdown: warm-up + measured run, median of ok runs)

| scenario | design | pool | max | acquires | empty acquires | acquire ms |
|---|---|---|---|---|---|---|
| mix-max | monolith | shop | 30 | 300,180 | 16 | 301 |
| mix-max | micro | cart | 10 | 69,743 | 12 | 149 |
| mix-max | micro | catalog | 10 | 205,656 | 67,760 | 31,675 |
| mix-max | micro | orders | 10 | 11,601 | 11 | 153 |
| checkout-max | monolith | shop | 30 | 372,823 | 16 | 281 |
| checkout-max | micro | cart | 10 | 259,016 | 2,904 | 513 |
| checkout-max | micro | catalog | 10 | 135,680 | 19,275 | 8,311 |
| checkout-max | micro | orders | 10 | 83,105 | 2,852 | 1,322 |

## CPU-quota allocation, budget B = 2 (mix-max)

| config | 2xx req/s | p99 ms | app CPU-s / 1k | throttled s | verdict vs mono |
|---|---|---|---|---|---|
| mono | 7,188 [7,112-7,562] | 9.4 [8.8-9.4] | 0.13 [0.12-0.13] | 0.0 [0.0-0.0] |  |
| micro-even | 1,224 [1,155-1,236] | 74.5 [74.1-74.9] | 1.02 [1.01-1.07] | 26.3 [26.2-27.2] | mono by 487% |
| micro-tuned | 4,675 [3,800-4,987] | 31.6 [28.1-36.8] | 0.41 [0.39-0.51] | 17.7 [14.2-19.4] | mono by 54% |

## CPU-quota allocation, budget B = 3 (mix-max)

| config | 2xx req/s | p99 ms | app CPU-s / 1k | throttled s | verdict vs mono |
|---|---|---|---|---|---|
| mono | 7,120 [6,943-7,457] | 9.4 [9.0-9.8] | 0.14 [0.13-0.14] | 0.0 [0.0-0.0] |  |
| micro-even | 3,151 [2,852-4,365] | 41.8 [33.8-42.8] | 0.59 [0.43-0.65] | 12.3 [10.0-12.8] | mono by 126% |
| micro-tuned | 5,924 [5,879-5,965] | 9.1 [9.0-9.1] | 0.40 [0.39-0.40] | 0.1 [0.0-0.2] | mono by 20% |

## Load capacity (scaling-B3, mix-ramp): p99 < 50 ms, non-2xx < 0.1%, dropped < 0.1%

| config | capacity, 2xx req/s | verdict |
|---|---|---|
| mono | 4,556 [4,554-4,564] |  |
| micro-even | 3,521 [3,518-3,523] | mono by 29% |
| micro-tuned | 4,561 [4,559-4,563] | tie |

| step | offered iter/s | mono p99 ms / non-2xx % / dropped % | micro-even p99 ms / non-2xx % / dropped % | micro-tuned p99 ms / non-2xx % / dropped % |
|---|---|---|---|---|
| step01 | 1371 | 4.4 / 0.00 / 0.00 | 3.7 / 0.00 / 0.00 | 3.7 / 0.00 / 0.00 |
| step02 | 2361 | 6.1 / 0.00 / 0.00 | 3.3 / 0.00 / 0.00 | 3.3 / 0.00 / 0.00 |
| step03 | 3352 | 13.2 / 0.00 / 0.00 | 22.6 / 0.00 / 0.00 | 4.9 / 0.00 / 0.00 |
| step04 | 4342 | 10.4 / 0.00 / 0.00 | 123.3 / 0.00 / 0.00 | 38.0 / 0.00 / 0.00 |
| step05 | 5333 | 114.2 / 0.00 / 0.00 | 335.4 / 0.00 / 1.31 | 285.9 / 0.00 / 0.00 |
| step06 | 6323 | 333.5 / 0.00 / 0.09 | 868.3 / 0.00 / 6.94 | 881.2 / 0.00 / 6.93 |
| step07 | 7314 | 1270.9 / 0.00 / 9.08 | 1470.6 / 0.00 / 23.50 | 1534.0 / 0.00 / 23.06 |
| step08 | 8304 | 1856.4 / 0.00 / 22.87 | 1642.1 / 0.00 / 32.50 | 1805.8 / 0.00 / 32.93 |
| step09 | 9295 | 2188.5 / 0.00 / 31.99 | 2028.8 / 0.00 / 41.65 | 2184.5 / 0.00 / 41.18 |
| step10 | 10285 | 2630.0 / 0.00 / 39.00 | 2354.6 / 25.15 / 45.98 | 2056.0 / 67.29 / 44.92 |

## Environment (matrix)

```text
date: 2026-10-30T16:40:33Z
kit: 02d821b
kernel: 7.0.0-38-generic
Model name:                              Intel(R) Core(TM) i7-9700 CPU @ 3.00GHz
os: Ubuntu 26.04.1 LTS
docker: 29.9.1
phase: matrix duration: 30s runs: 3 step: 20s budget: none
cpus: os=0 k6=1,2 pg=3,4 app=5,6,7
noise excludes harness cgroup: /user.slice/user-0.slice/session-284.scope
noise excludes daemons: docker.service containerd.service
resolved: VUS=16 FIXED_RATE=3428 RAMP_LO=1371 RAMP_HI=10285 NOISE_LIMIT=0.05
--- sibling map (lscpu -e=CPU,CORE)
CPU CORE
  0    0
  1    1
  2    2
  3    3
  4    4
  5    5
  6    6
  7    7
--- bench.env
# Versions: current releases checked 2026-10-30 on Docker Hub / gcr.io.
GO_IMAGE=${GO_IMAGE:-golang:1.27.3}
DISTROLESS_IMAGE=${DISTROLESS_IMAGE:-gcr.io/distroless/static-debian13:nonroot}
PG_IMAGE=${PG_IMAGE:-postgres:18.6}
K6_IMAGE=${K6_IMAGE:-grafana/k6:2.3.0}
BUF_IMAGE=${BUF_IMAGE:-bufbuild/buf:1.75.0}

# CPU split. The test box has 8 cores, one thread each (CPUs 0-7, no SMT siblings); CPU 0 stays for the OS.
K6_CPUS=${K6_CPUS:-1,2}
PG_CPUS=${PG_CPUS:-3,4}
APP_CPUS=${APP_CPUS:-5,6,7}
OS_CPUS=${OS_CPUS:-0}   # bench.sh pins itself (and every child: sampler, awk, docker CLI) here, off the bench CPUs

# Calibration from the smoke sweep (summarize.py calibrate). Rates are iterations/s.
VUS=${VUS:-16}
FIXED_RATE=${FIXED_RATE:-3428}
RAMP_LO=${RAMP_LO:-1371}
RAMP_HI=${RAMP_HI:-10285}

# A test whose non-bench CPU use averages above this many cores is marked noisy.
NOISE_LIMIT=${NOISE_LIMIT:-0.05}
--- images
image mvm-monolith:bench 21791350 sha256:1ad6c557f1dfaba34bb413456a999d3bc27651024b318869ef3ceb929c172185
image mvm-gateway:bench 25118343 sha256:3d756e281a27863dc4121c98bccf46983c13b0a55bf0e7f239161a2e987e9594
image mvm-catalog:bench 28713287 sha256:c603f7d7f900387cb84946a9a0e18613f2669b0f8beada93bc092e66a78ac834
image mvm-cart:bench 28827353 sha256:15f8c5754fd69bd8a0fd829326c0c11a4c438f0f7fecd238bab991ff3f1493f4
image mvm-orders:bench 28828945 sha256:c399a692bd038a88143e61a474ea39ea0f1aaa0cef82c91510fdea86a301aebb
image postgres:18.6 644209868 postgres@sha256:979bccfde35445db618c65107d27d08c6c21339d8dc3ad4c830c6633947be0e4
image grafana/k6:2.3.0 111432763 grafana/k6@sha256:2dd4756ec6e14e62778916e1eb850108e4b499304c02df56760fa0bdb0fba0b8
image golang:1.27.3 1300870045 golang@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b
image gcr.io/distroless/static-debian13:nonroot 6652143 gcr.io/distroless/static-debian13@sha256:18f4cc26c9ffa7f20a359298be7deadac5c607c8e03a02b8119f1a5fc2f82c99
--- docker stats before the run
other containers running: 2
gomaxprocs: cart: GOMAXPROCS=3
gomaxprocs: catalog: GOMAXPROCS=3
gomaxprocs: gateway: GOMAXPROCS=3
gomaxprocs: monolith: GOMAXPROCS=3
gomaxprocs: orders: GOMAXPROCS=3
```

## Environment (scaling-B2)

```text
date: 2026-10-30T17:41:08Z
kit: 02d821b
kernel: 7.0.0-38-generic
Model name:                              Intel(R) Core(TM) i7-9700 CPU @ 3.00GHz
os: Ubuntu 26.04.1 LTS
docker: 29.9.1
phase: scaling-B2 duration: 30s runs: 3 step: 20s budget: 2
cpus: os=0 k6=1,2 pg=3,4 app=5,6,7
noise excludes harness cgroup: /user.slice/user-0.slice/session-292.scope
noise excludes daemons: docker.service containerd.service
resolved: VUS=16 FIXED_RATE=3428 RAMP_LO=1371 RAMP_HI=10285 NOISE_LIMIT=0.05
--- sibling map (lscpu -e=CPU,CORE)
CPU CORE
  0    0
  1    1
  2    2
  3    3
  4    4
  5    5
  6    6
  7    7
--- bench.env
# Versions: current releases checked 2026-10-30 on Docker Hub / gcr.io.
GO_IMAGE=${GO_IMAGE:-golang:1.27.3}
DISTROLESS_IMAGE=${DISTROLESS_IMAGE:-gcr.io/distroless/static-debian13:nonroot}
PG_IMAGE=${PG_IMAGE:-postgres:18.6}
K6_IMAGE=${K6_IMAGE:-grafana/k6:2.3.0}
BUF_IMAGE=${BUF_IMAGE:-bufbuild/buf:1.75.0}

# CPU split. The test box has 8 cores, one thread each (CPUs 0-7, no SMT siblings); CPU 0 stays for the OS.
K6_CPUS=${K6_CPUS:-1,2}
PG_CPUS=${PG_CPUS:-3,4}
APP_CPUS=${APP_CPUS:-5,6,7}
OS_CPUS=${OS_CPUS:-0}   # bench.sh pins itself (and every child: sampler, awk, docker CLI) here, off the bench CPUs

# Calibration from the smoke sweep (summarize.py calibrate). Rates are iterations/s.
VUS=${VUS:-16}
FIXED_RATE=${FIXED_RATE:-3428}
RAMP_LO=${RAMP_LO:-1371}
RAMP_HI=${RAMP_HI:-10285}

# A test whose non-bench CPU use averages above this many cores is marked noisy.
NOISE_LIMIT=${NOISE_LIMIT:-0.05}
--- tuned-B2.env
# from results-2026-10-30 matrix micro mix-max, shares {"gateway": 0.4013, "catalog": 0.3301, "cart": 0.1641, "orders": 0.1045}
Q_GATEWAY=0.8
Q_CATALOG=0.7
Q_CART=0.3
Q_ORDERS=0.2
--- images
image mvm-monolith:bench 21791350 sha256:19c6b4f4416533f56b308645d3c4bb7d02b10fbf21d6665a7c8148b13abce0ae
image mvm-gateway:bench 25118343 sha256:f6890eafb0b165392900990f9bc14da213a9f9be340a8583d72a9675a0dfb540
image mvm-catalog:bench 28713287 sha256:7cf021dcd1bfbbf22a1bf80188219addb51845b76f0f5498eff0a95f916766f1
image mvm-cart:bench 28827353 sha256:7c935d9dda184a839982f9a7abb2b7fde592e78698f930838315c7ceb8d6ba63
image mvm-orders:bench 28828945 sha256:c51074df5e43504d2b66e0846429b5048880c91015127926d04f7e24fd24533d
image postgres:18.6 644209868 postgres@sha256:979bccfde35445db618c65107d27d08c6c21339d8dc3ad4c830c6633947be0e4
image grafana/k6:2.3.0 111432763 grafana/k6@sha256:2dd4756ec6e14e62778916e1eb850108e4b499304c02df56760fa0bdb0fba0b8
image golang:1.27.3 1300870045 golang@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b
image gcr.io/distroless/static-debian13:nonroot 6652143 gcr.io/distroless/static-debian13@sha256:18f4cc26c9ffa7f20a359298be7deadac5c607c8e03a02b8119f1a5fc2f82c99
--- docker stats before the run
other containers running: 2
gomaxprocs: cart: GOMAXPROCS=2
gomaxprocs: catalog: GOMAXPROCS=2
gomaxprocs: gateway: GOMAXPROCS=2
gomaxprocs: monolith: GOMAXPROCS=2
gomaxprocs: orders: GOMAXPROCS=2
```

## Environment (scaling-B3)

```text
date: 2026-10-30T17:52:13Z
kit: 02d821b
kernel: 7.0.0-38-generic
Model name:                              Intel(R) Core(TM) i7-9700 CPU @ 3.00GHz
os: Ubuntu 26.04.1 LTS
docker: 29.9.1
phase: scaling-B3 duration: 30s runs: 3 step: 20s budget: 3
cpus: os=0 k6=1,2 pg=3,4 app=5,6,7
noise excludes harness cgroup: /user.slice/user-0.slice/session-294.scope
noise excludes daemons: docker.service containerd.service
resolved: VUS=16 FIXED_RATE=3428 RAMP_LO=1371 RAMP_HI=10285 NOISE_LIMIT=0.05
--- sibling map (lscpu -e=CPU,CORE)
CPU CORE
  0    0
  1    1
  2    2
  3    3
  4    4
  5    5
  6    6
  7    7
--- bench.env
# Versions: current releases checked 2026-10-30 on Docker Hub / gcr.io.
GO_IMAGE=${GO_IMAGE:-golang:1.27.3}
DISTROLESS_IMAGE=${DISTROLESS_IMAGE:-gcr.io/distroless/static-debian13:nonroot}
PG_IMAGE=${PG_IMAGE:-postgres:18.6}
K6_IMAGE=${K6_IMAGE:-grafana/k6:2.3.0}
BUF_IMAGE=${BUF_IMAGE:-bufbuild/buf:1.75.0}

# CPU split. The test box has 8 cores, one thread each (CPUs 0-7, no SMT siblings); CPU 0 stays for the OS.
K6_CPUS=${K6_CPUS:-1,2}
PG_CPUS=${PG_CPUS:-3,4}
APP_CPUS=${APP_CPUS:-5,6,7}
OS_CPUS=${OS_CPUS:-0}   # bench.sh pins itself (and every child: sampler, awk, docker CLI) here, off the bench CPUs

# Calibration from the smoke sweep (summarize.py calibrate). Rates are iterations/s.
VUS=${VUS:-16}
FIXED_RATE=${FIXED_RATE:-3428}
RAMP_LO=${RAMP_LO:-1371}
RAMP_HI=${RAMP_HI:-10285}

# A test whose non-bench CPU use averages above this many cores is marked noisy.
NOISE_LIMIT=${NOISE_LIMIT:-0.05}
--- tuned-B3.env
# from results-2026-10-30 matrix micro mix-max, shares {"gateway": 0.4013, "catalog": 0.3301, "cart": 0.1641, "orders": 0.1045}
Q_GATEWAY=1.2
Q_CATALOG=1.0
Q_CART=0.5
Q_ORDERS=0.3
--- images
image mvm-monolith:bench 21791350 sha256:5c26e3c56e958e183a0bddd98a97f4af815befbb829bd4c194591cb5abfa807f
image mvm-gateway:bench 25118343 sha256:ad610468bd89a1fdbe4195cc357a06d9a8c7568198aa84602f8a104790ff5b4f
image mvm-catalog:bench 28713287 sha256:aab1f710c75d58806e04d3c0e1572bedcb9a78afe4c1f6fe7a2afde606cae3e3
image mvm-cart:bench 28827353 sha256:940923b9c6d510c2c94635bb8f535943eb9222ea62949e66613f15b89568820b
image mvm-orders:bench 28828945 sha256:2da8296ec29f6cc49a350a90a2da90d1d7f521f96ac209e9f30e9481423a015d
image postgres:18.6 644209868 postgres@sha256:979bccfde35445db618c65107d27d08c6c21339d8dc3ad4c830c6633947be0e4
image grafana/k6:2.3.0 111432763 grafana/k6@sha256:2dd4756ec6e14e62778916e1eb850108e4b499304c02df56760fa0bdb0fba0b8
image golang:1.27.3 1300870045 golang@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b
image gcr.io/distroless/static-debian13:nonroot 6652143 gcr.io/distroless/static-debian13@sha256:18f4cc26c9ffa7f20a359298be7deadac5c607c8e03a02b8119f1a5fc2f82c99
--- docker stats before the run
other containers running: 2
gomaxprocs: cart: GOMAXPROCS=2
gomaxprocs: catalog: GOMAXPROCS=2
gomaxprocs: gateway: GOMAXPROCS=2
gomaxprocs: monolith: GOMAXPROCS=3
gomaxprocs: orders: GOMAXPROCS=2
```
