# Dati & pipeline asset — Fase 0

Questa cartella documenta l'estrazione dei dati e degli asset dal materiale sorgente
(`Tabelle_Materiali/World Order/`) verso il progetto Godot in `../game/`.

## Sorgenti

- `Rules.pdf` — regolamento ufficiale V1.0.
- `3362153615.json` — salvataggio **Tabletop Simulator** *"World Order - Scripted"*.
  - Contiene gli sprite-sheet delle carte (URL Steam → file locali in `Images/`).
  - Contiene **~138K caratteri di logica Lua** (`LuaScript`): riferimento per gli effetti.
- `Images/` — sprite-sheet (griglie fino a 10×7) e carte/plance singole.

## Pipeline di estrazione

Script: [`../tools/extract_cards.py`](../tools/extract_cards.py)

```bash
python tools/extract_cards.py \
  --source "/percorso/Tabelle_Materiali/World Order" \
  --out    game/assets/cards \
  --manifest game/data/cards_manifest.json
```

Cosa fa:
1. Indicizza i file locali in `Images/` per hash (gli ultimi 40 caratteri del nome = hash dell'URL Steam).
2. Per ogni istanza di carta nel salvataggio TTS calcola lo sheet e la **cella della griglia**
   dal `CardID` (`CardID = deckKey*100 + posizione`).
3. **Deduplica** per identità `(sheet, cella)` — il salvataggio è una partita *a metà*, quindi
   le stesse carte compaiono sia nei mazzi sia sul tavolo.
4. Classifica ogni carta per **forma** (rapporto larghezza/altezza) e ritaglia l'immagine.

Output: **253 carte uniche** in `game/assets/cards/<tipo>/` + manifest `game/data/cards_manifest.json`.

## Classificazione per forma (bucket)

| Bucket | Dimensione tipica | Ratio | Contenuto |
|--------|-------------------|-------|-----------|
| `country` | 745×1040 | ~0.72 | **Country card** (117) |
| `ability` | 485×745 | ~0.65 | **Market / Starting Ability / Growth / Auto-Influence** (102) |
| `strategic_asset` | 1000×716 | ~1.40 | **Strategic Asset** (20) |
| `wide_aux` | 745×485 | ~1.53 | **Trade Deals / plance ausiliarie** (14) |

> Il bucket `ability` è ancora misto: va suddiviso ispezionando il contenuto (colore del bordo
> per le Ability, badge di livello per le Growth, layout regione/bandiera per le Auto-Influence).

## Componenti identificati dal salvataggio TTS

- **Market Ability**: un mazzo da **66** carte abilità (Diplomatic/Economic/Military/Domestic).
- **Auto-Influence**: carte con layout Regione + bandiere (usate nelle partite 2–3 giocatori).
- **Country card**: ~60+ Paesi, divisi per Regione; nel save sono sparsi tra mazzi regionali e tavolo.
- **Growth card**: in pile per nome/livello.
- **Strategic Asset**: 5 per potenza.

## Schema dati

- `schema/card.schema.json` — JSON Schema (neutro) delle carte trascritte.
- Le classi `Resource` GDScript equivalenti sono in `../game/scripts/data/`.

## Prossimi passi (trascrizione)

1. Suddividere il bucket `ability` nei tipi reali.
2. Trascrivere ogni carta in JSON conforme allo schema (nome, costi, effetti come micro-DSL).
3. Definire il vocabolario delle operazioni (`op`) del micro-DSL, guidandosi con la logica Lua.
4. Catalogare token e plance (`Counter/`, `Player Production/`, `Player Aid/`).

> ⚠️ **Uso personale.** Gli asset grafici sono © Hegemonic Project Limited e non vanno ridistribuiti.
