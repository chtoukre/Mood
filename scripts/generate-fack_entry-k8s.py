import psycopg2
import random
from datetime import datetime, timedelta

# === Liste des aspects à noter ===
ASPECTS = [
    "moral_global", "gratitude", "pleine_conscience", "famille", "amis",
    "relation", "plaisir", "calme", "sincerite", "temps_pour_soi",
    "alimentation", "hydratation", "exercice", "sorties", "sante",
    "creativite", "finances", "education_travail", "emotions_pensees",
    "present", "futur"
]

# Connexion à PostgreSQL
def get_connection():
    return psycopg2.connect(
        host="localhost",  # ou IP/minikube DNS si PostgreSQL tourne dans K8s
        port=5432,
        dbname="moodtracker",
        user="mooduser",
        password="moodpass"
    )

# Générer une entrée aléatoire pour une date donnée
def generate_entry(date_str):
    entry = {aspect: random.randint(1, 10) for aspect in ASPECTS}
    entry["overall_mood"] = random.randint(1, 10)
    entry["note"] = f"Entrée générée automatiquement le {date_str}"
    return entry

# Insertion dans PostgreSQL
def insert_into_postgres(conn, date_str, entry):
    try:
        cur = conn.cursor()

        columns = ["date"] + ASPECTS + ["overall_mood", "note"]
        values = [date_str] + [entry[aspect] for aspect in ASPECTS] + [entry["overall_mood"], entry["note"]]
        placeholders = ', '.join(['%s'] * len(values))

        sql = f"""
        INSERT INTO mood_entries ({', '.join(columns)})
        VALUES ({placeholders})
        ON CONFLICT (date) DO NOTHING
        """

        cur.execute(sql, values)
        conn.commit()
        cur.close()
    except Exception as e:
        print(f"❌ Erreur pour {date_str} :", e)

# Génère toutes les entrées entre deux dates
def generate_all_entries():
    start_date = datetime(2000, 9, 1)
    end_date = datetime.today()

    total_days = (end_date - start_date).days
    print(f"📅 Génération de {total_days} jours d’entrées...")

    conn = get_connection()

    current_date = start_date
    while current_date <= end_date:
        date_str = current_date.strftime("%Y-%m-%d")
        entry = generate_entry(date_str)
        insert_into_postgres(conn, date_str, entry)
        current_date += timedelta(days=1)

    conn.close()
    print("✅ Données générées et insérées avec succès !")

if __name__ == "__main__":
    generate_all_entries()

