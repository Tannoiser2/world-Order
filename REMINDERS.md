# Reminders — riprendere domani (nuova sessione)

**Progetto**: World Order (digitale). Deploy attuale: **v0.7.30** su `main`.
Branch di lavoro: `claude/world-order-digital-roadmap-0msb1a`.

## Come riprendere
- Test: da `game/` → `verify_ui.gd` (UI) e `run_tests.gd` (engine, 101/0).
- Rulebook: `/Tabelle_Materiali/World Order/Rules.pdf` (24 pp.).
- Engine: `game/scripts/engine/` · UI: `game/scripts/ui/board_view.gd` · dati: `game/data/`.

## ✅ Calibrazione plance (4 potenze) — FATTA (2026-06-21)
Template utente in `game/assets/calibration/plance/` mappati e validati a video
(overlay dei pallini + simulazione dello stato di setup sulle 4 plance reali).
Template→potenza: **0=USA, 1=China, 2=Russia, 3=EU** (dedotto dalle lunghezze dei
tracciati). Layout **CONDIVISO** confermato dai dati: stesse coordinate d'inizio per
tutti, cambia solo la lunghezza. **Unica eccezione**: `raw_materials` parte da x
diversa per potenza → costante `RAW_MATERIALS_X` in `board_view.gd`.
Aggiornate `PROD_PITCH`, `PROD_TRACKS` (incl. produzione **armate**, sulla riga della
Diplomazia), `FOCUS_POS`, `PROSPERITY_POS`, `RES_TRACK_X`, `_resource_slot`.
**Riserva carri/Armate in alto (`RESERVE_ARMY_POS`) lasciata invariata** (non marcata
nei template = "i carri non si toccano").


## Priorità #1 — allineare la meccanica al regolamento
Vedi `TODO.md` → sezione **"📌 Prossima sessione — audit regole↔meccanica"**: 21 discrepanze
trovate (azioni, setup/fasi, aftermath/scoring), molte **rules-breaking**. Le più gravi:
1. Abilità speciali potenze (USA/Russia/Cina) **mai applicate** nello scoring reale.
2. **+2 VP per Strategic Asset non usato** e **Executive Orders (+3 VP)** non assegnati a fine partita.
3. **Spareggio vincitore** errato (ordine di inserimento invece di 1° bonus → cubi → pari).
4. **Auto-Influence**: 1 carta invece di 2; money commercio incondizionato.
5. **Trade**: bene da 20 = Armate (non Diplomazia); Armate non commerciabili.
6. **Engage/Improve/Invest/Build/Move**: prerequisiti e limiti del regolamento non applicati.
7. **ROI e THREAT**: scarto Engage token (money / +Difesa) non collegati.

## Priorità #2 — rifiniture UI (da `TODO.md` sezione 🟡)
- Verificare `board.json` di tutte le Regioni vs tabellone (MENA era errata).
- Engage token: posa calibrata. FDI/Base anche sulle Country sul tabellone.
- Maggioranza a inizio partita (tutti pari): valutare se nasconderla.
- UX dopo Move: il cassetto resta chiuso.

## Da chiedere all'utente
- La sua lista di bug dal playtest (sezione "🔴 Da triage" in TODO.md, ancora vuota).
- Priorità: prima i fix di regole (scoring/fine partita) o la UI?
