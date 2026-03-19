# Homelab
This repository contains the applications and configurations for my private home server infrastructure.

![](https://img.shields.io/badge/Talos-informational?style=flat-square&logo=talos&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/ArgoCD-informational?style=flat-square&logo=argo&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Helm-informational?style=flat-square&logo=helm&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Gitea-informational?style=flat-square&logo=gitea&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Cilium-informational?style=flat-square&logo=cilium&logoColor=white&color=0366D6)

> [!IMPORTANT]
> This repository is developed in my privately hosted Gitea instance.
> The version on GitHub is a push mirror. Any changes made there will be overwritten during the next sync.

## Infrastructure
The infrastructure runs on a Talos Linux Kubernetes cluster composed of two nodes.

- Controlplane: Intel N100 mini-PC with 8GB RAM
- Worker: Intel N97 mini-PC with 16GB RAM

Talos is an immutable, minimal Kubernetes OS designed for security and ease of management. Configuration is managed declaratively in the `.talos/` directory.

## GitOps with ArgoCD
ArgoCD manages itself and all other applications from this repository. The primary ArgoCD Application is `applications/argocd.yaml` and ArgoCD reconciles the rest of the repo.

Key locations:

- `applications/argocd.yaml` — ArgoCD self-management manifest.
- `applications/` — ArgoCD Application manifests for all services.
- `kubernetes/` — plain Kubernetes manifests deployed via ApplicationSets.
- `custom-resources/applicationsets/` — ApplicationSet manifests (generators and templates).
- `custom-resources/appprojects/` — ArgoCD AppProject manifests (scoping, source/destination restrictions).

Updates to ArgoCD and all apps are automated via Renovate.

## Cilium - CNI, Load Balancing & Gateway
Cilium is the CNI provider, handles LoadBalancer services (LB-IPAM with L2 announcements), and serves as the Gateway API implementation. Configured via:
- Cluster-wide network policies: `custom-resources/cilium-clusterwide-network-policies/`
- Load balancer IP pools: `custom-resources/cilium/ipPool.yaml`
- L2 announcement policies: `custom-resources/cilium/l2Announcement.yaml`

## Applications

### Networking & Ingress
- **[Cilium](/applications/cilium.yaml)**: CNI, L2 load balancing, Hubble observability, and Gateway API implementation.
- **[Gateway API](/applications/gateway-api.yaml)**: Kubernetes Gateway API CRDs.
- **[Contour](/applications/contour.yaml)**: Ingress controller.
- **[Cert-Manager](/applications/cert-manager.yaml)**: Automatic TLS certificate provisioning.
- **[External DNS](/applications/external-dns.yaml)**: Automatic DNS record management via Cloudflare.
- **[Tailscale](/applications/tailscale.yaml)**: VPN operator for secure remote access.
- **[Metrics Server](/applications/metrics-server.yaml)**: Kubernetes resource metrics (CPU/memory) for HPA and `kubectl top`.

### GitOps & CI/CD
- **[ArgoCD](/applications/argocd.yaml)**: GitOps controller managing all cluster applications.
- **[Argo Workflows](/applications/argo-workflows.yaml)**: Workflow engine for orchestrating jobs.
- **[Gitea](/applications/gitea.yaml)**: Self-hosted Git server.
- **[Gitea Actions](/applications/gitea-actions.yaml)**: CI/CD runners for Gitea.
- **[Renovate Operator](/applications/renovate-operator.yaml)**: Automated dependency updates.

### Secret & Storage Management
- **[Vault](/applications/vault.yaml)**: HashiCorp Vault for secret storage.
- **[External Secrets Operator](/applications/external-secrets-operator.yaml)**: Syncs secrets from Vault into Kubernetes. Requires a bootstrap secret: `kubectl create secret generic vault-token -n external-secrets-operator --from-literal=token=<token>`
- **[Cloud Native Postgres Operator](/applications/cloud-native-postgres-operator.yaml)**: PostgreSQL operator (CNPG) for managed database clusters.
- **[NFS Provisioner](/applications/nfs-provisioner.yaml)**: Dynamic NFS-backed PersistentVolume provisioning.

### Monitoring & Observability
- **[Kube Prometheus Stack](/applications/kube-prometheus-stack.yaml)**: Prometheus, Grafana, and Alertmanager for cluster monitoring.
- **[Gatus](/applications/gatus.yaml)**: Uptime and health status monitoring dashboard.

### Applications
- **[Homepage](/applications/homepage.yaml)**: Unified dashboard for all services.
- **[Docker UI](/applications/docker-ui.yaml)**: Docker registry with a management UI.
- **[Kanboard](/applications/kanboard.yaml)**: Project management (Kanban board).
- **[Ntfy](/applications/ntfy.yaml)**: Self-hosted push notification service.
- **[Mogenius Operator](/applications/mogenius.yaml)**: Cluster management operator.
- **[Too Restful API](/applications/too-restful-api.yaml)**: REST API service.
- **[Webservice](/applications/webservice.yaml)**: Generic web service deployment.
- **[Workflow](/applications/workflow.yaml)**: Generic workflow deployment.

## Additional Resources
- **Network Policies**: `custom-resources/cilium-clusterwide-network-policies/`
- **Persistent Volumes**: `custom-resources/persistent-volumes/`
- **Postgres Clusters**: `custom-resources/postgres-operator/`
- **RBAC Configurations**: `custom-resources/rbac/`
