# Mood Tracker Documentation

Welcome to the **Mood Tracker** project – a secure and extensible daily logging platform designed to track well-being over time. The project leverages **AWS**, **Terraform**, **Kubernetes (Minikube)**, **Grafana**, and **PostgreSQL**, with a foundation ready to evolve into a full web application with authentication and dashboards.

---

## ✅ Project Goals

- Collect **daily emotional metrics** (mood, gratitude, calm, family, energy, etc.)
- Store data **locally** (JSON/CSV) and/or in **PostgreSQL**
- Provide a **secure cloud-based database** using **AWS RDS (private)**
- Access AWS RDS securely via **SSM tunnel (no public exposure)**
- Visualize insights via **Grafana dashboards**
- Evolve gradually into a **web app** (frontend + backend + RDS)
- Demonstrate **real DevOps architecture** (AWS + Terraform + Kubernetes)

---

## 🔧 Technology Overview

| Component               | Technology                          |
|------------------------|--------------------------------------|
| Infrastructure         | Terraform + AWS                      |
| Database               | PostgreSQL (local + AWS RDS)         |
| Secure access          | AWS SSM Bastion + Kubernetes tunnel  |
| Dashboards             | Grafana                              |
| Scripting interface    | Python CLI tools                     |
| Local Dev Environment  | Minikube + Docker Compose            |
| Documentation          | MkDocs + Material Theme              |

---

## 🚀 Repository Highlights

✅ Private AWS RDS PostgreSQL via SSM (no public DB access)  
✅ Kubernetes pod as **secure database proxy** (`ssm-proxy`)  
✅ Terraform AWS infrastructure module included  
✅ Python CLI scripts to insert daily logs  
✅ Local Grafana for data exploration  
✅ Ready for future **frontend + API** integration  
✅ Clean architecture for **learning or production** projects  

---

## 📚 Documentation Structure

This documentation will guide you through:

| Section | Description |
|----------|-------------|
| **Architecture** | System design (AWS + k8s + SSM) |
| **Setup** | Deploy infra & local environment |
| **Usage** | Python scripts + local DB + Grafana |
| **SSM Tunnel** | Secure access to private RDS |
| **Roadmap** | Future vision of the project |

---

## ✅ Quick Start

```bash
# Clone the repo
git clone https://github.com/yourusername/mood-tracker.git
cd mood-tracker

# Launch documentation preview
mkdocs serve

