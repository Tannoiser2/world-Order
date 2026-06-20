#!/usr/bin/env python3
"""Valida i file di trascrizione delle carte (data/countries/*.json, ...)
contro data/schema/card.schema.json e verifica l'esistenza degli asset.

Uso: python tools/validate_data.py
"""
import json, glob, os, sys

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    schema = json.load(open(os.path.join(root, "data/schema/card.schema.json")))
    try:
        from jsonschema import Draft202012Validator
        validator = Draft202012Validator(schema)
    except ImportError:
        print("jsonschema non installato: salto la validazione di schema, controllo solo gli asset.")
        validator = None

    cards_root = os.path.join(root, "game/assets/cards")
    errors, total = 0, 0
    for path in sorted(glob.glob(os.path.join(root, "data/**/*.json"), recursive=True)):
        if "schema" in path:
            continue
        doc = json.load(open(path))
        cards = doc.get("countries") or doc.get("cards") or []
        for c in cards:
            total += 1
            if validator:
                for e in validator.iter_errors(c):
                    print(f"[schema] {os.path.basename(path)} {c.get('id')}: {e.message}")
                    errors += 1
            art = c.get("art")
            if art and not os.path.exists(os.path.join(cards_root, art)):
                print(f"[asset] {os.path.basename(path)} {c.get('id')}: art mancante {art}")
                errors += 1
    print(f"\nCarte controllate: {total} — errori: {errors}")
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()
