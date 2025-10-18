# Setup Guide

This guide explains how to deploy the Mood Tracker infrastructure and development environment.

---

## ✅ 1. Prerequisites

### Tools to install

| Tool | Required | Install |
|------|----------|---------|
| AWS CLI | ✅ Yes | https://docs.aws.amazon.com/cli |
| Terraform | ✅ Yes | https://developer.hashicorp.com/terraform |
| kubectl | ✅ Yes | https://kubernetes.io/docs/tasks/tools |
| Helm | ✅ Yes | https://helm.sh |
| Minikube | ✅ Yes | https://minikube.sigs.k8s.io |
| Python 3.10+ | ✅ Yes | https://python.org |
| Docker | ✅ Optional | https://docker.com |
| mkdocs-material | ✅ For docs | `pip install mkdocs-material` |

---

### AWS account & credentials

Configure AWS credentials locally:

```bash
aws configure
````

Or use environment variables:

```bash
export AWS_ACCESS_KEY_ID=YOUR_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
export AWS_DEFAULT_REGION=eu-west-3
```

✅ **Make sure your IAM user has permissions**:

* `AmazonEC2FullAccess`
* `AmazonSSMFullAccess`
* `AmazonRDSFullAccess`
* `IAMFullAccess` *(optional for Terraform role creation)*

---

## ✅ 2. Clone the Repository

```bash
git clone https://github.com/yourusername/mood-tracker.git
cd mood-tracker
```

---

## ✅ 3. Deploy AWS Infrastructure (Terraform)

This will create:
✅ VPC + subnets
✅ Private RDS PostgreSQL
✅ Private Bastion EC2 + SSM
✅ DB subnet groups, security groups
✅ AWS Secrets Manager entry for db password

```bash
cd infra
terraform init
terraform plan
terraform apply
```

Get outputs:

```bash
terraform output -raw bastion_instance_id
terraform output -raw db_endpoint
```

---

## ✅ 4. Start Kubernetes (Minikube)

```bash
minikube start --cpus=4 --memory=6g
kubectl get nodes
```

---

## ✅ 5. Configure Python Environment

```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip psycopg2-binary
```

---

## ✅ 6. Deploy the SSM Tunnel (Helm chart)

```bash
cd ../k8s/ssm-proxy

# Inject AWS credentials for SSM
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...   # Only if using temporary AWS credentials

export BASTION_ID=$(cd ../../infra && terraform output -raw bastion_instance_id)
export RDS_ENDPOINT=$(cd ../../infra && terraform output -raw db_endpoint)

helm install ssm-proxy . \
  --set aws.region=eu-west-3 \
  --set bastionId="$BASTION_ID" \
  --set rds.endpoint="$RDS_ENDPOINT" \
  --set-string aws.accessKeyId="$AWS_ACCESS_KEY_ID" \
  --set-string aws.secretAccessKey="$AWS_SECRET_ACCESS_KEY"
```

Verify:

```bash
kubectl get pods -l app=ssm-proxy
kubectl get svc postgres-rds
kubectl get endpoints postgres-rds  # ✅ Should not be empty
```

---

## ✅ 7. Test RDS Connectivity from Kubernetes

```bash
kubectl run -it --rm netshoot --image=nicolaka/netshoot --restart=Never -- \
  nc -zv postgres-rds.default.svc.cluster.local 5432
```

✅ Success → SSM tunnel works.

---

✅ Continue: next read **[Usage Guide](usage.md)** to insert data & connect Grafana.

```

```

