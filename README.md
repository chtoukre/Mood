
# Mood Tracker — AWS RDS + Kubernetes (Minikube) + Terraform + Grafana

A production-minded playground to track daily mood data, store it in **PostgreSQL**, and visualize insights with **Grafana**.
Infrastructure is provisioned on **AWS** (RDS + Bastion + private subnets) via **Terraform**.
Cluster-side access to the private RDS instance is provided by an **SSM tunnel pod** in Kubernetes (Minikube).
Local developer workflows include **Docker Compose**, **Python scripts**, and **Grafana**.

> Status: evolving project. Today the CLI scripts collect data to JSON/CSV and (optionally) PostgreSQL; RDS access from k8s works via SSM. Next steps include a backend API and frontend UI.

---

## Table of Contents

1. [Overview](#overview)
2. [Repository Structure](#repository-structure)
3. [Architecture](#architecture)
4. [Components](#components)
5. [Getting Started](#getting-started)
6. [Usage](#usage)
7. [Security Model](#security-model)
8. [Roadmap](#roadmap)
9. [Commands Cheatsheet](#commands-cheatsheet)
10. [Contributing](#contributing)
11. [License](#license)

---

## Overview

### Goal

* Track daily mood aspects (gratitude, focus, family, workouts, etc.) via **CLI**.
* Store entries locally (JSON/CSV) and in **PostgreSQL** (local or AWS RDS).
* Explore dashboards with **Grafana**.
* Practice **private** RDS connectivity from Kubernetes using **AWS SSM** instead of public networking.

### Key Features

* **Terraform**: AWS VPC, subnets, RDS PostgreSQL, private Bastion (SSM).
* **Kubernetes (Minikube)**:

  * `ssm-proxy` pod opens a **private tunnel** to RDS.
  * Optional local PostgreSQL and Grafana stacks for development.
* **Python scripts**:

  * Daily CLI to append entries to JSON/CSV.
  * Variant that inserts into PostgreSQL.
  * Generator for realistic historical data.
* **Docker Compose** (full-stack local mode, provided separately in this repo).

---

## Repository Structure

```
mood-tracker/
├─ infra/                      # Terraform: AWS RDS + Bastion + networking
├─ k8s/
│  ├─ ssm-proxy/               # Helm chart: SSM tunnel (pod) → private RDS
│  ├─ postgres-grafana/        # Local Grafana + Postgres (for dashboards)
│  └─ postgres-moodtracker/    # Local Postgres for dev/tests
├─ scripts/
│  ├─ daily-check.py           # CLI -> JSON/CSV
│  ├─ daily-check-k8s.py       # CLI -> JSON/CSV + PostgreSQL
│  └─ generate-fake-entry-k8s.py  # Generate historical entries into Postgres
├─ test/                       # Small bash helpers & debug commands
├─ data/                       # Generated JSON/CSV (gitignored recommended)
├─ README.md
├─ mkdocs.yml                  # MkDocs site config (docs/ below)
└─ docs/
   ├─ index.md
   ├─ architecture.md
   ├─ setup.md
   ├─ usage.md
   ├─ tunnel-ssm.md
   └─ roadmap.md
```

> The `docs/` site is ready for MkDocs (Material theme recommended). See `mkdocs.yml`.

---

## Architecture

### High-level diagram (ASCII)

```
+--------------------+           +------------------------------+
|  Developer Laptop  |           |           AWS VPC            |
|                    |           |                              |
|  Minikube Cluster  |           |  +------------------------+  |
|  +--------------+  |  SSM      |  |   Private Subnets      |  |
|  |  Grafana     |<------------>|  | +--------------------+ |  |
|  |  (dashboard) |  Session     |  | |  Bastion (EC2)     | |  |
|  +--------------+  Manager     |  | |  SSM Agent         | |  |
|  +--------------+  Tunnel      |  | +--------------------+ |  |
|  | ssm-proxy    |==============|  | +--------------------+ |  |
|  | (pod tunnel) |  TCP 5432    |  | | RDS PostgreSQL     | |  |
|  +--------------+              |  | | (private endpoint) | |  |
|                                |  | +--------------------+ |  |
+--------------------+           +------------------------------+
```

* The `ssm-proxy` pod opens a local port and maintains an SSM port-forwarding session **through the Bastion** to the RDS endpoint.
* A Kubernetes Service exposes `ssm-proxy` inside the cluster (e.g., `postgres-rds.default.svc.cluster.local:5432`), so Grafana and other pods can reach the private database.

---

## Components

### Terraform (infra/)

* Provisions:

  * VPC with private subnets
  * **RDS PostgreSQL** (private, no public access)
  * **Bastion EC2** with **SSM** IAM role (no SSH keys required)
  * **VPC interface endpoints** for SSM (`ssm`, `ssmmessages`, `ec2messages`)
* Outputs:

  * `bastion_instance_id`
  * `db_endpoint`
  * (Optional) Secrets Manager ARN for DB password

### Bastion + SSM

* The Bastion is **private** and reachable only via **AWS Systems Manager** (Session Manager).
* No public IP, no SSH ingress required.
* SSM tunnel documents used: `AWS-StartPortForwardingSessionToRemoteHost`.

### AWS RDS PostgreSQL

* Engine: PostgreSQL
* Private subnets, security group restricted to Bastion/Proxy SG.
* SSL strongly recommended (`verify-ca` with AWS RDS CA bundle).

### Kubernetes (Minikube)

* Local cluster for development.
* Namespace: `default` (customize as needed).
* Helm chart `k8s/ssm-proxy/` runs:

  * A container that starts SSM port forwarding to RDS (loopback)
  * A **sidecar** (e.g., `socat`) that re-binds the port to `0.0.0.0` for Service exposure
* Service name for Grafana/clients: `postgres-rds.default.svc.cluster.local:5432`

### Grafana

* Local dashboards against either:

  * local PostgreSQL (in `k8s/postgres-grafana/`), or
  * RDS via `postgres-rds` Service.
* Datasource configuration: Host `postgres-rds.default.svc.cluster.local:5432`, DB `postgres` (or your DB), SSL mode `require` (or `verify-ca` with CA bundle).

### Python scripts (scripts/)

* `daily-check.py`: CLI prompts → writes to `data/<name>.json` and `data/<name>.csv`.
* `daily-check-k8s.py`: same, and **inserts into PostgreSQL** (configure connection params).
* `generate-fake-entry-k8s.py`: bulk generate daily entries from a start date to today → insert into PostgreSQL.

---

## Getting Started

### 1) Prerequisites

* Accounts/CLIs:

  * **AWS CLI** configured (profile/keys or SSO)
  * **Terraform** ≥ 1.5
  * **kubectl** + **Helm**
  * **Minikube**
  * **Python 3.11+** (venv), `psycopg2` for DB scripts
* Optional:

  * **Docker** & **Docker Compose** (for local full-stack)

### 2) Deploy AWS Infrastructure (Terraform)

```bash
cd infra
terraform init
terraform apply
# Review and confirm
terraform output -raw bastion_instance_id
terraform output -raw db_endpoint
```

> Ensure SSM VPC endpoints exist and the RDS SG allows ingress **from the Bastion/Proxy SG** on 5432.

### 3) Start Minikube

```bash
minikube start
kubectl get nodes
```

### 4) Install the SSM proxy Helm chart

```bash
# Export AWS creds (temporary tokens supported)
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
# optional
export AWS_SESSION_TOKEN=...

# Values from Terraform
export BASTION_ID=$(cd infra && terraform output -raw bastion_instance_id)
export RDS_ENDPOINT=$(cd infra && terraform output -raw db_endpoint)

# Install chart
helm install ssm-proxy ./k8s/ssm-proxy \
  --set aws.region=eu-west-3 \
  --set bastionId="$BASTION_ID" \
  --set rds.endpoint="$RDS_ENDPOINT" \
  --set-string aws.accessKeyId="$AWS_ACCESS_KEY_ID" \
  --set-string aws.secretAccessKey="$AWS_SECRET_ACCESS_KEY"
```

Verify:

```bash
kubectl get pods -l app=ssm-proxy
kubectl get svc postgres-rds
kubectl get endpoints postgres-rds
# Should show one pod IP and port :5432
```

### 5) (Optional) Local Postgres + Grafana

See `k8s/postgres-grafana/` for manifests or use Docker Compose (provided separately).

### 6) Python Virtualenv

```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install psycopg2-binary
```

---

## Usage

### CLI — Local JSON/CSV

```bash
cd scripts
python daily-check.py --name overview
# Prompts for ~20 aspects, writes to data/overview.json and data/overview.csv
```

### CLI — Insert into PostgreSQL

Adjust connection params inside `daily-check-k8s.py` (host/port/db/user/password).

* For **local Postgres**: host `localhost` (or your service name if in k8s).
* For **RDS via tunnel in k8s**: from a pod, host `postgres-rds.default.svc.cluster.local`.

Run:

```bash
python scripts/daily-check-k8s.py --name overview
```

### Generate Fake History

```bash
python scripts/generate-fake-entry-k8s.py
```

### Grafana

* Add PostgreSQL datasource:

  * **Host**: `postgres-rds.default.svc.cluster.local:5432`
  * **Database**: `postgres` (or your DB)
  * **User**: your DB user
  * **Password**: from AWS Secrets Manager / local secret
  * **TLS**: `require` or `verify-ca` (recommended; mount CA bundle)

---

## Security Model

* **Private RDS**: no public endpoint; connectivity via **Bastion + SSM** only.
* **SSM Tunnel** in Kubernetes:

  * RDS SG allows 5432 **from Bastion/Proxy SG only**.
  * VPC Endpoints: `ssm`, `ssmmessages`, `ec2messages`.
* **Secrets**:

  * AWS Secrets Manager stores the DB password in AWS.
  * For k8s, inject via Helm values or (recommended) use External Secrets Operator.
* **IAM**:

  * Bastion instance profile with `AmazonSSMManagedInstanceCore`.
  * Principle of least privilege for any additional policies.
* **TLS**:

  * Use AWS RDS CA bundle for `verify-ca`:
    `https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem`

---

## Roadmap

* **Backend API** (FastAPI or Flask) to receive mood entries.
* **Frontend UI** (React/Next.js) to input daily mood easily.
* **AuthN/AuthZ** for multi-tenant user isolation.
* **Per-user databases/schemas** or row-level security.
* **Grafana Cloud / AWS Managed Grafana** with scoped dashboards.
* **EKS** deployment (prod-ready), CI/CD.
* **External Secrets** integration for RDS creds in k8s.

---

## Commands Cheatsheet

### Terraform

```bash
cd infra
terraform init
terraform plan
terraform apply
terraform output -raw db_endpoint
terraform destroy
```

### AWS SSM

```bash
# Open interactive shell on bastion
aws ssm start-session --target <BASTION_INSTANCE_ID>

# Local port forward to RDS (from laptop)
aws ssm start-session \
  --target <BASTION_INSTANCE_ID> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<RDS_ENDPOINT>"],"portNumber":["5432"],"localPortNumber":["5432"]}'

# List & terminate sessions
aws ssm describe-sessions --state Active
aws ssm terminate-session --session-id <ID>
```

### Kubernetes

```bash
kubectl get pods -l app=ssm-proxy
kubectl logs -f deploy/ssm-proxy
kubectl get svc postgres-rds
kubectl get endpoints postgres-rds
```

### PostgreSQL (psql)

```bash
# From bastion shell
psql -h <RDS_ENDPOINT> -U <USER> -d <DB> -p 5432

# From k8s pod (tunneled)
psql -h postgres-rds.default.svc.cluster.local -U <USER> -d <DB> -p 5432
```

---

## Contributing

Contributions are welcome!

* Open an issue for bugs, questions, or feature ideas.
* Fork → branch → PR with a clear description.
* Style: keep docs clear, code commented, and avoid committing secrets.
* For docs site, edit files in `docs/` and update `mkdocs.yml` if needed.



---

### Appendix: Script Notes

The scripts prompt for **~20 mood aspects** and write to both **JSON** and **CSV**.
The `*-k8s.py` variants also push into PostgreSQL using `psycopg2`.
Tweak DB credentials/host according to whether you target local Postgres or the RDS tunnel Service.

