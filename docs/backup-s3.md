# Backups to S3 (with Restore)

This page documents how we **backup and restore PostgreSQL** for the Mood Tracker project using:
- **AWS S3** bucket: `mood-tracker-backups` (region: `eu-west-3`)
- **AWS Secrets Manager** for the DB password (`rds-postgres-password`)
- Works with both **local PostgreSQL (Minikube)** and **AWS RDS (via SSM tunnel)**

No automation is included here (manual commands only).

---

## 🔭 Overview

```

Local Postgres (Minikube)  ─┐
├─►  backup-to-s3.sh  ─►  S3: mood-tracker-backups/postgres/<timestamp>.sql.gz
AWS RDS Postgres (via SSM) ─┘

```

For restore:

```

S3: mood-tracker-backups/postgres/<file>.sql.gz  ─►  restore-from-s3.sh  ─►  Local Postgres or AWS RDS (via SSM)

```

---

## ✅ What we already set up

- S3 bucket: **`mood-tracker-backups`** (private, SSE-AES256, versioning on; lifecycle 90d → Glacier is recommended)
- Secrets Manager **`rds-postgres-password`** stores the DB password  
  - Accepts either a **plain string** or JSON: `{"password":"..."}`
- Two helper scripts (placed under `k8s/`):
  - `backup-to-s3.sh` — dumps PostgreSQL and uploads to S3 with SSE-AES256
  - `restore-from-s3.sh` — **takes a safety backup first**, then restores from S3

> These scripts can back up **local Postgres** or **AWS RDS**.  
> For RDS, you typically run them **from a pod/laptop that can already reach RDS** (e.g., via the **SSM proxy Service** in your cluster: `postgres-rds.default.svc.cluster.local:5432`) or by opening a local SSM port-forward.

---

## 🔐 Secrets & Credentials

- **Database password** is read from **AWS Secrets Manager**:
  - Secret name: `rds-postgres-password`
  - Script auto-detects if the value is plain text or JSON (and reads `password`)
- **AWS credentials** must be available for:
  - calling Secrets Manager (to fetch DB password)
  - uploading/downloading S3 objects

Export (if needed):

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...      # only if you use temporary creds
export AWS_DEFAULT_REGION=eu-west-3
```

---

## 🗃️ Backup (Local Postgres)

If your **local Postgres** Service is `postgres` in the default namespace:

```bash
# This script will try a direct connection to 127.0.0.1:5432.
# If it’s not reachable, it will temporarily port-forward svc/postgres.
./k8s/backup-to-s3.sh
```

**Result:**

* Local copy in `./backups/moodtracker-YYYY-mm-dd_HH-MM-SS.sql.gz`
* S3 object: `s3://mood-tracker-backups/postgres/moodtracker-YYYY-mm-dd_HH-MM-SS.sql.gz`

To target a specific host/port/db/user:

```bash
./k8s/backup-to-s3.sh <DB_HOST> <DB_PORT> <DB_NAME> <DB_USER>
# example (local PF on 55432):
./k8s/backup-to-s3.sh 127.0.0.1 55432 moodtracker mooduser
```

---

## 🗄️ Backup (AWS RDS via SSM)

**Option A — From inside Kubernetes** (recommended)

If your **SSM proxy** chart is running and exposes `postgres-rds:5432`:

```bash
# Start a short-lived pod that runs pg_dump and uploads to S3 using our script from your workstation
# (or run the script locally but point to the in-cluster hostname if you have network access to it).
./k8s/backup-to-s3.sh postgres-rds.default.svc.cluster.local 5432 <DB_NAME> <DB_USER>
```

**Option B — From your laptop** (local SSM port-forward)

Open a local SSM port-forward to the bastion → RDS (5432 → 5432), then:

```bash
./k8s/backup-to-s3.sh 127.0.0.1 5432 <DB_NAME> <DB_USER>
```

> The script fetches the password from Secrets Manager automatically.

---

## ♻️ Restore (to Local Postgres or RDS)

The restore script always does a **safety backup first** (both local and S3) before applying the restore.

**Restore the latest S3 backup → Local Postgres (auto port-forward if needed)**

```bash
./k8s/restore-from-s3.sh
```

**Restore a specific local file**

```bash
./k8s/restore-from-s3.sh 127.0.0.1 5432 moodtracker mooduser ./backups/moodtracker-2025-10-18_12-00-00.sql.gz
```

**Restore a specific S3 key**

```bash
./k8s/restore-from-s3.sh 127.0.0.1 5432 moodtracker mooduser \
  postgres/moodtracker-2025-10-18_12-00-00.sql.gz
```

> **Destructive reset** (optional) before restore:
>
> ```bash
> export DROP_SCHEMA=true
> ./k8s/restore-from-s3.sh
> ```
>
> This runs `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` before import.

---

## 📦 S3 Layout

```
s3://mood-tracker-backups/
└── postgres/
    ├── moodtracker-2025-10-18_12-00-00.sql.gz
    ├── moodtracker-2025-10-19_12-00-00.sql.gz
    └── safety/
        └── safety-moodtracker-2025-10-19_12-34-56.sql.gz
```

* **Regular backups** land under `postgres/`
* **Safety backups** created by the restore script go under `postgres/safety/`

---

## 🧪 Quick Checks

List latest backups:

```bash
aws s3 ls s3://mood-tracker-backups/postgres/ --recursive | sort | tail -n 5
```

Download one locally:

```bash
aws s3 cp s3://mood-tracker-backups/postgres/<file>.sql.gz ./backups/
```

Test connectivity (local PF):

```bash
kubectl port-forward svc/postgres 5432:5432 &
psql -h 127.0.0.1 -U mooduser -d moodtracker -c '\dt'
```

---

## 🔐 Security Best Practices

* **Bucket is private** (Block Public Access ON)
* **Server-side encryption** enabled (SSE-S3 AES256)
* **Versioning** enabled (rollbacks possible)
* **IAM least privilege** (only `s3:PutObject`, `s3:GetObject`, `s3:ListBucket` for this bucket)
* **Secrets Manager** for DB password (no plaintext in scripts)
* Consider **Lifecycle**: move backups to Glacier after 90 days, keep for up to 10 years

---

## 🛠️ Troubleshooting

| Symptom                             | Likely Cause                                   | Fix                                                                        |
| ----------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------- |
| `could not translate host name ...` | Not running inside cluster and no port-forward | Use `kubectl port-forward` or pass an IP that’s reachable                  |
| `Connection refused`                | Port not open / PF not ready                   | Wait a few seconds; verify `kubectl get endpoints`, `nc -z 127.0.0.1 5432` |
| Slow / stuck for RDS                | SSM path not ready                             | Ensure SSM proxy is running and **EndpointSlice** shows an IP:port         |
| `AccessDenied` on S3                | Missing IAM permission                         | Ensure your AWS user can `s3:PutObject`, `s3:GetObject`, `s3:ListBucket`   |
| Empty password                      | Secret not in expected format                  | Store either plain string or JSON with `{"password":"..."}`                |
| Restore corrupt                     | Wrong DB / schema mismatch                     | (Optional) `export DROP_SCHEMA=true` then run restore                      |

---

## ✅ Summary

* You can **backup** both local and RDS Postgres to S3 using `backup-to-s3.sh`
* You can **restore** safely using `restore-from-s3.sh` (safety backup taken first)
* Passwords are pulled from **AWS Secrets Manager**
* Storage is **S3** with **AES256** and **versioning**
* No public exposure; everything stays private and secure

Next: if you want, we can later add **Kubernetes CronJobs** for scheduled backups (daily/hourly) and retention per environment.

```

```
