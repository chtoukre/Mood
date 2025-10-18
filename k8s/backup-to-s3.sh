#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./backup-to-s3.sh [db_host] [db_port] [db_name] [db_user]
# Defaults: connect local/forwarded Postgres used by the stack.
DB_HOST="${1:-127.0.0.1}"
DB_PORT="${2:-5432}"
DB_NAME="${3:-moodtracker}"
DB_USER="${4:-mooduser}"

AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-west-3}}"
SECRET_NAME="${SECRET_NAME:-rds-postgres-password}"
S3_BUCKET="${S3_BUCKET:-mood-tracker-backups}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"

DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BASENAME="${DB_NAME}-${DATE}.sql.gz"
LOCAL_FILE="${BACKUP_DIR}/${BASENAME}"
S3_KEY="postgres/${BASENAME}"

pf_pid=""
cleanup() {
  if [[ -n "${pf_pid}" ]] && ps -p "${pf_pid}" >/dev/null 2>&1; then
    echo "🧹 Stopping port-forward (pid=${pf_pid})..."
    kill "${pf_pid}" >/dev/null 2>&1 || true
    wait "${pf_pid}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1"; exit 1; }
}

# --- Dependencies we need ---
require aws
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
  # Secret is JSON => try to extract .password
  if command -v jq >/dev/null 2>&1; then
    DB_PASSWORD="$(printf '%s' "${RAW_SECRET}" | jq -r '.password // empty')"
  else
    # Fallback to python if jq not present
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

# --- Try to reach DB; if not reachable, auto port-forward to svc/postgres ---
echo "🔎 Checking DB reachability on ${DB_HOST}:${DB_PORT}..."
can_connect() {
  if command -v pg_isready >/dev/null 2>&1; then
    PGPASSWORD="${DB_PASSWORD}" pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" >/dev/null 2>&1
  else
    # fallback with bash builtin /dev/tcp
    (exec 3<>"/dev/tcp/${DB_HOST}/${DB_PORT}") >/dev/null 2>&1
  fi
}

if ! can_connect; then
  echo "⚠️  Not reachable. Will try to create a port-forward to svc/postgres:5432 (Kubernetes)."
  require kubectl
  # Ensure service exists
  if ! kubectl get svc postgres >/dev/null 2>&1; then
    echo "❌ Kubernetes service 'postgres' not found. Start your k8s stack or pass host/port explicitly."
    exit 1
  fi

  # Find a free local port (default 5432, fallback 55432)
  try_port="5432"
  if (exec 3<>"/dev/tcp/127.0.0.1/${try_port}") >/dev/null 2>&1; then
    try_port="55432"
  fi

  echo "📡 Starting port-forward: 127.0.0.1:${try_port} -> svc/postgres:5432"
  kubectl port-forward svc/postgres "${try_port}:5432" >/dev/null 2>&1 &
  pf_pid=$!

  # Wait for the port-forward to be ready
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

# --- Run backup ---
mkdir -p "${BACKUP_DIR}"

echo "🗃️  Dumping ${DB_NAME} from ${DB_HOST}:${DB_PORT}..."
PGPASSWORD="${DB_PASSWORD}" pg_dump \
  -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${DB_NAME}" \
  --no-owner --no-privileges --format=plain \
  | gzip -9 > "${LOCAL_FILE}"

echo "💾 Local copy saved: ${LOCAL_FILE}"

echo "☁️  Uploading to s3://${S3_BUCKET}/${S3_KEY} (SSE-S3 AES256)..."
aws s3 cp "${LOCAL_FILE}" "s3://${S3_BUCKET}/${S3_KEY}" --sse AES256 --only-show-errors

echo "✅ Backup done!"
echo "   • Local: ${LOCAL_FILE}"
echo "   • S3:    s3://${S3_BUCKET}/${S3_KEY}"

