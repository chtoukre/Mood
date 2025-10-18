# PostgreSQL on Kubernetes (Helm)

This guide explains how PostgreSQL is deployed locally in **Minikube** using a **Helm chart**.
This replaces raw YAML manifests with a cleaner and maintainable setup.

✅ Use cases:
- Local development database
- Test data generation
- Works alongside AWS RDS setup (no conflict)

---

## 🎯 Goal of this setup

| Feature | Status |
|----------|--------|
| PostgreSQL runs inside Kubernetes | ✅ |
| Persistent storage (PVC) | ✅ |
| Configurable DB, user, password | ✅ |
| Ready to connect from Grafana & Python | ✅ |
| Simple lifecycle (`install/stop/status`) scripts | ✅ |

---

## 📂 Folder Structure

```

k8s/
└── charts/
└── postgres/
├── Chart.yaml
├── values.yaml
└── templates/
├── deployment.yaml
├── service.yaml
└── pvc.yaml

```

---

## ⚙️ Default Configuration (`values.yaml`)

```yaml
image:
  repository: postgres
  tag: "15"
  pullPolicy: IfNotPresent

postgres:
  db: moodtracker
  user: mooduser
  password: moodpass

service:
  name: postgres
  type: ClusterIP
  port: 5432

persistence:
  enabled: true
  size: 512Mi
  storageClass: ""

resources: {}
nodeSelector: {}
tolerations: []
affinity: {}
```

> ✅ You can override password / size with Helm flags

---

## 🚀 Install PostgreSQL

```bash
helm upgrade --install postgres k8s/charts/postgres \
  --set postgres.db=moodtracker \
  --set postgres.user=mooduser \
  --set-string postgres.password=moodpass \
  --set persistence.size=512Mi
```

Check status:

```bash
kubectl get pods -l app=postgres
kubectl get svc postgres
```

---

## 🔌 Connect to PostgreSQL

### From your laptop via port-forward

```bash
kubectl port-forward svc/postgres 5432:5432
```

Then:

```bash
psql -h 127.0.0.1 -U mooduser -d moodtracker
```

---

### From inside Kubernetes

```bash
kubectl run -it psql --image=postgres --restart=Never -- \
  psql -h postgres.default.svc.cluster.local -U mooduser -d moodtracker
```

---

## 🛑 Uninstall / Cleanup

```bash
helm uninstall postgres
kubectl delete pvc postgres-pvc
```

---

## ✅ Benefits of Helm for Postgres

| Advantage           | Why it matters                         |
| ------------------- | -------------------------------------- |
| Configurable values | Easy to change DB name, user, password |
| Clear templates     | Easier maintenance                     |
| One-command deploy  | Fast setup                             |
| Works with scripts  | ✅ backup/restore compatible            |

---

Next: 👉 connect this Postgres to **Grafana** or use it with **local Python scripts**.

```

```

