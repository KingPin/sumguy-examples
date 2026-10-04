#!/usr/bin/env python3
"""Derive OpenCost on-prem hourly rates (CPU/RAM/storage) for one node.

OpenCost custom pricing units: CPU = $ per core-hour, RAM = $ per GB-hour,
storage = $ per GB-hour. Run once per node and average, or feed the totals
of the whole cluster (sum cores, RAM, disk, watts, price).
"""
import argparse
import json

HOURS_PER_YEAR = 8766  # 365.25 * 24


def derive(kwh_rate, watts, price, years, cores, ram_gb, disk_gb,
           disk_share=0.10, cpu_weight=0.70):
    power_hr = watts / 1000 * kwh_rate
    hw_hr = price / (years * HOURS_PER_YEAR)
    # Disk gets a fixed slice of the hardware cost; electricity is all compute.
    disk_hr = hw_hr * disk_share
    compute_hr = power_hr + hw_hr - disk_hr
    return {
        "power_per_hour": power_hr,
        "hardware_per_hour": hw_hr,
        "node_per_hour": power_hr + hw_hr,
        "node_per_month": (power_hr + hw_hr) * HOURS_PER_YEAR / 12,
        "CPU": compute_hr * cpu_weight / cores,
        "RAM": compute_hr * (1 - cpu_weight) / ram_gb,
        "storage": disk_hr / disk_gb,
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--kwh-rate", type=float, required=True, help="$/kWh from your bill")
    p.add_argument("--watts", type=float, required=True, help="measured average draw")
    p.add_argument("--price", type=float, required=True, help="hardware purchase price, $")
    p.add_argument("--years", type=float, required=True, help="amortization years")
    p.add_argument("--cores", type=int, required=True)
    p.add_argument("--ram-gb", type=float, required=True)
    p.add_argument("--disk-gb", type=float, required=True)
    p.add_argument("--disk-share", type=float, default=0.10,
                   help="fraction of hardware cost charged to storage (default 0.10)")
    p.add_argument("--cpu-weight", type=float, default=0.70,
                   help="fraction of compute cost charged to CPU, rest to RAM (default 0.70)")
    p.add_argument("--json", action="store_true", help="print only the costModel JSON")
    a = p.parse_args()
    r = derive(a.kwh_rate, a.watts, a.price, a.years, a.cores, a.ram_gb,
               a.disk_gb, a.disk_share, a.cpu_weight)
    model = {"provider": "custom", "description": "On-prem rates derived from power bill and hardware cost",
             "CPU": f"{r['CPU']:.8f}", "RAM": f"{r['RAM']:.8f}", "storage": f"{r['storage']:.8f}"}
    if a.json:
        print(json.dumps(model, indent=2))
        return
    print(f"Electricity:  ${r['power_per_hour']:.4f}/hour")
    print(f"Hardware:     ${r['hardware_per_hour']:.4f}/hour")
    print(f"Node total:   ${r['node_per_hour']:.4f}/hour  (${r['node_per_month']:.2f}/month)")
    print(f"CPU:          ${r['CPU']:.8f} per core-hour")
    print(f"RAM:          ${r['RAM']:.8f} per GB-hour")
    print(f"Storage:      ${r['storage']:.8f} per GB-hour")
    print()
    print(json.dumps(model, indent=2))


if __name__ == "__main__":
    main()
