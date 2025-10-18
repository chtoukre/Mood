# Usage Guide

This page explains how to:
✅ Use the Python CLI scripts  
✅ Insert data into PostgreSQL  
✅ Generate fake history  
✅ View data in Grafana  

---

## 📦 Data Model

Each daily entry tracks 20 well-being dimensions:

```python
ASPECTS = [
    "moral_global", "gratitude", "pleine_conscience", "famille", "amis",
    "relation", "plaisir", "calme", "sincerite", "temps_pour_soi",
    "alimentation", "hydratation", "exercice", "sorties", "sante",
    "creativite", "finances", "education_travail", "emotions_pensees",
    "present", "futur"
]
```

Database table used (PostgreSQL):

```sql
CREATE TABLE IF NOT EXISTS mood_entries (
  date DATE PRIMARY KEY,
  moral_global INT,
  gratitude INT,
  pleine_conscience INT,
  famille INT,
  amis INT,
  relation INT,
  plaisir INT,
  calme INT,
  sincerite INT,
  temps_pour_soi INT,
  alimentation INT,
  hydratation INT,
  exercice INT,
  sorties INT,
  sante INT,
  creativite INT,
  finances INT,
  education_travail INT,
  emotions_pensees INT,
  present INT,
  futur INT,
  overall_mood INT,
  note TEXT
);
```

---

## ✍️ Manual Daily Entry (Local JSON/CSV)

Run from project root:

```bash
python scripts/daily-check.py --name mylog
```

✅ Output:

```
data/mylog.json
data/mylog.csv
```

---

## 🐘 Insert into Local PostgreSQL

If you're using Minikube-local DB from `k8s/postgres-moodtracker`:

```python
# Edit inside daily-check-k8s.py
host="localhost"  # or pod URL if inside k8s
dbname="moodtracker"
user="mooduser"
password="moodpass"
```

Run:

```bash
python scripts/daily-check-k8s.py --name mylog
```

---

## ☁️ Insert into AWS RDS (via SSM Tunnel Pod)

If the SSM tunnel is running in Kubernetes:

Use host **inside Kubernetes**:

```
postgres-rds.default.svc.cluster.local
```

From Kubernetes pod:

```bash
kubectl run -it psql --image=postgres --restart=Never \
  -- psql -h postgres-rds.default.svc.cluster.local -U <user> -d postgres
```

From Python:

```python
host="postgres-rds.default.svc.cluster.local"
port=5432
```

---

## 🔧 Generate Fake Historical Data

```bash
python scripts/generate-fake-entry-k8s.py
```

* Fills DB starting from year 2000 to today
* Useful for dashboards & Grafana testing

---

## 📊 Use Grafana Locally

You can use:

### Option A — Local Grafana in Kubernetes

```bash
kubectl port-forward svc/grafana 3000:3000
```

Access [http://localhost:3000](http://localhost:3000) (admin/admin)

Add PostgreSQL datasource:

```
Host: postgres-rds.default.svc.cluster.local:5432
Database: postgres
User: <your user>
SSL Mode: require
```

---

### Option B — Grafana with Docker Compose

Use the full stack (Grafana + Postgres + script runner) via Docker — see root `docker-compose.yml`.

---

✅ Next: see **[SSM Tunnel Details](tunnel-ssm.md)**.

```


```

