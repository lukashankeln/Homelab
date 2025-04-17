# Homelab
This repository contains the applications and configurations for my private home server infrastructure.

![](https://img.shields.io/badge/k3s-informational?style=flat-square&logo=k3s&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/ArgoCD-informational?style=flat-square&logo=argo&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Helm-informational?style=flat-square&logo=helm&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Gitea-informational?style=flat-square&logo=gitea&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Cilium-informational?style=flat-square&logo=cilium&logoColor=white&color=0366D6)

> [!IMPORTANT]
> This repository is developed in my privately hosted Gitea instance.
> The version on GitHub is a push mirror. Any changes made there will be overwritten during the next sync.

## Infrastructure
The infrastructure runs on a single-node k3s cluster hosted on an Intel N100-powered mini-PC with 8GB of RAM. Plans are underway to add a second node powered by a Raspberry Pi 4 to the cluster.

## GitOps with ArgoCD
ArgoCD is installed via the Helm chart located in `charts/argocd`. Updates to ArgoCD are automated using Gitea Actions. The following components are managed via ArgoCD:

- **Applications**: Found in `applications/`, deployed using `charts/argocd/templates/applications.yaml`.
- **Plain Kubernetes Manifests**: Located in `kubernetes/`, deployed via `applicationsets/deployments.yaml` using a Git directories generator.
- **Custom Resources**: Found in `custom-resources/`, deployed via `applicationsets/custom-resources.yaml` using a Git directories generator.
- **ApplicationSets**: Managed in `applicationsets/`, deployed using `charts/argocd/templates/applicationsets.yaml`.

## Cilium - CNI Provider
Cilium is used as the CNI provider and is installed via the Helm chart in `charts/cilium`. Updates are currently manual to better understand Cilium's update behavior.

## Applications
A variety of applications are deployed in the cluster, including:

- **[Argo Workflows](/applications/argo-workflows.yaml)**: Workflow engine for orchestrating jobs.
- **[Aspire Dashboard](/applications/aspire-dashboard.yaml)**: Lightweight OpenTelemetry dashboard.
- **[Cert-Manager](/applications/cert-manager.yaml)**: Automatic certificate generation for ingresses.
- **[Dashy](/applications/dashy.yaml)**: Centralized dashboard for managing applications.
- **[Docker UI](/applications/docker-ui.yaml)**: Docker registry with a management UI.
- **[Gitea](/applications/gitea.yaml)**: Self-hosted Git server with CI/CD capabilities.
- **[Kanboard](/applications/kanboard.yaml)**: Project management software.
- **[MetalLB](/kubernetes/metallb-system/configuration.yaml)**: Load balancer for bare-metal Kubernetes clusters.
- **[nginx](/applications/nginx-ingress.yaml)**: Ingress controller.
- **[Skooner](/applications/skooner.yaml)**: Kubernetes dashboard for cluster management.
- **[PostgreSQL](/kubernetes/postgres/)**: Open-source relational database.

## Secret Management
Secrets are managed using the External Secrets Operator. To enable it, create a Vault token as a Kubernetes secret:

```bash
kubectl create secret generic vault-token -n external-secrets-operator --from-literal=token=<token>
```

## Additional Resources
- **Network Policies**: Defined in `custom-resources/cilium-clusterwide-network-policies/`.
- **Persistent Volumes**: Configured in `custom-resources/persistent-volumes/`.
- **RBAC Configurations**: Found in `custom-resources/rbac/`.

This repository is continuously evolving to meet the needs of the home server infrastructure.
