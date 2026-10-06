# zstd vs lz4 vs gzip vs xz vs bzip2: benchmark kit

The test kit behind [zstd vs lz4 vs gzip vs xz: Measured](https://sumguy.com/zstd-lz4-gzip-xz-benchmark/), a SumGuy's Lab post.
It compresses and decompresses four public 256 MiB data sets with every tool at several levels,
pins each run to fixed CPU cores, and records ratio, speed, and peak memory.

## The data

All four files come from public sources, so you can rebuild them byte for byte. `fetch_data.sh`
downloads them, cuts the first 256 MiB of each, and checks the result against `SHA256SUMS`.

| File | Source | What it stands for |
|---|---|---|
| `logs` | [Loghub](https://zenodo.org/records/8196385) "Thunderbird" syslog | Text logs: sshd, kernel, cron, postfix |
| `dbdump` | [Simple English Wikipedia](https://dumps.wikimedia.org/simplewiki/) SQL table dumps, 2026-10-01 | A MariaDB `mysqldump` |
| `rootfs` | `postgres:18` (PG 18.6, linux/amd64) flattened with `crane export`, pinned by digest | A container image or a filesystem backup |
| `video` | [Big Buck Bunny](https://peach.blender.org) 1080p H.264 MP4 | Data that is already compressed |

Wikimedia keeps dumps for a few months only. If the 2026-10-01 dump is gone, change the date in
`fetch_data.sh` to a newer one. The checksum for `dbdump` will not match, but the shape of the data stays the same.

## What it tests

19 configs from `run.sh`: gzip 1/6/9, pigz 6, bzip2 9, lz4 1/9, zstd 1/3/9/19, zstd 19 with
`--long=27`, xz 0/6/9, plus 4-thread runs of pigz, lz4, zstd, and xz. Single-thread configs run
on one CPU. Multithreaded configs run on four CPUs on four separate physical cores.

Thread counts are always set explicitly. xz 5.6 and later and lz4 1.10 use every core by
default, so a bare `xz -6` is not a single-thread number.

Each config runs 3 times; `summarize.py` reports the median. Inputs and outputs live in tmpfs,
so the disk never enters the numbers. Decompression writes to `/dev/null`. The first run of
every config decompresses again and compares the result byte for byte with the input.

## Prerequisites

- Linux with Docker
- Python 3
- 1 GB free disk for `data/`, 1 GB free RAM for the tmpfs
- At least 4 physical cores. Check `lscpu -e=CPU,CORE` and set `CPUS` and `ONE_CPU` to match.

Tested with: Docker 29.8, Ubuntu 22.04 (kernel 6.8), Intel i7-11800H, zstd 1.5.7, lz4 1.10.0,
xz 5.8.4, gzip 1.14, pigz 2.8, bzip2 1.0.8 (Debian forky packages).

## Run it

```bash
./fetch_data.sh          # about 1 minute, downloads a few hundred MB
./bench.sh               # 3 runs of every config; about 2 hours, mostly zstd -19 and xz -9
python3 summarize.py results
```

Quick smoke test:

```bash
RUNS=1 DATASETS=logs CONFIGS="gzip-6 zstd-3 lz4-1 xz-0" OUT=results-smoke ./bench.sh
```

Other CPU layouts:

```bash
CPUS=0-3 ONE_CPU=0 ./bench.sh
```

Stop other busy containers first, and keep the hyperthread siblings of the pinned CPUs idle.

## Files

- `Dockerfile`: Debian forky with the six tools
- `fetch_data.sh`: builds the four data files from public sources
- `SHA256SUMS`: checksums of the four data files
- `run.sh`: the config table and timing loop (runs inside the container)
- `bench.sh`: builds the image, records the environment, runs `run.sh` with CPU pinning
- `summarize.py`: median tables in Markdown
- `results-2026-10-06/`: raw results used in the post (`results.csv`, `env.txt`)
