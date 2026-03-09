#!/usr/bin/env bash

# Upgrade Talos on all nodes to the image defined in patches/*/disk.yaml.
#
# Usage:
#   ./4-upgrade.sh [--dry-run]
#
# Requires CONTROL_PLANE_IP and WORKER_IPS env vars (source .envrc).
# Upgrades the control plane first, waits for it to be ready, then upgrades
# each worker in sequence.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALOS_DIR="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}DRY RUN MODE - No changes will be applied${NC}\n"
fi

# ---------------------------------------------------------------------------
# Env vars
# ---------------------------------------------------------------------------
if [[ -z "${CONTROL_PLANE_IP:-}" || -z "${WORKER_IPS:-}" ]]; then
    echo -e "${RED}Error: CONTROL_PLANE_IP and WORKER_IPS must be set (source .talos/.envrc)${NC}" >&2
    exit 1
fi

IFS=',' read -ra WORKER_IP_ARRAY <<< "$WORKER_IPS"

# ---------------------------------------------------------------------------
# Resolve image from controlplane disk patch
# ---------------------------------------------------------------------------
CONTROLPLANE_DISK="$TALOS_DIR/patches/controlplane/disk.yaml"
if [[ ! -f "$CONTROLPLANE_DISK" ]]; then
    echo -e "${RED}Error: $CONTROLPLANE_DISK not found${NC}" >&2
    exit 1
fi

IMAGE="$(grep -oE 'image: \S+' "$CONTROLPLANE_DISK" | sed 's/image: //')"

if [[ -z "$IMAGE" ]]; then
    echo -e "${RED}Error: could not read image from $CONTROLPLANE_DISK${NC}" >&2
    exit 1
fi

TALOSCONFIG="$TALOS_DIR/talosconfig"
if [[ ! -f "$TALOSCONFIG" ]]; then
    echo -e "${RED}Error: talosconfig not found at $TALOSCONFIG${NC}" >&2
    exit 1
fi

echo -e "${GREEN}=== Talos Upgrade ===${NC}\n"
echo -e "Image:         ${BLUE}$IMAGE${NC}"
echo -e "Control plane: ${BLUE}$CONTROL_PLANE_IP${NC}"
echo -e "Workers:       ${BLUE}$WORKER_IPS${NC}\n"

# ---------------------------------------------------------------------------
# Upgrade helper
# ---------------------------------------------------------------------------
upgrade_node() {
    local node="$1"
    local image="$2"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[dry-run] talosctl upgrade --nodes $node --image $image${NC}"
        return
    fi

    talosctl upgrade \
        --talosconfig "$TALOSCONFIG" \
        --nodes "$node" \
        --image "$image" \
        --wait
}

wait_for_node() {
    local node="$1"
    echo -e "${YELLOW}Waiting for $node to become responsive...${NC}"
    local attempts=0
    until talosctl version \
            --talosconfig "$TALOSCONFIG" \
            --nodes "$node" \
            --short 2>/dev/null | grep -q "Tag:"; do
        attempts=$((attempts + 1))
        if [[ $attempts -ge 20 ]]; then
            echo -e "${RED}Timed out waiting for $node${NC}" >&2
            exit 1
        fi
        echo "  attempt $attempts/20 — retrying in 15s..."
        sleep 15
    done
    echo -e "${GREEN}✓ $node is responsive${NC}\n"
}

# ---------------------------------------------------------------------------
# Upgrade control plane
# ---------------------------------------------------------------------------
echo -e "${YELLOW}=== Upgrading control plane: $CONTROL_PLANE_IP ===${NC}"
upgrade_node "$CONTROL_PLANE_IP" "$IMAGE"
echo -e "${GREEN}✓ Control plane upgrade initiated${NC}\n"

if [[ "$DRY_RUN" == false ]]; then
    wait_for_node "$CONTROL_PLANE_IP"
fi

# ---------------------------------------------------------------------------
# Upgrade workers sequentially
# ---------------------------------------------------------------------------
for ip in "${WORKER_IP_ARRAY[@]}"; do
    echo -e "${YELLOW}=== Upgrading worker: $ip ===${NC}"
    upgrade_node "$ip" "$IMAGE"
    echo -e "${GREEN}✓ Worker $ip upgrade initiated${NC}\n"

    if [[ "$DRY_RUN" == false ]]; then
        wait_for_node "$ip"
    fi
done

echo -e "${GREEN}=== All nodes upgraded successfully ===${NC}"
