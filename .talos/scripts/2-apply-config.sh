#!/usr/bin/env bash

set -euo pipefail

# Script to apply Talos configuration to machines
# Based on process.md documentation

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Talos Configuration Applier ===${NC}\n"

# Parse arguments
MODE="${1:-}"
DRY_RUN=""

if [[ "${2:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    echo -e "${YELLOW}DRY RUN MODE - No changes will be applied${NC}\n"
fi

# Check for mode argument
if [[ "$MODE" != "fresh" && "$MODE" != "existing" ]]; then
    echo -e "${RED}Error: Invalid or missing mode${NC}"
    echo ""
    echo "Usage: $0 [fresh|existing] [--dry-run]"
    echo ""
    echo "  fresh    - For a new cluster (uses --insecure, bootstraps cluster)"
    echo "  existing - For an existing cluster (uses --talosconfig)"
    echo "  --dry-run - Preview changes without applying them"
    echo ""
    exit 1
fi

# Check required environment variables
if [[ -z "${CONTROL_PLANE_IP:-}" ]]; then
    echo -e "${RED}Error: CONTROL_PLANE_IP environment variable is not set${NC}"
    exit 1
fi

if [[ -z "${WORKER_IPS:-}" ]]; then
    echo -e "${RED}Error: WORKER_IPS environment variable is not set${NC}"
    exit 1
fi

echo -e "${BLUE}Mode: $MODE cluster${NC}"
echo -e "${GREEN}Control Plane IP: $CONTROL_PLANE_IP${NC}"
echo -e "${GREEN}Worker IPs: $WORKER_IPS${NC}"
echo ""

# Convert WORKER_IPS to array
IFS=',' read -ra WORKER_IP_ARRAY <<< "$WORKER_IPS"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALOS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$TALOS_DIR"

# Check if configuration files exist
if [[ ! -f "controlplane.yaml" ]]; then
    echo -e "${RED}Error: controlplane.yaml not found${NC}"
    echo "Run ./scripts/1-create-config.sh first"
    exit 1
fi

if [[ ! -f "worker.yaml" ]]; then
    echo -e "${RED}Error: worker.yaml not found${NC}"
    echo "Run ./scripts/1-create-config.sh first"
    exit 1
fi

if [[ "$MODE" == "existing" && ! -f "talosconfig" ]]; then
    echo -e "${RED}Error: talosconfig not found${NC}"
    echo "For existing clusters, talosconfig is required"
    exit 1
fi

# Apply configuration based on mode
if [[ "$MODE" == "fresh" ]]; then
    # Fresh cluster setup
    echo -e "${YELLOW}=== Applying configuration to control plane (insecure) ===${NC}"
    talosctl apply-config --insecure \
        --nodes "$CONTROL_PLANE_IP" \
        --file controlplane.yaml \
        $DRY_RUN
    echo -e "${GREEN}✓ Control plane configuration applied${NC}\n"

    echo -e "${YELLOW}=== Applying configuration to workers (insecure) ===${NC}"
    for ip in "${WORKER_IP_ARRAY[@]}"; do
        echo -e "${BLUE}Applying configuration to node $ip...${NC}"
        talosctl apply-config --insecure \
            --nodes "$ip" \
            --file worker.yaml \
            $DRY_RUN
        echo -e "${GREEN}✓ Configuration applied to $ip${NC}\n"
    done

    echo -e "${YELLOW}=== Configuring endpoints ===${NC}"
    talosctl config endpoint --talosconfig talosconfig "$CONTROL_PLANE_IP"
    echo -e "${GREEN}✓ Endpoints configured${NC}\n"

    echo -e "${YELLOW}=== Bootstrapping cluster ===${NC}"
    echo "Waiting 30 seconds for nodes to be ready..."
    sleep 30
    talosctl bootstrap --talosconfig talosconfig --nodes "$CONTROL_PLANE_IP"
    echo -e "${GREEN}✓ Cluster bootstrapped${NC}\n"

    echo -e "${YELLOW}=== Retrieving kubeconfig ===${NC}"
    echo "Waiting 60 seconds for Kubernetes API to be ready..."
    sleep 60
    talosctl kubeconfig alternative-kubeconfig --talosconfig talosconfig --nodes "$CONTROL_PLANE_IP"
    echo -e "${GREEN}✓ Kubeconfig retrieved and saved to alternative-kubeconfig${NC}\n"

    echo -e "${GREEN}=== Fresh cluster setup complete! ===${NC}"
    echo ""
    echo "Your kubeconfig is available at: ./alternative-kubeconfig"
    echo "Use it with: export KUBECONFIG=$TALOS_DIR/alternative-kubeconfig"

else
    # Existing cluster update
    echo -e "${YELLOW}=== Configuring endpoints ===${NC}"
    talosctl config endpoint --talosconfig talosconfig "$CONTROL_PLANE_IP"
    echo -e "${GREEN}✓ Endpoints configured${NC}\n"

    echo -e "${YELLOW}=== Applying configuration to control plane ===${NC}"
    talosctl apply-config --talosconfig talosconfig \
        --nodes "$CONTROL_PLANE_IP" \
        --file controlplane.yaml \
        $DRY_RUN
    echo -e "${GREEN}✓ Control plane configuration applied${NC}\n"

    echo -e "${YELLOW}=== Applying configuration to workers ===${NC}"
    for ip in "${WORKER_IP_ARRAY[@]}"; do
        echo -e "${BLUE}Applying configuration to node $ip...${NC}"
        talosctl apply-config --talosconfig talosconfig \
            --nodes "$ip" \
            --file worker.yaml \
            $DRY_RUN
        echo -e "${GREEN}✓ Configuration applied to $ip${NC}\n"
    done

    echo -e "${GREEN}=== Existing cluster update complete! ===${NC}"
    echo ""
    echo "Configuration has been applied to all nodes."
    echo "Nodes will automatically reboot if necessary."
fi
