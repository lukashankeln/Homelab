# Talos Configuration

This document describes the manual process for configuring Talos Linux nodes. For automated setup, use the scripts in `./scripts/`.

## Quick Start with Scripts

1. **Create configuration files:**
   ```sh
   export CLUSTER_NAME="homelab"
   export CONTROL_PLANE_IP="192.168.1.10"
   export WORKER_IPS="192.168.1.11,192.168.1.12"

   ./scripts/1-create-config.sh
   ```

2. **Apply configuration:**
   ```sh
   # For a fresh cluster
   ./scripts/2-apply-config.sh fresh

   # For an existing cluster
   ./scripts/2-apply-config.sh existing

   # Preview changes without applying
   ./scripts/2-apply-config.sh existing --dry-run
   ```

## Manual Process

### Prerequisites

**Environment Variables:**
The following environment variables must be set:

```sh
export CLUSTER_NAME="<your-cluster-name>"
export CONTROL_PLANE_IP="<your-master-node-ip>"
export WORKER_IPS="<comma-separated-worker-ips>"  # e.g., "192.168.1.11,192.168.1.12"
```

**Secrets:**
The `secrets.yaml` file must exist in this directory. For first-time setup, generate secrets:
```sh
talosctl gen secrets -o secrets.yaml
```

> ⚠️ **Important:** Keep `secrets.yaml` secure and never commit it to version control.

**Nodes:**
Your nodes must be booted with a Talos Linux image. Download images from [talos.dev](https://www.talos.dev/).

**Network and Disk Configuration:**
Verify your nodes' network and disk configuration:
```sh
talosctl get disks --insecure --nodes <node-ip>
talosctl get links --insecure --nodes <node-ip>
```

**Configuration:**
Generate the base configuration:
```sh
talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$CONTROL_PLANE_IP:6443
```

This creates three files:
- `controlplane.yaml` - Control plane node configuration
- `worker.yaml` - Worker node configuration
- `talosconfig` - CLI configuration for managing the cluster

**Patches:**
Apply machine-specific patches to customize the configuration:

```sh
# Patch control plane configuration
talosctl machineconfig patch controlplane.yaml \
    --patch @patches/cni.yaml \
    --patch @patches/dns.yaml \
    --patch @patches/controlplane/hostname.yaml \
    --patch @patches/controlplane/disk.yaml \
    --patch @patches/controlplane/allow-workloads.yaml \
    --output controlplane.yaml

# Patch worker configuration
talosctl machineconfig patch worker.yaml \
    -resh Cluster Setup

Apply configuration to the control plane:
```sh
talosctl apply-config --insecure \
    --nodes $CONTROL_PLANE_IP \
    --file controlplane.yaml
```

Apply configuration to workers:
```sh
# Convert comma-separated IPs to array
IFS=',' read -ra WORKER_IP_ARRAY <<< "$WORKER_IPS"

for ip in "${WORKER_IP_ARRAY[@]}"; do
  echo "=== Applying configuration to node $ip ==="
  talosctl apply-config --insecure \
    --nodes $ip \
    --file worker.yaml
  echo "Configuration applied to $ip"
  echo ""
done
```

Configure endpoints:
```sh
talosctl config endpoint --talosconfig talosconfig $CONTROL_PLANE_IP
```

Bootstrap the cluster:
```sh
talosctl bootstrap --talosconfig talosconfig --nodes $CONTROL_PLANE_IP
```

> ℹ️ Wait a few minutes for the cluster to initialize before proceeding.

Retrieve kubeconfig:
```sh
talosctl kubeconfig alternative-kubeconfig --talosconfig talosconfig --nodes $CONTROL_PLANE_IP
export KUBECONFIG=$(pwd)/alternative-kubeconfig
kubectl get nodes
```

### Existing Cluster Update

Configure endpoints (in case they changed):
```sh
talosctl config endpoint --talosconfig talosconfig $CONTROL_PLANE_IP
```

Apply configuration to the control plane:
```sh
talosctl apply-config --talosconfig talosconfig \
    --nodes $CONTROL_PLANE_IP \
    --file controlplane.yaml
```

Apply configuration to workers:
```sh
# Convert comma-separated IPs to array
IFS=',' read -ra WORKER_IP_ARRAY <<< "$WORKER_IPS"

for ip in "${WORKER_IP_ARRAY[@]}"; do
  echo "=== Applying configuration to node $ip ==="
  talosctl apply-config --talosconfig talosconfig \
    --nodes $ip \
    --file worker.yaml
  echo "Configuration applied to $ip"
  echo ""
done
```

> ℹ️ Nodes will automatically reboot if necessary to apply the changes.

## Troubleshooting

**Check node status:**
```sh
talosctl --talosconfig talosconfig --nodes $CONTROL_PLANE_IP health
talosctl --talosconfig talosconfig --nodes $CONTROL_PLANE_IP dmesg
```

**View service logs:**
```sh
talosctl --talosconfig talosconfig --nodes $CONTROL_PLANE_IP logs kubelet
talosctl --talosconfig talosconfig --nodes $CONTROL_PLANE_IP logs etcd
```

**Interactive dashboard:**
```sh
talosctl --talosconfig talosconfig --nodes $CONTROL_PLANE_IP dashboard
```sh
for ip in "${WORKER_IPS[@]}"; do
  echo "=== Applying configuration to node $ip ==="
  talosctl apply-config --talosconfig talosconfig \
    --nodes $ip \
    --file worker.yaml
  echo "Configuration applied to $ip"
  echo ""
done
```
