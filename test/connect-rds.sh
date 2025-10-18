#!/bin/bash

# --- Récupération des infos Terraform ---
cd infra
DB_ENDPOINT=$(terraform output -raw db_endpoint)
BASTION_ID=$(terraform output -raw bastion_instance_id)
DB_USER="chtoukre"

# --- Récupération mot de passe depuis AWS Secrets Manager ---
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id rds-postgres-password \
  --query SecretString \
  --output text)

echo "✅ Endpoint RDS  : $DB_ENDPOINT"
echo "✅ Bastion ID    : $BASTION_ID"
echo "✅ User          : $DB_USER"
echo "🔐 Mot de passe récupéré depuis AWS Secrets Manager"

echo "🚀 Ouverture du tunnel SSM vers RDS..."
aws ssm start-session \
  --target $BASTION_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$DB_ENDPOINT\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5432\"]}" &
SSM_PID=$!

sleep 3

echo "🛜 Connexion PostgreSQL..."
#PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U $DB_USER -d postgres
pwd
ls
ping -c 2  $DB_ENDPOINT
bash -c "</dev/tcp/$DB_ENDPOINT/5432" && echo '✅ Port 5432 ouvert' || echo '❌ Port bloqué'



echo "🧹 Fermeture du tunnel SSM..."
kill $SSM_PID

