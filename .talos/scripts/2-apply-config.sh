#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Talos Configuration Applier ===${NC}\n"

MODE="${1:-}"
DRY_RUN=""
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN="--dry-run" && echo -e "${YELLOW}DRY RUN MODE${NC}\n"

if [[ "$MODE" != "fresh" && "$MODE" != "existing" && "$MODE" != "join-controlplane" ]]; then
    echo -e "${RED}Error: Invalid or missing mode${NC}"
    echo ""
    echo "Usage: $0 [fresh|existing|join-controlplane] [--dry-run]"
    echo ""
    echo "  fresh             - New cluster: applies CP + workers insecurely, bootstraps"
    echo "  existing          - Update existing cluster: applies CP + workers"
    echo "  join-controlplane - Join additional CP nodes to a running cluster (no bootstrap)"
    echo "  --dry-run         - Preview changes without applying"
    echo ""
    exit 1
fi

if [[ -z "${CONTROL_PLANE_IPS:-}" ]]; then
    echo -e "${RED}Error: CONTROL_PLANE_IPS is not set${NC}"; exit 1
fi

IFS=',' read -ra CP_IP_ARRAY <<< "$CONTROL_PLANE_IPS"
IFS=',' read -ra CP_HOSTNAME_ARRAY <<< "${CONTROL_PLANE_HOSTNAMES:-}"
PRIMARY_CP_IP="${CP_IP_ARRAY[0]}"

if [[ -n "${WORKER_IPS:-}" ]]; then
    IFS=',' read -ra WORKER_IP_ARRAY <<< "$WORKER_IPS"
    IFS=',' read -ra WORKER_HOSTNAME_ARRAY <<< "${WORKER_HOSTNAMES:-}"
else
    WORKER_IP_ARRAY=()
    WORKER_HOSTNAME_ARRAY=()
fi

