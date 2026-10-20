#!/usr/bin/env bash
# Print what the multi-GPU article tells you to check before picking a split mode.
set -euo pipefail

echo "== GPUs, PCIe link, VRAM =="
nvidia-smi --query-gpu=index,name,pcie.link.gen.current,pcie.link.width.current,memory.total --format=csv

echo
echo "== Topology (NV# = NVLink, PIX/PXB/PHB/NODE = PCIe, SYS = crosses NUMA nodes) =="
nvidia-smi topo -m

echo
echo "== P2P read capability =="
nvidia-smi topo -p2p r

echo
echo "Note: link gen/width can drop at idle. Run a load, then re-run this script."
