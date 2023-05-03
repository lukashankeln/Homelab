# Homelab
Setup for my private Homelab infrastructure


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