# World Order — progetto Godot

Versione digitale (uso personale) del gioco da tavolo *World Order*. Engine **Godot 4.x**.

## Struttura

- `scripts/data/` — modello dati come classi `Resource` (Country, Ability, Region, ...).
- `scripts/engine/` — motore di regole **puro** (nessun nodo di scena):
  - `influence_track.gd` — slot Influenza permanenti/temporanei (push FIFO, convert, reset).
  - `scoring.gd` — punteggio Regione (maggioranze, spareggi, cubi locali).
  - `threat.gd` — risoluzione THREAT/Defense.
  - `player_state.gd`, `game_state.gd`, `game_setup.gd` — stato e setup partita.
  - `data_loader.gd` — carica i dati da `res://data/` (sincronizzati da `../data/`).
- `scripts/tests/` — test del motore che riproducono gli esempi del regolamento.
- `assets/cards/` — immagini delle carte. `data/` — dati di gioco (JSON).

## Test

```bash
# con Godot nel PATH:
GODOT=/percorso/Godot ../tools/run_godot_tests.sh
# oppure manualmente:
godot --headless --path . --import
godot --headless --path . --script res://scripts/tests/run_tests.gd
```

I test sono verificati con **Godot 4.3** (21/21 pass): Influence FIFO, Scoring (esempio
MENA), THREAT (esempi 1 e 2), setup partita.

> Nota: dopo aver aggiunto/rinominato uno script `class_name`, rilancia `--import` per
> aggiornare la cache delle classi globali prima di eseguire i test.

## Stato

Fase 1 (motore) in corso: implementati Influenza, Scoring, THREAT, setup. Da fare: le 8
azioni della fase di Azione, la macchina a stati delle 3 fasi/6 round, Aftermath completo,
e la codifica degli effetti delle carte come micro-DSL.
