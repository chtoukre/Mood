#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "🛠️  Mood Tracker Debug Assistant"
echo "======================================"

echo ""
echo "📦 Checking Kubernetes pods..."
kubectl get pods -o wide

echo ""
echo "🔧 ssm-proxy pod logs (last 50 lines)..."
POD=$(kubectl get pod -l app=ssm-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$POD" ]]; then
  kubectl logs "$POD" --tail=50
else
  echo "⚠️ No ssm-proxy pod found"
fi

echo ""
echo "🌐 Checking postgres-rds endpoints..."
kubectl get endpoints postgres-rds || echo "⚠️ postgres-rds service not found"

echo ""
echo "🛡️ Checking Security Groups (RDS access rules)..."
terraform -chdir=../infra state show aws_security_group.rds_sg 2>/dev/null | grep ingress -A5 || echo "⚠️ Could not inspect SG"

echo ""
echo "🔒 Checking active AWS SSM sessions..."
aws ssm describe-sessions --state Active || echo "⚠️ Cannot list AWS sessions (AWS CLI config missing?)"

echo ""
echo "🔎 Testing tunnel connectivity from inside cluster..."
kubectl run -it --rm debug-net --image=nicolaka/netshoot --restart=Never -- \
  sh -c "nc -zv postgres-rds.default.svc.cluster.local 5432" \
  && echo '✅ Tunnel OK: RDS reachable inside cluster' \
  || echo '❌ Tunnel FAILED: cannot reach RDS via proxy'

echo ""
echo "📜 Checking bastion instance ID from Terraform..."
terraform -chdir=../infra output bastion_instance_id || echo "⚠️ Terraform state not found"

echo ""
echo "✅ Debug summary:"
echo "- If tunnel fails: check AWS credentials + SSM endpoints"
echo "- If endpoints empty: check ssm-proxy deployment"
echo "- If Grafana can't connect: make sure datasource = postgres-rds:5432"

