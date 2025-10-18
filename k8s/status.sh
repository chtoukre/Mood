#!/usr/bin/env bash
set -euo pipefail

echo "==============================="
echo "🔍 Mood Tracker - Status Check"
echo "==============================="

echo "✅ Minikube status:"
minikube status || echo "⚠️ Minikube not running"

echo ""
echo "✅ Kubernetes Pods:"
kubectl get pods -o wide || true

echo ""
echo "✅ Kubernetes Services:"
kubectl get svc || true

echo ""
echo "🔐 Checking AWS SSM active sessions..."
SESSIONS=$(aws ssm describe-sessions --state Active --query "Sessions[].SessionId" --output text 2>/dev/null || true)
if [[ -z "$SESSIONS" ]]; then
  echo "✅ No active SSM sessions."
else
  echo "⚠️ Active SSM sessions:"
  echo "$SESSIONS"
fi

echo ""
echo "🔌 Testing connectivity to AWS RDS inside Kubernetes..."
kubectl run -it --rm net-test --image=nicolaka/netshoot --restart=Never -- \
  sh -c "nc -zvw3 postgres-rds.default.svc.cluster.local 5432" \
  && echo '✅ RDS reachable via SSM tunnel' \
  || echo '❌ Could not reach RDS (tunnel might be down)'

echo ""
echo "✅ Summary:"
echo "- Minikube:        $(minikube status | grep -q 'Running' && echo OK || echo DOWN)"
echo "- Grafana:         $(kubectl get deployment grafana >/dev/null 2>&1 && echo OK || echo MISSING)"
echo "- Local Postgres:  $(kubectl get svc postgres >/dev/null 2>&1 && echo OK || echo MISSING)"
echo "- SSM Proxy:       $(kubectl get deployment ssm-proxy >/dev/null 2>&1 && echo OK || echo NOT INSTALLED)"
echo "- AWS SSM Tunnel:  $( [[ -n "$SESSIONS" ]] && echo ACTIVE || echo INACTIVE )"

