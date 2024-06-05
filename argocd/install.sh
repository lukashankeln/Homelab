helm dependency build

helm upgrade --values ./values.yaml --namespace argocd argocd .