echo -e "${BLUE}Mode: $MODE${NC}"
echo -e "${GREEN}Control Plane IPs:     $CONTROL_PLANE_IPS${NC}"
echo -e "${GREEN}Control Plane Hostnames: ${CONTROL_PLANE_HOSTNAMES:-(auto)}${NC}"
[[ ${#WORKER_IP_ARRAY[@]} -gt 0 ]] && echo -e "${GREEN}Worker IPs: $WORKER_IPS${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALOS_DIR="$(dirname "$SCRIPT_DIR")"
cd "$TALOS_DIR"

[[ ! -f "controlplane.yaml" ]] && echo -e "${RED}Error: controlplane.yaml not found — run 1-create-config.sh first${NC}" && exit 1
[[ ${#WORKER_IP_ARRAY[@]} -gt 0 && ! -f "worker.yaml" ]] && echo -e "${RED}Error: worker.yaml not found — run 1-create-config.sh first${NC}" && exit 1
[[ "$MODE" == "existing" && ! -f "talosconfig" ]] && echo -e "${RED}Error: talosconfig not found${NC}" && exit 1
[[ "$MODE" == "join-controlplane" && ! -f "talosconfig" ]] && echo -e "${RED}Error: talosconfig not found${NC}" && exit 1

# Build inline hostname patch for a given hostname
hostname_patch() {
    local hostname="${1:-}"
    if [[ -n "$hostname" ]]; then
        printf 'apiVersion: v1alpha1\nkind: HostnameConfig\nhostname: %s\nauto: "off"' "$hostname"
    fi
}

apply_cp() {
    local ip="$1"
    local hostname="${2:-}"
    local insecure="${3:-false}"
    local extra_args=()

    [[ "$insecure" == "true" ]] && extra_args+=(--insecure) || extra_args+=(--talosconfig talosconfig)
    [[ -n "$hostname" ]] && extra_args+=(--config-patch "$(hostname_patch "$hostname")")
    [[ -n "$DRY_RUN" ]] && extra_args+=($DRY_RUN)

    echo -e "${BLUE}  Applying controlplane config to $ip${hostname:+ (hostname: $hostname)}...${NC}"
    talosctl apply-config "${extra_args[@]}" --nodes "$ip" --file controlplane.yaml
    echo -e "${GREEN}  ✓ Done${NC}"
}

apply_worker() {
    local ip="$1"
    local hostname="${2:-}"
    local insecure="${3:-false}"
    local extra_args=()

    [[ "$insecure" == "true" ]] && extra_args+=(--insecure) || extra_args+=(--talosconfig talosconfig)
    [[ -n "$hostname" ]] && extra_args+=(--config-patch "$(hostname_patch "$hostname")")
    [[ -n "$DRY_RUN" ]] && extra_args+=($DRY_RUN)

    echo -e "${BLUE}  Applying worker config to $ip${hostname:+ (hostname: $hostname)}...${NC}"
    talosctl apply-config "${extra_args[@]}" --nodes "$ip" --file worker.yaml
    echo -e "${GREEN}  ✓ Done${NC}"
}

if [[ "$MODE" == "fresh" ]]; then
    echo -e "${YELLOW}=== Applying controlplane config (insecure) ===${NC}"
    for i in "${!CP_IP_ARRAY[@]}"; do
        apply_cp "${CP_IP_ARRAY[$i]}" "${CP_HOSTNAME_ARRAY[$i]:-}" "true"
    done
    echo ""

    if [[ ${#WORKER_IP_ARRAY[@]} -gt 0 ]]; then
        echo -e "${YELLOW}=== Applying worker config (insecure) ===${NC}"
        for i in "${!WORKER_IP_ARRAY[@]}"; do
            apply_worker "${WORKER_IP_ARRAY[$i]}" "${WORKER_HOSTNAME_ARRAY[$i]:-}" "true"
        done
        echo ""
    fi

    echo -e "${YELLOW}=== Configuring endpoints ===${NC}"
    talosctl config endpoint --talosconfig talosconfig "${CP_IP_ARRAY[@]}"
    echo -e "${GREEN}✓ Endpoints configured${NC}\n"

    echo -e "${YELLOW}=== Bootstrapping cluster (primary: $PRIMARY_CP_IP) ===${NC}"
    echo "Waiting for node to be ready (retrying every 10s, up to 5 minutes)..."
    bootstrapped=false
    for attempt in $(seq 1 30); do
        if talosctl bootstrap --talosconfig talosconfig --nodes "$PRIMARY_CP_IP" 2>/dev/null; then
            bootstrapped=true
            break
        fi
        echo "  attempt $attempt/30 — not ready yet, retrying in 10s..."
        sleep 10
    done
    if [[ "$bootstrapped" != "true" ]]; then
        echo -e "${RED}Error: bootstrap failed after 30 attempts${NC}"; exit 1
    fi
    echo -e "${GREEN}✓ Cluster bootstrapped${NC}\n"

    echo -e "${YELLOW}=== Retrieving kubeconfig ===${NC}"
    echo "Waiting for Kubernetes API to be ready (retrying every 10s, up to 5 minutes)..."
    for attempt in $(seq 1 30); do
        if talosctl kubeconfig alternative-kubeconfig --talosconfig talosconfig --nodes "$PRIMARY_CP_IP" 2>/dev/null; then
            break
        fi
        echo "  attempt $attempt/30 — API not ready yet, retrying in 10s..."
        sleep 10
    done
    echo -e "${GREEN}✓ Kubeconfig saved to alternative-kubeconfig${NC}\n"

    echo -e "${GREEN}=== Fresh cluster setup complete! ===${NC}"
    echo "  export KUBECONFIG=$TALOS_DIR/alternative-kubeconfig"

elif [[ "$MODE" == "existing" ]]; then
    echo -e "${YELLOW}=== Configuring endpoints ===${NC}"
    talosctl config endpoint --talosconfig talosconfig "${CP_IP_ARRAY[@]}"
    echo -e "${GREEN}✓ Endpoints configured${NC}\n"

    echo -e "${YELLOW}=== Applying controlplane config ===${NC}"
    for i in "${!CP_IP_ARRAY[@]}"; do
        apply_cp "${CP_IP_ARRAY[$i]}" "${CP_HOSTNAME_ARRAY[$i]:-}" "false"
    done
    echo ""

    if [[ ${#WORKER_IP_ARRAY[@]} -gt 0 ]]; then
        echo -e "${YELLOW}=== Applying worker config ===${NC}"
        for i in "${!WORKER_IP_ARRAY[@]}"; do
            apply_worker "${WORKER_IP_ARRAY[$i]}" "${WORKER_HOSTNAME_ARRAY[$i]:-}" "false"
        done
        echo ""
    fi

    echo -e "${GREEN}=== Update complete — nodes will reboot if needed ===${NC}"

elif [[ "$MODE" == "join-controlplane" ]]; then
    # Apply controlplane config to all CP nodes except the primary (already bootstrapped)
    # Useful when adding new CP nodes to an existing cluster
    echo -e "${YELLOW}=== Joining additional controlplane nodes (insecure) ===${NC}"
    echo -e "${BLUE}Skipping primary ($PRIMARY_CP_IP) — already in cluster${NC}\n"

    if [[ ${#CP_IP_ARRAY[@]} -lt 2 ]]; then
        echo -e "${RED}Error: join-controlplane requires at least 2 IPs in CONTROL_PLANE_IPS${NC}"
        exit 1
    fi

    for i in "${!CP_IP_ARRAY[@]}"; do
        [[ "$i" -eq 0 ]] && continue  # skip primary
        apply_cp "${CP_IP_ARRAY[$i]}" "${CP_HOSTNAME_ARRAY[$i]:-}" "true"
    done
    echo ""

    echo -e "${YELLOW}=== Updating endpoints to include all CP nodes ===${NC}"
    talosctl config endpoint --talosconfig talosconfig "${CP_IP_ARRAY[@]}"
    echo -e "${GREEN}✓ Endpoints updated${NC}\n"

    echo -e "${GREEN}=== Done — new CP nodes are joining etcd automatically ===${NC}"
    echo "  Monitor with: talosctl --talosconfig talosconfig --nodes $PRIMARY_CP_IP health"
fi
