# Talos Configuration

This document describes the process for configuring Talos Linux nodes. For day-to-day operations, use the scripts in `./scripts/`.

## Cluster Hardware

3-node all-controlplane cluster (no dedicated workers). Workloads run on controlplane nodes via `allow-workloads` patch.

| Hostname      | IP             | Hardware                          | RAM  |
|---------------|----------------|-----------------------------------|------|
| server-luha-1 | 192.168.1.41   | Intel N100                        | 16GB |
| server-luha-2 | 192.168.1.55   | Mini PC Elegant P2 (Ryzen 3 4300U) | 16GB |
| server-luha-3 | 192.168.1.51   | Mini PC Elegant P2 (Ryzen 3 4300U) | 16GB |

## Quick Start with Scripts

### 1. Create configuration files

Source `.envrc` or export manually:

```sh
source .envrc
./scripts/1-create-config.sh
```

### 2. Apply configuration

```sh
# New cluster (insecure apply + bootstrap)
./scripts/2-apply-config.sh fresh

# Update existing cluster
./scripts/2-apply-config.sh existing

# Preview changes without applying
./scripts/2-apply-config.sh existing --dry-run
```

### Joining new nodes to an existing cluster

Set `JOIN_CONTROLPLANE_IPS` (and optionally `JOIN_CONTROLPLANE_HOSTNAMES`) in `.envrc`, then run `existing`. New nodes are applied insecurely since they haven't joined yet. Endpoints are updated automatically afterward.

```sh
export JOIN_CONTROLPLANE_IPS="192.168.1.99"
export JOIN_CONTROLPLANE_HOSTNAMES="server-luha-4"
./scripts/2-apply-config.sh existing
# After done, clear the JOIN vars in .envrc
```

Same pattern applies for workers via `JOIN_WORKER_IPS` / `JOIN_WORKER_HOSTNAMES`.

## Environment Variables

| Variable                    | Required | Description                                              |
|-----------------------------|----------|----------------------------------------------------------|
| `CLUSTER_NAME`              | yes      | Cluster name used in generated config                    |
| `CONTROL_PLANE_IPS`         | yes      | Comma-separated CP IPs; first is primary/bootstrap node  |
| `CONTROL_PLANE_HOSTNAMES`   | no       | Comma-separated hostnames, zipped with IPs               |
| `WORKER_IPS`                | no       | Comma-separated worker IPs; omit for CP-only cluster     |
| `WORKER_HOSTNAMES`          | no       | Comma-separated hostnames, zipped with WORKER_IPS        |
| `JOIN_CONTROLPLANE_IPS`     | no       | New CP nodes to join an existing cluster (insecure apply)|
| `JOIN_CONTROLPLANE_HOSTNAMES` | no     | Hostnames for JOIN_CONTROLPLANE_IPS                      |
| `JOIN_WORKER_IPS`           | no       | New worker nodes to join an existing cluster             |
| `JOIN_WORKER_HOSTNAMES`     | no       | Hostnames for JOIN_WORKER_IPS                            |

Hostnames are applied as inline patches at apply time — no per-node patch files needed.

## Secrets

`secrets.yaml` must exist in this directory. Generate once for a new cluster:

```sh
talosctl gen secrets -o secrets.yaml
```

> **Important:** Keep `secrets.yaml` out of version control.

## Manual Process

### Prerequisites

Boot nodes with a Talos Linux image from [talos.dev](https://www.talos.dev/). Verify disk and network before applying:

```sh
talosctl get disks --insecure --nodes <node-ip>
talosctl get links --insecure --nodes <node-ip>
```

### Generate base config

```sh
talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$PRIMARY_CP_IP:6443
```

Creates `controlplane.yaml`, `worker.yaml`, and `talosconfig`.

### Patch configs

```sh
# Controlplane
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

# Worker (if applicable)
talosctl machineconfig patch worker.yaml \
    --patch @patches/no-flannel.yaml \
    --patch @patches/dns.yaml \
    --patch @patches/kubernetes-version.yaml \
    --patch @patches/worker/disk.yaml \
    --output worker.yaml
```

### Fresh cluster setup

```sh
# Apply controlplane (insecure — node not yet in cluster)
talosctl apply-config --insecure --nodes $PRIMARY_CP_IP --file controlplane.yaml

# Configure endpoint and bootstrap
talosctl config endpoint --talosconfig talosconfig $PRIMARY_CP_IP
talosctl bootstrap --talosconfig talosconfig --nodes $PRIMARY_CP_IP

# Retrieve kubeconfig
talosctl kubeconfig alternative-kubeconfig --talosconfig talosconfig --nodes $PRIMARY_CP_IP
export KUBECONFIG=$(pwd)/alternative-kubeconfig
kubectl get nodes
```

### Existing cluster update

```sh
talosctl config endpoint --talosconfig talosconfig $CONTROL_PLANE_IPS
talosctl apply-config --talosconfig talosconfig --nodes $PRIMARY_CP_IP --file controlplane.yaml
```

## Troubleshooting

```sh
# Node health and logs
talosctl --talosconfig talosconfig --nodes 192.168.1.41 health
talosctl --talosconfig talosconfig --nodes 192.168.1.41 dmesg
talosctl --talosconfig talosconfig --nodes 192.168.1.41 logs kubelet
talosctl --talosconfig talosconfig --nodes 192.168.1.41 logs etcd

# Interactive dashboard
talosctl --talosconfig talosconfig --nodes 192.168.1.41 dashboard
```
