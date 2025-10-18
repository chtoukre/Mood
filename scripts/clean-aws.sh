#!/usr/bin/env bash
set -euo pipefail

echo "==============================="
echo "🧹 Cleaning AWS Infrastructure"
echo "==============================="

if [ ! -d "infra" ]; then
  echo "✅ No Terraform infra folder found (already cleaned)"
  exit 0
fi

echo "📦 Saving Terraform state before cleanup..."
mkdir -p .backup
terraform -chdir=infra output -json > .backup/terraform-state.json || true

echo "🔥 Destroying Terraform infrastructure on AWS..."
terraform -chdir=infra destroy -auto-approve

echo "📦 Archiving Terraform configuration..."
mkdir -p archived-infra
mv infra archived-infra/aws-rds-infra-$(date +%Y%m%d%H%M)

echo "✅ AWS cleanup done!"
echo "💾 Previous Terraform state stored in .backup/terraform-state.json"
echo "📦 Infra backup stored in archived-infra/"

