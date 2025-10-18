#!/usr/bin/env bash
set -euo pipefail

echo "==============================="
echo "🚀 Starting Mood Tracker stack"
echo "==============================="

echo "✅ Starting Minikube..."
minikube start --driver=docker >/dev/null 2>&1 || true

echo "🛢️ Deploying local Postgres (moodtracker)..."
kubectl apply -f postgres-moodtracker/postgres-deployment.yaml
kubectl apply -f postgres-moodtracker/postgres-service.yaml

echo "📊 Deploying Grafana and its Postgres..."
kubectl apply -f postgres-grafana/postgres-pvc.yaml
kubectl apply -f postgres-grafana/postgres-deployment.yaml
kubectl apply -f postgres-grafana/postgres-service.yaml
kubectl apply -f grafana-deployment.yaml
kubectl apply -f grafana-service.yaml

echo "🔒 Connecting to AWS RDS via SSM Proxy..."
if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "❌ ERROR: AWS credentials not found. Export them first:"
  echo "   export AWS_ACCESS_KEY_ID=..."
  echo "   export AWS_SECRET_ACCESS_KEY=..."
  echo "   export AWS_SESSION_TOKEN=... (if using MFA)"
  exit 1
fi

export BASTION_ID=$(cd ../infra && terraform output -raw bastion_instance_id)
export RDS_ENDPOINT=$(cd ../infra && terraform output -raw db_endpoint)

helm upgrade --install ssm-proxy ./ssm-proxy \
  --set aws.region=eu-west-3 \
  --set bastionId="$BASTION_ID" \
  --set rds.endpoint="$RDS_ENDPOINT" \
  --set-string aws.accessKeyId="$AWS_ACCESS_KEY_ID" \
  --set-string aws.secretAccessKey="$AWS_SECRET_ACCESS_KEY" \
  --set-string aws.sessionToken="${AWS_SESSION_TOKEN:-}"

echo "✅ Checking deployments..."
kubectl get pods -o wide
echo ""
echo "✅ STACK IS READY ✅"
echo "➡️ Grafana Dashboard  → http://localhost:32000"
echo "➡️ Local Postgres     → postgres.default.svc.cluster.local:5432"
echo "➡️ AWS RDS (tunnel)   → postgres-rds.default.svc.cluster.local:5432"

