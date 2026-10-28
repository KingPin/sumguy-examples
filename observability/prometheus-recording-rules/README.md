# Prometheus recording rules for faster Grafana dashboards

Working files for the article [Recording Rules: Faster Prometheus Panels](https://sumguy.com/prometheus-recording-rules/).

## What it does

- Runs Prometheus, node_exporter, and Grafana in Docker.
- Defines four recording rules in `rules/node.yml`: CPU utilisation (two chained steps), memory utilisation, and network receive rate.
- Ships a `promtool test rules` unit test in `tests/node_test.yml` with `input_series` and expected samples.
- Prometheus scrapes itself too, so you can look at `prometheus_rule_group_last_duration_seconds`.

## Prerequisites and tested versions

- Docker with Compose v2
- `prom/prometheus:v3.15.1`
- `prom/node-exporter:v1.12.1`
- `grafana/grafana:13.3.0`

Host ports 9090, 9100, and 3000 must be free. Change the left side of the `ports:` entries in `compose.yaml` if they are not.

## Validate without starting anything

```bash
docker run --rm -v "$PWD":/w -w /w --entrypoint promtool prom/prometheus:v3.15.1 check rules rules/*.yml
docker run --rm -v "$PWD":/w -w /w --entrypoint promtool prom/prometheus:v3.15.1 test rules tests/*.yml
```

`check config prometheus.yml` also works, but `rule_files` points at the container path `/etc/prometheus/rules/`. Mount the files at that path to check it:

```bash
docker run --rm -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" -v "$PWD/rules:/etc/prometheus/rules:ro" \
  --entrypoint promtool prom/prometheus:v3.15.1 check config /etc/prometheus/prometheus.yml
```

## Run the stack

```bash
docker compose up -d
# wait about a minute: the rules use rate(...[5m]) and need a few scrapes
curl -s -G localhost:9090/api/v1/query --data-urlencode 'query=instance:node_cpu_utilisation:ratio_rate5m'
```

Open Prometheus at http://localhost:9090/rules to see each group, its evaluation time, and rule health. Open Grafana at http://localhost:3000 (default login `admin` / `admin`), add a Prometheus data source with URL `http://prometheus:9090`, and graph `instance:node_cpu_utilisation:ratio_rate5m`.

Clean up with `docker compose down -v`.

## Results from the last run

- `check rules`: 4 rules found
- `test rules`: SUCCESS
- All four recorded series returned data about a minute after start.
- `prometheus_rule_evaluation_failures_total` was 0 for both groups.
