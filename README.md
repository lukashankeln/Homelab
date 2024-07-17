# Homelab
This repository contains the applications in my private homeserver infrastructure.

![](https://img.shields.io/badge/k3s-informational?style=flat-square&logo=k3s&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/ArgoCD-informational?style=flat-square&logo=argo&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Helm-informational?style=flat-square&logo=helm&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Gitea-informational?style=flat-square&logo=gitea&logoColor=white&color=0366D6)
![](https://img.shields.io/badge/Cilium-informational?style=flat-square&logo=cilium&logoColor=white&color=0366D6)

> [!IMPORTANT]
> This Repository is developed in my privatly hosted Gitea Instance.
> The version on Github is just a push mirror, all changes made there will be lost on the next sync.

## Infrastructure
Currently I am running on a single Node k3s-Cluster.
My current Node is a Intel N100 powered Mini-PC utilising 8GB of RAM.

I am planning on adding a second Node powered by a Raspberry Pi 4 into the cluster.

## ArgoCD and GitOps
ArgoCD is installed via the Helm Chart in `charts/argocd`.
Updates to ArgoCD are automatically installed using Gitea Actions.

This also deploys the two main Applications `charts/argocd/templates/applications.yaml` and `charts/argocd/templates/applicationsets.yaml`
from which all other Applications and ApplicationSets are beeing deployed.

- Applications that are deployed using ArgoCD Applications can be found in `./applications` those are beeing deployed using the `charts/argocd/templates/applications.yaml`
- Applications that are deployed using plain kubernetes manifest files can be found in `./kubernetes` those are beeing deployed by the `applicationsets/deployments.yaml` leveraging a git directories generator
- Custom Resources and other plain manifests can be found in `./custom-resources` and are beeing deployed from the `applicationsets/custom-resources.yaml` also leveraging a git directories generator
- The ApplicationSets in `./applicationsets` are beeing deployed using the `charts/argocd/templates/applicationsets.yaml`

## Cilium - Installation
I am running Cilium as a CNI Provider. Cilium is installed via the Helm Chart in `charts/cilium`.
Currently Cilium will not be automatically updated, as I need to get a feeling for Ciliums update behavior first.



## Applications

### [Dotnet Aspire Dashboard](/applications/aspire-dashboard.yaml)
The dotnet Aspire Dashboard was initially developed to be used in local development.
That makes it a perfect tool for this situation as it has really low resource consumption in comparison
to other Open Telementry Dashboard alternatives.

### [Cert-Manager](/applications/cert-manager.yaml)

##### Prerequisites
```kubectl create secret generic cloudflare-api-key-secret -n cert-manager --from-literal=api-key="<your_cloudflare_secret>"```

### [Dashy](/applications/dashy.yaml)
Dashy is a Dashboard software that I use to group all the applications that are running
in my infrastructure into a single Dashboard.

### [Docker UI](/applications/docker-ui.yaml)
A Docker Registry with included UI used for management.

No persistent Volumes are used at this point, because every image saved in this registry
can be rebuild from their respective source if needed.

### [Gitea](/applications/gitea.yaml) and [Gitea Runner](/applications/gitea-runner.yaml)
Gitea is a git management server that is very similar to Github.
Even Github Actions can seamlessly be used in Gitea.

I use Gitea to host my private projects and renovate configurations.

### [MetalLB](/applications/metallb.yaml)
MetalLB is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols.

For reference see [here](https://metallb.universe.tf/).

### [nginx](/applications/nginx-ingress.yaml)
nginx is used as the ingress controller.


### [skooner](/applications/skooner.yaml)

Skooner is an open source Kubernetes dashboard that helps to understand & manage your cluster.
Via the dashboard, you can manage your cluster's components and gain an in-depth look at its health and viability.

For reference see [here](https://skooner.io/).

### [Postgres](/applications/postgres.yaml)
PostgreSQL is a powerful, open source object-relational database.

For reference see [here](https://www.postgresql.org/).

##### Prerequisites
```bash
kubectl create secret generic postgres-user-pass -n postgres --from-literal=POSTGRES_USER=<user> --from-literal=POSTGRES_PASSWORD=<password>
```


## Todos

##### Secret Management
To improve on secrets management within the cluster I plan on implementing the External Secrets Operator and an accompanying secret store like Hashicorp Vault.
