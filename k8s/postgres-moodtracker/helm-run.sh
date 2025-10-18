#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Kubernetes environment..."

echo "📦 Starting Minikube (if needed)..."
minikube status >/dev/null 2>&1 || minikube start

echo "🗄 Deploying PostgreSQL..."
./helm-install-postgres.sh

echo "📊 Deploying Grafana..."
kubectl apply -f k8s/postgres-grafana/postgres-pvc.yaml
kubectl apply -f k8s/postgres-grafana/postgres-deployment.yaml
kubectl apply -f k8s/postgres-grafana/postgres-service.yaml
kubectl apply -f k8s/grafana-deployment.yaml
kubectl apply -f k8s/grafana-service.yaml

echo "✅ Environment is almost ready!"
echo "👉 Grafana URL: http://localhost:32000"

