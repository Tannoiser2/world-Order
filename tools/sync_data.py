#!/usr/bin/env python3
"""Copia i dati di gioco (data/) dentro al progetto Godot (game/data/),
cosi' il motore puo' caricarli via res://data/. La copia canonica resta in data/."""
import shutil, os, glob
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, "data")
dst = os.path.join(root, "game", "data")
os.makedirs(dst, exist_ok=True)
copied = 0
for path in glob.glob(os.path.join(src, "**", "*.json"), recursive=True):
    if os.sep + "schema" + os.sep in path:
        continue
    rel = os.path.relpath(path, src)
    out = os.path.join(dst, rel)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    shutil.copy2(path, out)
    copied += 1
print(f"Sincronizzati {copied} file JSON in game/data/")
