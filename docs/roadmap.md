# Roadmap

The Mood Tracker project is designed to evolve progressively from a **local personal CLI tool** into a **secure cloud-based application** with dashboards and per-user analytics. This roadmap tracks that evolution.

---

## ✅ Phase 1 – Local Data Collection (DONE)

| Status | Feature |
|--------|---------|
| ✅ | Python CLI script writes JSON and CSV |
| ✅ | Generate historical fake data |
| ✅ | Local PostgreSQL instance |
| ✅ | Grafana dashboards in local environment |

---

## ✅ Phase 2 – AWS Infrastructure (DONE)

| Status | Feature |
|--------|---------|
| ✅ | RDS PostgreSQL deployment via Terraform |
| ✅ | Private database (no public exposure) |
| ✅ | Bastion + SSM Session access |
| ✅ | VPC with private subnets |
| ✅ | Secure SG inbound rules |
| ✅ | Secrets Manager for password storage |

---

## 🚧 Phase 3 – Kubernetes & Secure RDS Access (IN PROGRESS)

| Status | Feature |
|--------|---------|
| ✅ | Local Minikube cluster |
| ✅ | SSM tunnel from Kubernetes pod |
| ✅ | DB access via internal Service |
| ✅ | Test with Python scripts inside pod |
| 🔄 | Automate DB init & migration |
| 🔄 | External Secrets Operator (sync AWS → k8s secrets) |

---

## 🔜 Phase 4 – Backend API (COMING NEXT)

| Planned | Feature |
|---------|---------|
| 🔜 | FastAPI backend |
| 🔜 | REST endpoints for mood entry submission |
| 🔜 | CI/CD pipeline |
| 🔜 | DB repository layer |
| 🔜 | Pydantic models |
| 🔜 | Helm chart for backend |

---

## 🔜 Phase 5 – Frontend App

| Planned | Feature |
|---------|---------|
| 🔜 | React/Next.js web app |
| 🔜 | Authentication (JWT + refresh tokens) |
| 🔜 | Form for mood input |
| 🔜 | Personal dashboard page |
| 🔜 | Secure access per user |

---

## 🔮 Phase 6 – Scalability and Production

| Future | Feature |
|--------|---------|
| 🔮 | Deploy on AWS EKS |
| 🔮 | Replace Minikube for cloud deployment |
| 🔮 | AWS ALB Ingress Controller |
| 🔮 | HTTPS (ACM + Load Balancer) |
| 🔮 | Monitoring with Prometheus |
| 🔮 | Logs aggregation with Loki |
| 🔮 | S3 data exports |

---

## 🌍 Phase 7 – Observability Platform

| Future | Feature |
|--------|---------|
| 🔮 | AWS Managed Grafana |
| 🔮 | Per-user dashboard isolation |
| 🔮 | Time-series analytics |
| 🔮 | Mood prediction with ML (optional) |

---

## ✅ Contribute to the Roadmap

Want to help or suggest ideas? Open an issue:
```

[https://github.com/yourusername/mood-tracker/issues](https://github.com/yourusername/mood-tracker/issues)

```

Or submit a PR!

---

This roadmap is **alive** and evolving. Check back often 🚀
```

---

✅ Docs section is now complete.

Next, I’ll generate **your `docker-compose.yml` full stack**.
This will include:
✅ Postgres
✅ Grafana
✅ Python script runner
✅ Optional pgAdmin
✅ Ready-to-use network


