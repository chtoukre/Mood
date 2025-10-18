# System Architecture

The Mood Tracker project uses a **cloud + local hybrid architecture** that enables secure development and data visualization without exposing any database publicly. The architecture is designed to evolve progressively from a **local CLI prototype** to a **cloud-native application**.

---

## 🔧 High-Level Architecture

```

Developer Laptop
│
│  (Minikube cluster)
│    ├─ Grafana (dashboards)
│    ├─ mood scripts (Python)
│    └─ SSM Proxy Pod  ────────────────┐
│                                      │  (AWS Systems Manager – encrypted)
│                                      ▼
│                              Bastion Instance (EC2)
│                                      │  (private subnet)
│                                      ▼
│                            AWS RDS PostgreSQL (Private)

```

🎯 Purpose:
- Secure database access using **SSM** (no public access)
- Kubernetes pod acts as a **tunnel endpoint**
- Grafana connects to RDS **privately** via `ssm-proxy`

---

## ✅ Components Overview

| Component | Technology | Purpose |
|-----------|------------|---------|
| **RDS PostgreSQL** | AWS RDS | Stores mood entries |
| **Bastion EC2** | AWS | Endpoint for SSM port-forwarding |
| **SSM Proxy Pod** | Kubernetes + AWS CLI | Maintains tunnel to RDS |
| **Grafana** | Kubernetes / Docker | Dashboards and analytics |
| **Python Scripts** | CLI | Collect and insert mood entries |
| **Terraform** | AWS automation | Creates VPC, subnets, RDS, IAM |
| **Minikube** | Local Kubernetes | Dev environment |
| **AWS SSM** | AWS Systems Manager | Secure tunneling |

---

## 🔐 Security Model

### AWS Private Networking
- RDS is deployed **in private subnets**
- It has **NO public endpoint**
- Only **Bastion + SSM proxy pod** can reach it (via security groups)

### Secure Connectivity with SSM
✅ No SSH keys  
✅ No public ports  
✅ Connection authorized via IAM  
✅ Encrypted via AWS SSM

### Zero Public Exposure Design
| Layer | Exposure |
|-------|----------|
| RDS | ❌ No public internet |
| Bastion | ❌ No SSH / Only SSM |
| k8s connection | ✅ Only via `ssm-proxy` |
| Secrets | ✅ Stored in AWS Secrets Manager |

---

## 🧩 Kubernetes Access to AWS RDS

The SSM pipeline works like this:

```

Kubernetes Pod (ssm-proxy)
│
├── opens local port 15432 (loopback)
├── uses AWS SSM to forward traffic
│       to Bastion → RDS 5432
│
└── exposes a Service: postgres-rds:5432

```

✅ Then Grafana connects inside the cluster:
```

postgres-rds.default.svc.cluster.local:5432

```

---

## 📦 Data Flow

```

Python CLI → (optional JSON/CSV) → PostgreSQL (local or AWS RDS) → Grafana Dashboards

```

---

## 🏗️ Infrastructure Layers

| Layer | Tool |
|-------|------|
| IaC | Terraform |
| Cloud Provider | AWS |
| Runtime | Kubernetes (Minikube) |
| DB | PostgreSQL |
| Secure Access | AWS SSM |
| Monitoring | Grafana |

---

## ❗ Why not expose RDS publicly?

Because this project is designed with **security-first architecture**, similar to **real production systems**.
- Avoids public database endpoints
- Avoids IP whitelisting
- Eliminates SSH bastion management
- Uses Zero-Trust principles via IAM + SSM

---

✅ Next: Learn how to **deploy the AWS infrastructure** → proceed to **[Setup Guide](setup.md)**.

