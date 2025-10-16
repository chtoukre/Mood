import json
import csv
import os
from datetime import datetime
import argparse


# === Liste des aspects à noter ===
ASPECTS = [
    "moral_global", "gratitude", "pleine_conscience", "famille", "amis",
    "relation", "plaisir", "calme", "sincerite", "temps_pour_soi",
    "alimentation", "hydratation", "exercice", "sorties", "sante",
    "creativite", "finances", "education_travail", "emotions_pensees",
    "present", "futur"
]

# === Chemins des fichiers ===
JSON_FILE = "data/entries.json"
CSV_FILE = "data/overview.csv"


def demander_note(aspect):
    while True:
        try:
            note = int(input(f"{aspect.replace('_', ' ').capitalize():<25} (1-10) : "))
            if 1 <= note <= 10:
                return note
            else:
                print("➡️  Merci d’entrer une note entre 1 et 10.")
        except ValueError:
            print("➡️  Entrée invalide. Tape un nombre entre 1 et 10.")


def charger_json(path):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def sauvegarder_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def ajouter_au_csv(path, date_str, entry):
    file_exists = os.path.isfile(path)

    with open(path, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)

        if not file_exists:
            headers = ["date"] + ASPECTS + ["overall_mood", "note"]
            writer.writerow(headers)

        row = [date_str] + [entry[aspect] for aspect in ASPECTS] + [entry["overall_mood"], entry["note"]]
        writer.writerow(row)



def get_args():
    parser = argparse.ArgumentParser(description="Journal quotidien avec notes")
    parser.add_argument("--name", type=str, help="Nom du fichier à générer (sans extension)", default="overview")
    return parser.parse_args()
def main():
    args = get_args()
    base_name = args.name

    json_path = f"data/{base_name}.json"
    csv_path = f"data/{base_name}.csv"

    os.makedirs("data", exist_ok=True)

    print("\n=== Journal Quotidien ===")
    today = datetime.now().strftime("%Y-%m-%d")
    print(f"Date : {today}\n")

    entry = {}
    for aspect in ASPECTS:
        entry[aspect] = demander_note(aspect)

    overall_mood = demander_note("Note globale du jour")
    note = input("\nUne petite note ? (optionnel)\n> ")

    entry["overall_mood"] = overall_mood
    entry["note"] = note

    # Charger et mettre à jour le fichier JSON
    data = charger_json(json_path)
    data[today] = entry
    sauvegarder_json(json_path, data)

    # Ajouter au fichier CSV
    ajouter_au_csv(csv_path, today, entry)

    print(f"\n✅ Entrée enregistrée dans {csv_path} et {json_path} !\n")
if __name__ == "__main__":
    os.makedirs("data", exist_ok=True)
    main()

