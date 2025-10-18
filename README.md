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
The infrastructure runs on a small k3s cluster composed of two nodes, both running Ubuntu and k3s.

- Controlplane: Intel N100 mini-PC with 8GB RAM
- Worker: Intel N97 mini-PC with 16GB RAM

## GitOps with ArgoCD
ArgoCD now manages itself from this repository. The primary ArgoCD Application is `applications/argocd.yaml` and ArgoCD will reconcile the rest of the repo.

Key locations:

- `applications/argocd.yaml` — ArgoCD self-management (the ArgoCD application manifest).
- `applications/` — application-level ArgoCD Application manifests for services and charts.
- `kubernetes/` — plain Kubernetes manifests that are deployed via ApplicationSets.
- `custom-resources/applicationsets/` — ApplicationSet manifests (generators and templates) used to create many Applications from directories or lists.
- `custom-resources/appprojects/` — ArgoCD AppProject manifests (project scoping, source/destination restrictions).

ArgoCD is installed initially via the Helm chart but is now configured to self-manage using `applications/argocd.yaml`. Updates to ArgoCD and apps are automated via Renovate.

## Cilium - CNI Provider
Cilium is used as the CNI provider. It's deployed through the repository (see `applications/cilium.yaml`) and configured with cluster-wide network policies under `custom-resources/cilium-clusterwide-network-policies/`.

## Applications
A variety of applications are deployed in the cluster, including:

- **[Argo Workflows](/applications/argo-workflows.yaml)**: Workflow engine for orchestrating jobs.
- **[Aspire Dashboard](/applications/aspire-dashboard.yaml)**: Lightweight OpenTelemetry dashboard.
- **[Cert-Manager](/applications/cert-manager.yaml)**: Automatic certificate generation for ingresses.
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
