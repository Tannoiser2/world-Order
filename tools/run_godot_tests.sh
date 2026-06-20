#!/usr/bin/env bash
# Esegue i test del motore in headless. Richiede Godot 4.x nel PATH (o impostare GODOT).
# Uso: GODOT=/percorso/godot ./tools/run_godot_tests.sh
set -e
GODOT="${GODOT:-godot}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$DIR/tools/sync_data.py"
# re-import necessario per registrare le classi class_name
"$GODOT" --headless --path "$DIR/game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$DIR/game" --script res://scripts/tests/run_tests.gd
