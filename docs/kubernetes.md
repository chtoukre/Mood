# Kubernetes (Minikube) Setup

This guide explains how to run the Mood Tracker stack entirely on **Kubernetes (Minikube)** using your manifests:
- Local **PostgreSQL** for development (`postgres-moodtracker/`)
- **Grafana** backed by its own Postgres (`postgres-grafana/`)
- **AWS SSM proxy** (`ssm-proxy/`) to reach **private RDS** from inside the cluster

> Namespace: **default** (as per your files)

---

## 1) Prerequisites

- Minikube installed and running
- kubectl + Helm installed
- AWS CLI configured (for SSM proxy to AWS)
- Terraform deployed infra (to obtain `bastion_instance_id` & `db_endpoint`)

Start Minikube:
```bash
minikube start
kubectl get nodes
````

---

## 2) Deploy Local Postgres (Dev/Test)

This Postgres is used for:

* local testing
* Python-generated data
* quick Grafana dashboards without AWS

Apply manifests:

```bash
kubectl apply -f k8s/postgres-moodtracker/postgres-deployment.yaml
kubectl apply -f k8s/postgres-moodtracker/postgres-service.yaml
```

Verify:

```bash
kubectl get pods -l app=postgres
kubectl get svc postgres
```

Test from a debug pod:

```bash
kubectl run -it --rm netshoot --image=nicolaka/netshoot --restart=Never -- \
  nc -zv postgres.default.svc.cluster.local 5432
```

---

## 3) Deploy Grafana (+ its own DB)

Grafana is configured to use its **own Postgres** (`grafana-postgres`) for persistence.

Apply manifests:

```bash
kubectl apply -f k8s/postgres-grafana/postgres-pvc.yaml
kubectl apply -f k8s/postgres-grafana/postgres-deployment.yaml
kubectl apply -f k8s/postgres-grafana/postgres-service.yaml

kubectl apply -f k8s/grafana-deployment.yaml
kubectl apply -f k8s/grafana-service.yaml
```

Access Grafana:

```bash
minikube service grafana --url
# Or NodePort: http://localhost:32000  (as per grafana-service.yaml)
# Login: admin / admin
```

---

## 4) Deploy AWS SSM Proxy (Helm)

This chart opens a **secure SSM tunnel** via the Bastion EC2 to the **private RDS**,
and exposes it as a Service `postgres-rds:5432` for in-cluster access (Grafana, scripts, pods).

From repo root:

```bash
# Export AWS credentials (temporary or long-lived)
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...   # if applicable

# Pull Terraform outputs
export BASTION_ID=$(cd infra && terraform output -raw bastion_instance_id)
export RDS_ENDPOINT=$(cd infra && terraform output -raw db_endpoint)

# Install Helm chart (default namespace)
helm install ssm-proxy k8s/ssm-proxy \
  --set aws.region=eu-west-3 \
  --set bastionId="$BASTION_ID" \
  --set rds.endpoint="$RDS_ENDPOINT" \
  --set-string aws.accessKeyId="$AWS_ACCESS_KEY_ID" \
  --set-string aws.secretAccessKey="$AWS_SECRET_ACCESS_KEY" \
  --set-string aws.sessionToken="${AWS_SESSION_TOKEN}"
```

Check readiness:

```bash
kubectl get pods -l app=ssm-proxy
kubectl get svc postgres-rds
kubectl get endpoints postgres-rds
# ✅ Should show one or more pod IPs with :5432
```

Connectivity test:

```bash
kubectl run -it --rm netshoot --image=nicolaka/netshoot --restart=Never -- \
  nc -zv postgres-rds.default.svc.cluster.local 5432
```

---

## 5) Configure Grafana to AWS RDS (via SSM)

In Grafana UI → **Connections → Data sources → Add data source → PostgreSQL**:

* **Host**: `postgres-rds.default.svc.cluster.local:5432`
* **Database**: `postgres` (or your DB name)
* **User**: your RDS user (e.g., `admin` or app user)
* **Password**: from AWS Secrets Manager (paste temporarily)
* **TLS/SSL**: `require` (works); for production use `verify-ca` with AWS CA bundle

> AWS CA bundle:
> [https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem)

(Optional) Mount CA to Grafana pod and set **SSL Mode = verify-ca**, **Root cert path** accordingly.

---

## 6) Connect Python Scripts

For local dev Postgres:

```
host="postgres.default.svc.cluster.local"
port=5432
dbname="moodtracker"
user="mooduser"
password="moodpass"
```

For AWS RDS **from inside cluster**:

```
host="postgres-rds.default.svc.cluster.local"
port=5432
dbname="<your_db>"
user="<your_user>"
password="<your_password>"
```

> For local laptop direct access to RDS, use a **local SSM port-forward session** via AWS CLI and target `127.0.0.1:5432`.

---

## 7) Optional: Ingress for Grafana

If you prefer **[http://grafana.local/](http://grafana.local/)** instead of NodePort, enable Ingress:

1. Enable Ingress addon in Minikube:

```bash
minikube addons enable ingress
```

2. Example Ingress (create `k8s/grafana-ingress.yaml`):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: grafana.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 3000
```

