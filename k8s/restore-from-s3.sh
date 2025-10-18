#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./restore-from-s3.sh [db_host] [db_port] [db_name] [db_user] [source]
#
# Defaults: connect to local/forwarded postgres used by the stack.
# [source] can be:
#   - empty  -> auto-pick the latest backup from S3 (prefix: postgres/)
#   - path   -> local .sql.gz file
#   - s3 key -> e.g. postgres/moodtracker-2025-10-18_10-00-00.sql.gz
#   - s3 url -> s3://mood-tracker-backups/postgres/...

DB_HOST="${1:-127.0.0.1}"
DB_PORT="${2:-5432}"
DB_NAME="${3:-moodtracker}"
DB_USER="${4:-mooduser}"
SOURCE="${5:-}"

AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-west-3}}"
SECRET_NAME="${SECRET_NAME:-rds-postgres-password}"
S3_BUCKET="${S3_BUCKET:-mood-tracker-backups}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"

DATE="$(date +%Y-%m-%d_%H-%M-%S)"
SAFETY_BASENAME="safety-${DB_NAME}-${DATE}.sql.gz"
SAFETY_LOCAL="${BACKUP_DIR}/${SAFETY_BASENAME}"
SAFETY_S3_KEY="postgres/safety/${SAFETY_BASENAME}"

TMP_DIR="$(mktemp -d)"
DOWNLOAD_FILE="${TMP_DIR}/restore.sql.gz"

pf_pid=""
cleanup() {
  if [[ -n "${pf_pid}" ]] && ps -p "${pf_pid}" >/dev/null 2>&1; then
    echo "🧹 Stopping port-forward (pid=${pf_pid})..."
    kill "${pf_pid}" >/dev/null 2>&1 || true
    wait "${pf_pid}" 2>/dev/null || true
  fi
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1"; exit 1; }
}

# --- Dependencies ---
require aws
require psql
require pg_dump
require gzip

# --- Fetch password from AWS Secrets Manager ---
echo "🔐 Fetching DB password from AWS Secrets Manager (${SECRET_NAME}) in ${AWS_REGION}..."
RAW_SECRET="$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${SECRET_NAME}" \
  --query 'SecretString' \
  --output text)"

if [[ "${RAW_SECRET}" =~ ^\{ ]]; then
  if command -v jq >/dev/null 2>&1; then
    DB_PASSWORD="$(printf '%s' "${RAW_SECRET}" | jq -r '.password // empty')"
  else
    require python3
    DB_PASSWORD="$(python3 - <<'PY'
import json,sys
data=json.loads(sys.stdin.read())
print(data.get("password",""))
PY
<<<"${RAW_SECRET}")"
  fi
else
  DB_PASSWORD="${RAW_SECRET}"
fi

if [[ -z "${DB_PASSWORD}" ]]; then
  echo "❌ Could not extract password from secret '${SECRET_NAME}'."
  echo "   Expecting a plain string or JSON with key 'password'."
  exit 1
fi

# --- Check reachability; if not, auto port-forward to svc/postgres:5432 ---
echo "🔎 Checking DB reachability on ${DB_HOST}:${DB_PORT}..."
can_connect() {
  if command -v pg_isready >/dev/null 2>&1; then
    PGPASSWORD="${DB_PASSWORD}" pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" >/dev/null 2>&1
  else
    (exec 3<>"/dev/tcp/${DB_HOST}/${DB_PORT}") >/dev/null 2>&1
  fi
}

