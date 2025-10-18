  --set bastionId=$BASTION_ID \
  --set rds.endpoint=$RDS_ENDPOINT \
  --set-string aws.accessKeyId=$AWS_ACCESS_KEY_ID \
  --set-string aws.secretAccessKey=$AWS_SECRET_ACCESS_KEY \
  --reuse-values \
  --set patchPip=true

kubectl logs -f deploy/ssm-proxy


kubectl rollout status deploy/ssm-proxy
kubectl get svc postgres-rds

kubectl run --rm -it pg-test --image=postgres:16 -- bash -lc \
"PGPASSWORD=' psql -h postgres-rds -U chtoukre -d my-postgres-db -c 'SELECT version();'"