3. Add to `/etc/hosts`:

```
127.0.0.1 grafana.local
```

4. Apply:

```bash
kubectl apply -f k8s/grafana-ingress.yaml
```

---

## 8) One-Command Installer (Helper Script)

Create `k8s/setup.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Namespace = default (no creation needed)

echo "▶️ Deploy Postgres (dev)..."
kubectl apply -f k8s/postgres-moodtracker/postgres-deployment.yaml
kubectl apply -f k8s/postgres-moodtracker/postgres-service.yaml

echo "▶️ Deploy Grafana Postgres + Grafana..."
kubectl apply -f k8s/postgres-grafana/postgres-pvc.yaml
kubectl apply -f k8s/postgres-grafana/postgres-deployment.yaml
kubectl apply -f k8s/postgres-grafana/postgres-service.yaml
kubectl apply -f k8s/grafana-deployment.yaml
kubectl apply -f k8s/grafana-service.yaml

echo "▶️ Install SSM proxy (Helm)..."
: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY}"

BASTION_ID=$(cd infra && terraform output -raw bastion_instance_id)
RDS_ENDPOINT=$(cd infra && terraform output -raw db_endpoint)

helm upgrade --install ssm-proxy k8s/ssm-proxy \
  --set aws.region=eu-west-3 \
  --set bastionId="$BASTION_ID" \
  --set rds.endpoint="$RDS_ENDPOINT" \
  --set-string aws.accessKeyId="$AWS_ACCESS_KEY_ID" \
  --set-string aws.secretAccessKey="$AWS_SECRET_ACCESS_KEY" \
  --set-string aws.sessionToken="${AWS_SESSION_TOKEN:-}"

echo "✅ Done."
echo "Grafana: http://localhost:32000  (admin/admin)"
echo "RDS (in-cluster): postgres-rds.default.svc.cluster.local:5432"
```

Make it executable:

```bash
chmod +x k8s/setup.sh
./k8s/setup.sh
```

---

## 9) Teardown

```bash
helm uninstall ssm-proxy
kubectl delete -f k8s/grafana-service.yaml
kubectl delete -f k8s/grafana-deployment.yaml
kubectl delete -f k8s/postgres-grafana/postgres-service.yaml
kubectl delete -f k8s/postgres-grafana/postgres-deployment.yaml
kubectl delete -f k8s/postgres-grafana/postgres-pvc.yaml
kubectl delete -f k8s/postgres-moodtracker/postgres-service.yaml
kubectl delete -f k8s/postgres-moodtracker/postgres-deployment.yaml
```

---

## 10) Troubleshooting

| Symptom                                | Cause                                            | Fix                                                                                                               |
| -------------------------------------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `postgres-rds` **has no endpoints**    | SSM proxy pod not Ready                          | Check `kubectl logs deploy/ssm-proxy`, ensure AWS creds are valid                                                 |
| `Connection refused` to `postgres-rds` | socat not binding / tunnel not open              | Ensure sidecar runs; restart pod; verify endpoint shows `:5432`                                                   |
| Long SSM connect times                 | Existing active session or missing VPC endpoints | Terminate sessions with `aws ssm terminate-session`; ensure VPC endpoints for `ssm`, `ssmmessages`, `ec2messages` |
| psql SSL error                         | RDS enforces SSL                                 | Use `sslmode=require` or `verify-ca` with AWS CA bundle                                                           |
| Grafana can’t connect                  | Wrong datasource host                            | Use `postgres-rds.default.svc.cluster.local:5432` (not the AWS hostname directly)                                 |

Useful debug:

```bash
kubectl get endpoints postgres-rds
kubectl logs -f deploy/ssm-proxy
aws ssm describe-sessions --state Active
```

---

```


```