if ! can_connect; then
  echo "⚠️  Not reachable. Will try to create a port-forward to svc/postgres:5432 (Kubernetes)."
  require kubectl
  if ! kubectl get svc postgres >/dev/null 2>&1; then
    echo "❌ Kubernetes service 'postgres' not found. Start your k8s stack or pass host/port explicitly."
    exit 1
  fi

  try_port="5432"
  if (exec 3<>"/dev/tcp/127.0.0.1/${try_port}") >/dev/null 2>&1; then
    try_port="55432"
  fi

  echo "📡 Starting port-forward: 127.0.0.1:${try_port} -> svc/postgres:5432"
  kubectl port-forward svc/postgres "${try_port}:5432" >/dev/null 2>&1 &
  pf_pid=$!

  for i in {1..30}; do
    if (exec 3<>"/dev/tcp/127.0.0.1/${try_port}") >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! (exec 3<>"/dev/tcp/127.0.0.1/${try_port}") >/dev/null 2>&1; then
    echo "❌ Port-forward did not become ready."
    exit 1
  fi

  DB_HOST="127.0.0.1"
  DB_PORT="${try_port}"
  echo "✅ Port-forward ready on ${DB_HOST}:${DB_PORT}"
else
  echo "✅ DB reachable."
fi

mkdir -p "${BACKUP_DIR}"

# --- SAFETY BACKUP before restore ---
echo "🛡️  Safety backup BEFORE restore → ${SAFETY_LOCAL}"
PGPASSWORD="${DB_PASSWORD}" pg_dump \
  -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${DB_NAME}" \
  --no-owner --no-privileges --format=plain \
  | gzip -9 > "${SAFETY_LOCAL}"

echo "☁️  Uploading safety backup to s3://${S3_BUCKET}/${SAFETY_S3_KEY} (SSE-S3 AES256)..."
aws s3 cp "${SAFETY_LOCAL}" "s3://${S3_BUCKET}/${SAFETY_S3_KEY}" --sse AES256 --only-show-errors
echo "✅ Safety backup done."

# --- Determine source to restore ---
resolve_s3_key() {
  # Pick latest non-safety backup for this DB
  aws s3 ls "s3://${S3_BUCKET}/postgres/" --recursive \
    | grep "${DB_NAME}-" \
    | grep -v "/safety/" \
    | sort \
    | tail -n 1 \
    | awk '{print $4}'
}

if [[ -z "${SOURCE}" ]]; then
  echo "🔎 No source provided. Looking for latest backup in s3://${S3_BUCKET}/postgres/ ..."
  S3_KEY="$(resolve_s3_key)"
  if [[ -z "${S3_KEY}" ]]; then
    echo "❌ No suitable backups found in s3://${S3_BUCKET}/postgres/"
    exit 1
  fi
  echo "📦 Latest backup found: ${S3_KEY}"
  aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" "${DOWNLOAD_FILE}" --only-show-errors

elif [[ "${SOURCE}" == s3://* ]]; then
  echo "⬇️  Downloading ${SOURCE} ..."
  aws s3 cp "${SOURCE}" "${DOWNLOAD_FILE}" --only-show-errors

elif [[ -f "${SOURCE}" ]]; then
  echo "📄 Using local file: ${SOURCE}"
  cp "${SOURCE}" "${DOWNLOAD_FILE}"

else
  # assume it's an S3 key under our bucket
  echo "⬇️  Downloading s3://${S3_BUCKET}/${SOURCE} ..."
  aws s3 cp "s3://${S3_BUCKET}/${SOURCE}" "${DOWNLOAD_FILE}" --only-show-errors
fi

# --- Restore ---
echo "🗄️  Restoring into ${DB_NAME} on ${DB_HOST}:${DB_PORT} ..."
# Optional destructive reset:
#   export DROP_SCHEMA=true
#   (This will DROP and recreate schema public)
if [[ "${DROP_SCHEMA:-false}" == "true" ]]; then
  echo "⚠️  DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
  PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${DB_NAME}" \
    -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;"
fi

gunzip -c "${DOWNLOAD_FILE}" \
  | PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${DB_NAME}"

echo "✅ Restore complete."
echo "   • Safety backup (local): ${SAFETY_LOCAL}"
echo "   • Safety backup (S3):    s3://${S3_BUCKET}/${SAFETY_S3_KEY}"

