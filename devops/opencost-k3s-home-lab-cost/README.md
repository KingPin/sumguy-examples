# OpenCost on k3s: home lab pricing

Companion files for [OpenCost on k3s: What Your Pods Cost](https://sumguy.com/opencost-k3s-home-lab-cost/).

## What it does

- `derive_rates.py` turns your electricity rate, measured node watts, hardware price, amortization period, cores, RAM and disk into OpenCost hourly rates (CPU per core-hour, RAM per GB-hour, storage per GB-hour). Standard library only.
- `values.yaml` is a Helm values file for the OpenCost chart. It points at a kube-prometheus-stack Prometheus and turns on custom pricing. The chart renders the pricing ConfigMap (`custom-pricing-model`) from `costModel`.
- `pricing.json` is the same pricing as plain JSON, for reference or for tools that want the raw file.

The example numbers assume one node: $250 mini PC, 5 years, 18 W measured average, $0.13/kWh (an example rate, use the one on your bill), 8 cores, 32 GB RAM, 1000 GB disk.

## Prerequisites and tested versions

- k3s cluster, Helm 3
- Prometheus with kube-state-metrics and node-exporter (kube-prometheus-stack provides both)
- OpenCost Helm chart 2.5.32 (app version 1.121.3), as of October 2026
- Python 3.8+

## How to run

```bash
python3 derive_rates.py --kwh-rate 0.13 --watts 18 --price 250 --years 5 \
  --cores 8 --ram-gb 32 --disk-gb 1000
```

Copy the three rates into `values.yaml`. Check the Prometheus service name first (`kubectl -n monitoring get svc`), then:

```bash
helm install opencost --repo https://opencost.github.io/opencost-helm-chart opencost \
  --namespace opencost --create-namespace -f values.yaml
kubectl -n opencost port-forward deployment/opencost 9003 9090
curl -G http://localhost:9003/allocation/compute -d window=7d -d aggregate=namespace
```

The UI is on http://localhost:9090.
