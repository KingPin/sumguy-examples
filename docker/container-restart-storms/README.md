# Container Restart Storms: triage script and lab

Companion files for [Container Restart Storms at 2 AM](https://sumguy.com/container-restart-storms/).

## What is in here

- `restart-triage.sh`: prints restart count, status, restart policy, exit code, OOMKilled, error, start and finish times, the last log lines with timestamps, and the last five `die` events for one container.
- `compose.yaml`: a lab with three services that crash loop for different reasons (`missing-env`, `oom`, `race-app`) and one fixed variant (`fixed-app`, gated on `service_healthy`). A `slow-db` service fakes a 40 second database boot.

## Prerequisites

- Docker Engine with the Compose plugin. Tested on Docker Engine 29.8.2, Compose v2, cgroup v2, Linux.
- `bash`. `date -d` (GNU) or `date -r` (BSD) for the event timestamps.
- The images `alpine:3.22` and `postgres:17-alpine` (pulled automatically).

## Run it

```bash
docker compose -p storm-lab up -d
sleep 45
docker ps --format '{{.Names}}\t{{.Status}}'
./restart-triage.sh storm-lab-oom-1
./restart-triage.sh storm-lab-missing-env-1
./restart-triage.sh storm-lab-race-app-1
docker compose -p storm-lab down -v
```

Expected results:

- `missing-env`: exit code 2, `OOMKilled false`, log line about `DB_PASSWORD`.
- `oom`: exit code 137, `OOMKilled true`, memory limit 16777216 bytes.
- `race-app`: restarts several times while `slow-db` boots, then stays up.
- `fixed-app`: restart count 0.

The lab only uses throwaway containers and a 16 MiB memory limit. Nothing is published on host ports.
