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

## Trascrizione Country card

> ⚠️ **Correzione importante sui bucket.** Le vere **Country card** non sono nel bucket `country`
> (745×1040 = in realtà le *Starting Ability* a tutta pagina + Executive Order), bensì nel bucket
> **`ability`** (485×745), mescolate con Market/Growth/Auto-Influence. Si riconoscono dal layout:
> esagono valore, bandiera, mappa della Regione, striscia risorse in basso.

### ✅ Tutte le Country card trascritte (77 Paesi)

Le Country card sono nel bucket `ability` (485×745), raggruppate per **Regione**. La Regione è
**stampata su ogni carta** (sotto il nome): mappatura finale verificata leggendo le carte una per una.

| Regione | id `ability_*` (run principale) | # |
|---------|----------------------------------|---|
| Middle East – North Africa | a090–a101 | 12 |
| Central Asia | a028–a037 | 10 |
| Europe (teal) | a038–a047 + a024 (*EU Member States*) | 11 |
| Americas | a048–a057 + a026 (Chile), a027 (Brazil) | 12 |
| Africa | a058–a069 | 12 |
| South Asia | a070–a077 | 8 |
| East Asia – Pacific | a078–a089 | 12 |
| **Totale** | | **77** |

Indice: [`countries/index.json`](countries/index.json) · Legenda simboli: [`RESOURCE_LEGEND.md`](RESOURCE_LEGEND.md).

Le carte **non-Paese** del bucket `ability`: a000–a002 e a018–a023 = **Commerce/Trade card** delle
potenze (es. Russia mostra 3 barili + 3 minerali, coerente col regolamento); a003–a016, a017, a025
= **duplicati** di Country (la partita TTS è a metà, le carte sono sparse tra mazzi e tavolo).

> Verifiche incrociate col regolamento: Iran/Syria → USA non può migliorare relazioni; Russia ha
> base in Vietnam; valori di Turkey (3), Australia (3), Norway (2), Tajikistan (1) corrispondono
> agli esempi; India fornisce import di Servizi (esempio di Trade).

### ✅ Carte abilità iniziali (Starting Ability) — 4 potenze (36 carte)

Si trovano nel bucket **`country`** (745×1040, abilità a tutta pagina). Si distinguono dalle Market
(stesso formato) perché hanno la **bandiera della potenza** accanto al nome, mentre le Market mostrano
un **costo Research** (🔍 + numero). Layout: barra colore = tipo (verde=diplomatic, arancio=economic,
rosso=military, blu=domestic); box in alto a sx = bonus Research (numero 🔍) + top bonus (monete/risorsa).

Ogni potenza ha **9 carte distinte = 7 comuni + 2 uniche** (nel mazzo iniziale da 12, alcune in doppia copia):

| | Carte uniche |
|---|---|
| **USA** | Global Currency, Military Pact |
| **EU** | Soft Power, Humanitarian Aid |
| **Russia** | Military Re-Equipment, Energy Titan |
| **China** | Economic Diplomacy, The World's Factory |

Comuni a tutte: Growth Strategy, Foreign Direct Investment, Diplomatic Engagement, Foreign Trade,
New Allies, Foreign Military Presence, Military Reinforcements.

File: [`abilities/*_starting.json`](abilities/) (testo effetto verbatim + tipo + bonus) · indice [`abilities/index.json`](abilities/index.json).

## Prossimi passi

1. Trascrivere le **Market card** (bucket `country` con costo Research, + bucket `ability` piccolo) e gli **Executive Order** (4).
2. Trascrivere **Growth card** e **Strategic Asset** (bucket `strategic_asset`) e **Auto-Influence**.
3. Codificare gli effetti come micro-DSL (`effect` → array di `op`), guidandosi con la logica Lua.
4. Catalogare token e plance (`Counter/`, `Player Production/`, `Player Aid/`).

> ⚠️ **Uso personale.** Gli asset grafici sono © Hegemonic Project Limited e non vanno ridistribuiti.
