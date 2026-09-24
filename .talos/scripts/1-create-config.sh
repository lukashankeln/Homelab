#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Talos Configuration Generator ===${NC}\n"

if [[ -z "${CLUSTER_NAME:-}" ]]; then
    echo -e "${RED}Error: CLUSTER_NAME is not set${NC}"; exit 1
fi
if [[ -z "${CONTROL_PLANE_IPS:-}" ]]; then
    echo -e "${RED}Error: CONTROL_PLANE_IPS is not set${NC}"; exit 1
fi

IFS=',' read -ra CP_IP_ARRAY <<< "$CONTROL_PLANE_IPS"
PRIMARY_CP_IP="${CP_IP_ARRAY[0]}"

echo -e "${GREEN}Environment:${NC}"
echo "  CLUSTER_NAME:          $CLUSTER_NAME"
echo "  CONTROL_PLANE_IPS:     $CONTROL_PLANE_IPS"
echo "  CONTROL_PLANE_HOSTNAMES: ${CONTROL_PLANE_HOSTNAMES:-auto}"
echo "  WORKER_IPS:            ${WORKER_IPS:-(none)}"
echo "  WORKER_HOSTNAMES:      ${WORKER_HOSTNAMES:-auto}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALOS_DIR="$(dirname "$SCRIPT_DIR")"
cd "$TALOS_DIR"

if [[ ! -f "secrets.yaml" ]]; then
    echo -e "${YELLOW}secrets.yaml not found — generating new secrets...${NC}"
    talosctl gen secrets -o secrets.yaml
    echo -e "${GREEN}✓ Secrets generated${NC}\n"
else
    echo -e "${GREEN}✓ Using existing secrets.yaml${NC}\n"
fi

echo -e "${YELLOW}Cleaning up old configuration files...${NC}"
rm -f controlplane.yaml talosconfig worker.yaml
echo -e "${GREEN}✓ Done${NC}\n"

echo -e "${YELLOW}Generating base configuration (endpoint: $PRIMARY_CP_IP)...${NC}"
talosctl gen config --with-secrets secrets.yaml "$CLUSTER_NAME" "https://$PRIMARY_CP_IP:6443"
echo -e "${GREEN}✓ Base configuration generated${NC}\n"

# Controlplane: no hostname patch — applied per-node at apply time
echo -e "${YELLOW}Patching controlplane configuration...${NC}"
talosctl machineconfig patch controlplane.yaml \
    --patch @patches/no-flannel.yaml \
    --patch @patches/dns.yaml \
    --patch @patches/kubernetes-version.yaml \
    --patch @patches/controlplane/disk.yaml \
    --patch @patches/controlplane/allow-workloads.yaml \
    --patch @patches/controlplane/proxy.yaml \
    --patch @patches/controlplane/resources.yaml \
    --patch @patches/controlplane/metrics-bind-address.yaml \
    --patch @patches/controlplane/kubernetes-version.yaml \
    --output controlplane.yaml
echo -e "${GREEN}✓ Controlplane configuration patched (hostname applied per-node at apply time)${NC}\n"

if [[ -n "${WORKER_IPS:-}" ]]; then
    echo -e "${YELLOW}Patching worker configuration...${NC}"
    talosctl machineconfig patch worker.yaml \
        --patch @patches/no-flannel.yaml \
        --patch @patches/dns.yaml \
        --patch @patches/kubernetes-version.yaml \
        --patch @patches/worker/disk.yaml \
        --output worker.yaml
    echo -e "${GREEN}✓ Worker configuration patched (hostname applied per-node at apply time)${NC}\n"
else
    echo -e "${YELLOW}No WORKER_IPS set — skipping worker config${NC}\n"
fi

echo -e "${GREEN}=== Configuration files created ===${NC}"
echo ""
echo "Generated files:"
echo "  - controlplane.yaml"
[[ -n "${WORKER_IPS:-}" ]] && echo "  - worker.yaml"
echo "  - talosconfig"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  Run: ./scripts/2-apply-config.sh [fresh|existing]"
echo "  To join new nodes to an existing cluster: set JOIN_CONTROLPLANE_IPS / JOIN_WORKER_IPS, then run 'existing'"
