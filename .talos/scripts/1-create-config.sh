#!/usr/bin/env bash

set -euo pipefail

# Script to create Talos configuration files
# Based on process.md documentation

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Talos Configuration Generator ===${NC}\n"

# Check required environment variables
if [[ -z "${CLUSTER_NAME:-}" ]]; then
    echo -e "${RED}Error: CLUSTER_NAME environment variable is not set${NC}"
    exit 1
fi

if [[ -z "${CONTROL_PLANE_IP:-}" ]]; then
    echo -e "${RED}Error: CONTROL_PLANE_IP environment variable is not set${NC}"
    exit 1
fi

if [[ -z "${WORKER_IPS:-}" ]]; then
    echo -e "${RED}Error: WORKER_IPS environment variable is not set${NC}"
    exit 1
fi

echo -e "${GREEN}Environment variables:${NC}"
echo "  CLUSTER_NAME: $CLUSTER_NAME"
echo "  CONTROL_PLANE_IP: $CONTROL_PLANE_IP"
echo "  WORKER_IPS: $WORKER_IPS"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALOS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$TALOS_DIR"

# Check if secrets.yaml exists
if [[ ! -f "secrets.yaml" ]]; then
    echo -e "${YELLOW}Warning: secrets.yaml not found. Generating new secrets...${NC}"
    talosctl gen secrets -o secrets.yaml
    echo -e "${GREEN}✓ Secrets generated${NC}\n"
else
    echo -e "${GREEN}✓ Using existing secrets.yaml${NC}\n"
fi

# Clean up old configuration files
echo -e "${YELLOW}Cleaning up old configuration files...${NC}"
rm -f controlplane.yaml talosconfig worker.yaml
echo -e "${GREEN}✓ Old configuration files removed${NC}\n"

# Generate base configuration
echo -e "${YELLOW}Generating base configuration...${NC}"
talosctl gen config --with-secrets secrets.yaml "$CLUSTER_NAME" "https://$CONTROL_PLANE_IP:6443"
echo -e "${GREEN}✓ Base configuration generated${NC}\n"

# Apply patches to controlplane
echo -e "${YELLOW}Patching controlplane configuration...${NC}"
talosctl machineconfig patch controlplane.yaml \
    --patch @patches/cni.yaml \
    --patch @patches/dns.yaml \
    --patch @patches/controlplane/hostname.yaml \
    --patch @patches/controlplane/disk.yaml \
    --patch @patches/controlplane/allow-workloads.yaml \
    --output controlplane.yaml
echo -e "${GREEN}✓ Controlplane configuration patched${NC}\n"

# Apply patches to worker
echo -e "${YELLOW}Patching worker configuration...${NC}"
talosctl machineconfig patch worker.yaml \
    --patch @patches/cni.yaml \
    --patch @patches/dns.yaml \
    --patch @patches/worker/hostname.yaml \
    --patch @patches/worker/disk.yaml \
    --output worker.yaml
echo -e "${GREEN}✓ Worker configuration patched${NC}\n"

echo -e "${GREEN}=== Configuration files created successfully! ===${NC}"
echo ""
echo "Generated files:"
echo "  - controlplane.yaml"
echo "  - worker.yaml"
echo "  - talosconfig"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  Run: ./scripts/2-apply-config.sh [fresh|existing]"
