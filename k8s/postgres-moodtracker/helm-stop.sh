#!/usr/bin/env bash
set -euo pipefail

echo "🛑 Cleaning Kubernetes resources..."

echo "🗄 Removing PostgreSQL Helm release..."
helm uninstall postgres || echo "ℹ️ postgres not installed"

echo "🧹 Removing Persistent Volume data..."
kubectl delete pvc postgres-pvc --ignore-not-found

echo "📊 Removing Grafana stack..."
kubectl delete -f k8s/grafana-service.yaml --ignore-not-found
kubectl delete -f k8s/grafana-deployment.yaml --ignore-not-found
kubectl delete -f k8s/postgres-grafana/postgres-service.yaml --ignore-not-found
kubectl delete -f k8s/postgres-grafana/postgres-deployment.yaml --ignore-not-found
kubectl delete -f k8s/postgres-grafana/postgres-pvc.yaml --ignore-not-found

echo "✅ All services stopped."

