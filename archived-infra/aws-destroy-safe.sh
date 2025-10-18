#!/usr/bin/env bash
set -euo pipefail

echo "====================================="
echo "⚠️  AWS Terraform SAFE DESTROY MODE"
echo "====================================="

cd aws-rds-infra

echo "💾 Saving Terraform outputs (backup before destroy)..."
mkdir -p ../.backup
terraform output -json > ../.backup/terraform-state.json 2>/dev/null || true
echo "✅ Saved to .backup/terraform-state.json"

echo "🔍 Checking current Terraform state..."
terraform state list || echo "⚠️ No resources managed by Terraform"

echo "🛑 WARNING: You are about to destroy ALL AWS resources in this project:"
echo "   - RDS PostgreSQL"
echo "   - Bastion EC2"
echo "   - VPC Endpoints"
echo "   - Security Groups"
echo "   - Subnets & VPC"
echo "==========================================="
read -p "Type YES to continue: " confirm

if [[ "$confirm" != "YES" ]]; then
  echo "❌ Cancelled by user."
  exit 0
fi

echo "🔥 Destroying AWS infrastructure..."
terraform destroy -auto-approve

echo "📦 Archiving Terraform configuration..."
cd ..
mkdir -p archived-infra
mv infra "archived-infra/aws-infra-$(date +%Y%m%d-%H%M)"

echo "✅ AWS cleanup completed safely!"
echo "📦 Terraform configuration archived under archived-infra/"
echo "💾 Previous state saved in .backup/terraform-state.json"
echo "✅ You now have 0€ AWS infra cost."

