#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Installing PostgreSQL (with password from AWS Secrets Manager)"

# Check AWS credentials
if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "❌ ERROR: AWS credentials are not set!"
  echo "Please export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
  exit 1
fi

AWS_REGION=${AWS_REGION:-eu-west-3}
SECRET_NAME=${SECRET_NAME:-rds-postgres-password}

echo "✅ Using AWS region: $AWS_REGION"
echo "✅ Using AWS secret: $SECRET_NAME"


helm upgrade --install postgres . \
  --set aws.region="$AWS_REGION" \
  --set aws.secretName="$SECRET_NAME" \
  --set-string aws.accessKeyId="$AWS_ACCESS_KEY_ID" \
  --set-string aws.secretAccessKey="$AWS_SECRET_ACCESS_KEY" \
  --set-string aws.sessionToken="${AWS_SESSION_TOKEN:-}"

echo "✅ PostgreSQL installed successfully"
echo "👉 Check pod status with: kubectl get pods -l app=postgres"

