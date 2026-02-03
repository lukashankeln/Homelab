# Talos Configuration
## Prerequisites

**Environment:**
The following environment Variables must be present:

```env
CLUSTER_NAME: "<your-cluster-name>"
CONTROL_PLANE_IP: "<your-master-node>"
WORKER_IPS: "<list-of-worker-ips>"
```

**Secrets:** The `secrets.yaml` must exist in this folder. If this is your first Setup, generate the secrets like follows:
```sh
talosctl gen secrets -o secrets.yaml
```

**Nodes:** Your Nodes must be booted with a Talos Image!

**Network and Disk Configuration:** Check your Nodes Network and Disk Configuration like followed:
```sh
talosctl get disks --insecure --nodes <node-ip>
talosctl get links --insecure --nodes <node-ip>
```

**Configuration:** Generate the base configuration with the following command:
```sh
talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$CONTROL_PLANE_IP:6443
```

**Patches:** Adapt the machine configuration to your needs using patches:

```sh
talosctl machineconfig patch controlplane.yaml \
    --patch @patches/cni.yaml \
    --patch @patches/dns.yaml \
    --patch @patches/controlplane/hostname.yaml \
    --patch @patches/controlplane/disk.yaml \
    --patch @patches/controlplane/allow-workloads.yaml \
    --output controlplane.yaml

talosctl machineconfig patch worker.yaml \
    --patch @patches/cni.yaml \
    --patch @patches/dns.yaml \
    --patch @patches/worker/hostname.yaml \
    --patch @patches/worker/disk.yaml \
    --output worker.yaml
```

## Apply your Configuration

### For a fresh cluster




```sh
talosctl apply-config --insecure \
    --nodes $CONTROL_PLANE_IP \
    --file controlplane.yaml

```

```sh
for ip in "${WORKER_IPS[@]}"; do
  echo "=== Applying configuration to node $ip ==="
  talosctl apply-config --insecure \
    --nodes $ip \
    --file worker.yaml
  echo "Configuration applied to $ip"
  echo ""
done
```

Configure your Endpoints:

```
talosctl config endpoint --talosconfig talosconfig $CONTROL_PLANE_IP
```

Bootstrap the cluster:

```
talosctl bootstrap --talosconfig talosconfig --nodes $CONTROL_PLANE_IP
```

Get your KubeConfig:

```
talosctl kubeconfig alternative-kubeconfig --talosconfig talosconfig --nodes $CONTROL_PLANE_IP
```


### For an existing cluster

```sh
talosctl apply-config --talosconfig talosconfig \
    --nodes $CONTROL_PLANE_IP \
    --file controlplane.yaml
```

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
