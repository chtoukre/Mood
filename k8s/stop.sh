#!/usr/bin/env bash
set -euo pipefail

echo "==============================="
echo "🛑 Stopping Mood Tracker stack"
echo "==============================="

echo "🔒 Closing active AWS SSM sessions (if any)..."
SESSIONS=$(aws ssm describe-sessions --state Active --query "Sessions[].SessionId" --output text 2>/dev/null || true)
if [[ -z "$SESSIONS" ]]; then
  echo "✅ No active SSM sessions."
else
  for session in $SESSIONS; do
    echo " - Terminating session $session"
    aws ssm terminate-session --session-id "$session" >/dev/null 2>&1 || true
  done
fi

echo "🧹 Uninstalling SSM proxy tunnel from Kubernetes (if exists)..."
helm uninstall ssm-proxy >/dev/null 2>&1 || echo "⚠️ No Helm release named ssm-proxy"

echo "🧹 Cleaning Kubernetes workloads..."
kubectl delete deployment grafana --ignore-not-found
kubectl delete service grafana --ignore-not-found

kubectl delete deployment grafana-postgres --ignore-not-found
kubectl delete service grafana-postgres --ignore-not-found
kubectl delete pvc grafana-postgres-pvc --ignore-not-found

kubectl delete deployment postgres --ignore-not-found
kubectl delete service postgres --ignore-not-found
kubectl delete pvc postgres-pvc --ignore-not-found

echo "💤 Stopping Minikube (optional)..."
minikube stop >/dev/null 2>&1 || echo "⚠️ Minikube already stopped or not installed."

echo "✅ Environment stopped successfully!"
echo "💡 Tip: Use './k8s/start.sh' to restart everything."

