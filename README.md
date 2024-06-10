# Homelab
This repository contains the applications in my private homeserver infrastructure.

All applications described in this repository are managed via ArgoCD.

> [!IMPORTANT]  
> This Repository is developed in my privatly hosted Gitea Instance. 
> The version on Github is just a push mirror, all changes made there will be lost on the next sync.

[This](applications.yaml) application is used as the entry application.
From here the applications in [this](/applications/) Folder are created,
which contain the applications to be hosted.

## ArgoCD - Installation
ArgoCD is installed via the Helm Chart in the Folder _argocd_.


## Applications

### [Cert-Manager](/applications/cert-manager.yaml)

##### Prerequisites
```kubectl create secret generic cloudflare-api-key-secret -n cert-manager --from-literal=api-key="<your_cloudflare_secret>"```

### [Docker UI](/applications/docker-ui.yaml)
A Docker Registry with included UI used for management.

No persistent Volumes are used at this point, because every image saved in this registry
can be rebuild from their respective source if needed.


### [MetalLB](/applications/metallb.yaml)
MetalLB is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols.

For reference see [here](https://metallb.universe.tf/).

### [nginx](/applications/nginx-ingress.yaml)
nginx is used as the ingress controller.

### [seq](/applications/seq.yaml)
Seq is the self-hosted search, analysis, and alerting server built for structured log data.

For reference see [here](https://datalust.co/seq).

### [skooner](/applications/skooner.yaml)

Skooner is an open source Kubernetes dashboard that helps to understand & manage your cluster.
Via the dashboard, you can manage your cluster's components and gain an in-depth look at its health and viability.

For reference see [here](https://skooner.io/).

### [Postgres](/applications/postgres.yaml)
PostgreSQL is a powerful, open source object-relational database.

For reference see [here](https://www.postgresql.org/).

## SetUp
TODO: Move this to a secret

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: postgres
  labels:
    app: postgres
data:
  POSTGRES_USER: <user>
  POSTGRES_PASSWORD: <password>
```

