# World Order — Roadmap per la versione digitale

> Documento di pianificazione per lo sviluppo di una versione digitale del gioco da tavolo **World Order** (Hegemonic Project Limited, V1.0 2025).
>
> Tutto il materiale sorgente (regolamento, asset grafici, prototipo Tabletop Simulator) si trova nel repository `Tabelle_Materiali`, cartella `World Order/`.

---

## 1. Sintesi del gioco

**World Order** è un gioco di **maggioranza d'area (area majority)** per **2–4 giocatori**. Ogni
giocatore controlla una delle quattro grandi potenze degli anni 2010 — **USA, Cina, Russia, Unione
Europea** — e cerca di espandere la propria **Influenza** nelle Regioni del mondo usando strumenti
**diplomatici, economici e militari**.

| Parametro | Valore |
|-----------|--------|
| Giocatori | 2–4 |
| Durata partita | 6 round |
| Fasi per round | 3 (Preparazione → Azione → Aftermath) |
| Momenti di punteggio | round 3 e round 6 |
| Condizione di vittoria | più Punti Vittoria (VP) alla fine del round 6 |

### 1.1 Struttura di un round

1. **Fase di Preparazione** (saltata al round 1)
   - Pesca 6 carte
   - Rivela carte Country
   - Determina l'ordine di turno (in ordine inverso di VP)
   - Produci risorse primarie (Energia, Materie Prime, Cibo)
   - Scegli il **Focus** del round (Domestico / Diplomatico / Militare)
2. **Fase di Azione** (4 turni per giocatore)
   - Gioca una carta Ability e risolvi l'effetto, oppure gioca una Strategic Asset, oppure passa (+10 monete)
   - Azioni possibili: *Improve Relations, Engage, Trade, Invest, Move, Build a Base, Get a Growth Card, Produce*
   - **Research**: a fine fase si acquistano nuove carte dal **Market**
   - **Add Auto-Influence** (solo partite 2–3 giocatori)
3. **Fase di Aftermath**
   - Return on Investments (FDI ed Engage token)
   - Increase Prosperity
   - Resolve THREAT (presenza militare avversaria)
   - **Scoring** (solo round 3 e 6): maggioranze di Influenza per Regione + 3 token Maggioranza (denaro, armate, paesi alleati)

### 1.2 Concetti chiave da modellare

- **7 tipi di risorsa**: 3 primarie (Energia ⚡, Materie Prime ⛏, Cibo 🌾) + 4 secondarie (Beni di consumo, Servizi, Diplomazia, Armate). Le secondarie hanno costi di produzione in risorse primarie.
- **Influenza**: cubi posti nelle Regioni, in slot **permanenti** (sopra la linea, restano fino a fine partita) o **temporanei** (sotto la linea, FIFO da sinistra, vengono spinti fuori). Una Regione fa punti solo se **tutti gli slot permanenti sono pieni**.
- **Focus** del round: modifica costi/bonus (es. Diplomatic → Engage costa 2 in meno; Domestic → +2 Research; Military → +1 THREAT/Defense).
- **Zona di interesse / THREAT / Defense**: confronto di armate (Army token) per Regione.
- **Trade**: export/import di risorse tra giocatori e Country, con Trade Deals e Commerce card.
- **Abilità speciali per potenza** (Member of NATO, Global Superpower Status, Secured Sphere of Influence, Global FDI Network).
- **Prosperità**, **Growth card** (con abilità che si attivano al round = livello), **Strategic Asset** (uso singolo), **Executive Orders** (modulo opzionale).

---

## 2. Inventario degli asset disponibili

Tutti gli asset sono in `Tabelle_Materiali/World Order/`.

| Risorsa | Posizione | Note |
|---------|-----------|------|
| Regolamento | `Rules.pdf` | 24 pagine, V1.0 — fonte autorevole per tutte le regole |
| Prototipo digitale | `3362153615.json` | Salvataggio **Tabletop Simulator** *"World Order - Scripted"* |
| Logica di gioco | dentro il JSON, campo `LuaScript` | **~138.000 caratteri di Lua** con turn order, fasi, scoring, gestione coin/influence/VP — **riferimento implementativo prezioso** |
| Immagini carte | `Images/Carte/` (67 file) | Sprite-sheet in griglia (tipicamente 10×7 = fino a 70 carte) + carte singole |
| Counter/Token | `Images/Counter/` (31 file) | Token Influenza, Armate, Base, FDI, Engage, marker |
| Aiuti giocatore | `Images/Player Aid/` (8 file) | Plance riepilogative ad alta risoluzione (fino a 2480×2480) |
| Plance produzione | `Images/Player Production/` (4 file) | Player board delle 4 potenze (fino a 3308×2363) |
| Tabellone / vari | `Images/` (6 file) | Inclusi atlanti grandi (es. 10000×5005) = mappa/tabellone |

### 2.1 Composizione mazzi (dal salvataggio TTS)

Conteggi rilevati nel JSON, coerenti con il regolamento:

- **4 mazzi da 12 carte** → Starting Ability deck delle 4 potenze (12 carte ciascuna)
- **4 mazzi da 5 carte** → Strategic Asset (5 per potenza, se ne tengono 2)
- **1 mazzo da 20** → Market Ability cards
- **1 mazzo da 66** → Country cards (mappa, divise per Regione)
- **2 mazzi da 10** → Growth cards per livello
- **mazzi da 8 / 3 / 2** → Growth cards rimanenti, Auto-Influence, carte ausiliarie

> ⚠️ **Nota importante**: nel salvataggio TTS le carte **non** hanno testo strutturato (nickname/description vuoti) — il contenuto è **interamente nelle immagini**. Per una versione digitale con logica server-side servirà **trascrivere/strutturare il testo di ogni carta** in un formato dati (vedi §4 e Fase 0).

---

## 3. Strategia tecnologica

### 3.1 Obiettivo del prodotto

Una versione digitale **giocabile**, multipiattaforma (desktop + browser, idealmente mobile),
con:
- partita **hot-seat / pass-and-play** come primo traguardo,
- **multiplayer online** asincrono/sincrono come traguardo successivo,
- **bot/IA** opzionale per giocare in solitaria e per completare i tavoli 2–3 giocatori
  (le regole già prevedono le Auto-Influence card per i "non giocatori").

### 3.2 Stack consigliato (raccomandato)

**Web-first con TypeScript**, perché gli asset sono immagini 2D e il multiplayer è centrale:

- **Logica di gioco**: motore in **TypeScript**, deterministico, framework **[boardgame.io](https://boardgame.io)**.
  - Pensato per giochi a turni: gestisce stato immutabile, ordine di turno, fasi, log mosse, multiplayer e bot out-of-the-box.
  - Server Node.js + client React già integrati.
- **UI**: **React** + **PixiJS** (o Canvas/SVG) per il tabellone e il drag&drop di carte/token.
- **Server multiplayer**: Node.js (server boardgame.io) + persistenza (Postgres/SQLite); lobby e matchmaking custom.
- **Packaging**: web (PWA) come base; **Electron/Tauri** per desktop; eventuale wrapper per mobile.

**Alternativa** (se si preferisce un client più "ricco"/3D o un singolo binario): **Godot 4**
(GDScript/C#) — ottimo per export multipiattaforma, ma il multiplayer e l'IA vanno costruiti più a mano.

> Decisione da confermare con il committente prima della Fase 1 (vedi §8 "Decisioni aperte").

### 3.3 Principio architetturale chiave

**Separare nettamente il motore di regole dalla UI.**
Il motore (regole, validazione mosse, scoring) deve essere una libreria pura, testabile,
**senza dipendenze grafiche**. La UI è solo un renderer dello stato + emettitore di mosse.
Questo permette: test automatici delle regole, multiplayer autorevole lato server (anti-cheat),
e riuso dello stesso motore per il bot.

---

## 4. Modello dati (da definire in Fase 0)

Strutture principali da formalizzare in JSON/TypeScript:

- `GameState`: round, fase, ordine di turno, supply (coin, base, FDI), Market, mazzi, board.
- `Player`: potenza, plancia (livelli di produzione, risorse, prosperità, focus), mano, mazzo,
  scarti, carte giocate, Country alleate, Strategic Asset, Growth card, token (armate, engage),
  VP, denaro.
- `Region`: nome, zona d'interesse (flag potenze), slot Influenza (permanenti/temporanei con valori
  VP), costo Engage, cubi presenti, armate presenti, Influenza locale iniziale (cubi neri).
- `CountryCard`: nome, regione, valore (◇), costo Invest, risorse export/import, flag che possono/non
  possono migliorare relazioni, flag che possono costruire base, simbolo base.
- `AbilityCard` / `MarketCard`: tipo (Diplomatic/Economic/Military/Domestic), costo, effetto
  **strutturato** (lista di "step" eseguibili dal motore), bonus Research.
- `StrategicAsset`, `GrowthCard` (livello, costo, VP, abilità ongoing), `AutoInfluenceCard`,
  `ExecutiveOrder`.

> Il **collo di bottiglia di contenuto** è la **codifica degli effetti delle carte** in un piccolo
> "linguaggio" di azioni (DSL/JSON) che il motore sa eseguire. La logica Lua del prototipo TTS è la
> guida di riferimento per replicare i comportamenti corretti.

---

## 5. Roadmap a fasi

### Fase 0 — Fondamenta & contenuti (estrazione dati)
**Obiettivo:** trasformare regolamento + asset in dati strutturati e versionati.
- [ ] Definire lo schema dati (§4) e committarlo.
- [ ] Ritagliare gli sprite-sheet di `Images/Carte/` in singole carte (script di slicing dalle griglie 10×7) e indicizzarle.
- [ ] Catalogare token e plance (`Counter/`, `Player Production/`, `Player Aid/`).
- [ ] **Trascrivere** in dati: 4×12 carte iniziali, 20 Market, 66 Country, Growth (per livello), 4×5 Strategic Asset, Auto-Influence, 4 Executive Orders.
- [ ] Pipeline asset (ottimizzazione/atlas, naming coerente, licenze/diritti chiariti).
**Deliverable:** dataset completo + libreria di asset pronti.

### Fase 1 — Motore di regole (core engine)
**Obiettivo:** simulare una partita completa senza UI.
- [ ] Macchina a stati delle 3 fasi e dei 6 round.
- [ ] Sistema risorse (primarie/secondarie + produzione + cap a 10).
- [ ] Sistema Influenza (slot permanenti/temporanei, push FIFO, conversione, reset).
- [ ] Le 8 azioni della fase Azione + Market/Research.
- [ ] THREAT/Defense, Prosperità, Return on Investments.
- [ ] **Scoring** (round 3 e 6): maggioranze regioni + 3 token Maggioranza + abilità speciali potenze.
- [ ] Gestione tie-break e fine partita.
- [ ] **Suite di test** che riproduce gli esempi del regolamento (sono già numerici e verificabili).
**Deliverable:** motore + test che fa girare una partita 2–4 giocatori headless.

### Fase 2 — UI hot-seat (pass-and-play) — *MVP giocabile*
**Obiettivo:** prima versione realmente giocabile su un solo dispositivo.
- [ ] Rendering tabellone, Regioni, slot Influenza, plance, mano, Market.
- [ ] Interazioni: gioca carta, scegli Country/Regione, paga costi, posiziona Influenza/armate.
- [ ] Indicatori di fase/turno/Focus, log delle azioni, contatori VP/risorse/denaro.
- [ ] Validazione mosse e feedback errori (collegata al motore).
- [ ] Schermate setup partita (numero giocatori, scelta potenze con i vincoli del 2P).
**Deliverable:** **MVP** completabile da 2–4 persone sullo stesso schermo.

### Fase 3 — Multiplayer online
**Obiettivo:** partite a distanza, server autorevole.
- [ ] Server di gioco autorevole (boardgame.io) + sincronizzazione stato.
- [ ] Lobby, creazione/partecipazione partita, codici invito.
- [ ] Riconnessione, stato persistente, gestione disconnessioni.
- [ ] Mani nascoste (informazione segreta gestita lato server).
- [ ] Account/identità leggera (anche solo nickname per la beta).
**Deliverable:** partite online sincrone 2–4 giocatori.

### Fase 4 — IA / bot & moduli avanzati
- [ ] Bot di base (mosse legali + euristiche) sul motore di Fase 1.
- [ ] Gestione automatica delle potenze "non giocate" (Auto-Influence) nei tavoli 2–3.
- [ ] Modulo opzionale **Executive Orders**.
- [ ] Difficoltà multiple del bot.
**Deliverable:** gioco in solitario contro IA + tavoli 2–3 completati da bot.

### Fase 5 — Rifinitura, QA e rilascio
- [ ] Tutorial interattivo (la "Starting Hand" fissa del regolamento è ideale per l'onboarding).
- [ ] Animazioni, audio, accessibilità (daltonismo: le 4 potenze usano colori distinti), localizzazione (IT/EN).
- [ ] Bilanciamento/telemetria, fix di regole emersi dal playtest.
- [ ] Build di rilascio (web/PWA + desktop), distribuzione.
**Deliverable:** versione 1.0 pubblicabile.

---

## 6. Milestone & sequenza consigliata

```
M0  Dataset + asset (Fase 0)                ──► sblocca tutto
M1  Motore headless con scoring (Fase 1)    ──► cuore del progetto
M2  MVP hot-seat giocabile (Fase 2)         ──► primo traguardo "vedibile"
M3  Multiplayer online (Fase 3)
M4  IA + moduli opzionali (Fase 4)
M5  Release 1.0 (Fase 5)
```

Le Fasi 0 e 1 sono il **percorso critico**: la maggior parte del rischio (correttezza delle regole,
codifica degli effetti delle carte) si concentra lì. Conviene investirci presto e coprirle con test.

---

## 7. Rischi principali e mitigazioni

| Rischio | Impatto | Mitigazione |
|---------|---------|-------------|
| Effetti delle carte complessi/eterogenei | Alto | DSL/JSON per gli effetti + riferimento alla logica Lua del prototipo TTS |
| Regole ambigue (Influenza, scoring, tie-break) | Medio | Test che riproducono **gli esempi numerici del regolamento** |
| Testo carte solo nelle immagini | Medio | Fase 0 dedicata alla trascrizione strutturata |
| Diritti su asset/IP (gioco protetto da copyright) | Alto | Chiarire la licenza con l'editore (vedi §8) **prima** della distribuzione |
| Scope creep (multiplayer+IA subito) | Medio | MVP hot-seat prima, online/IA dopo |

---

## 8. Decisioni aperte (da confermare)

1. **Diritti / scopo**: il gioco è © Hegemonic Project Limited. Questa versione digitale è
   **personale/prototipo** o destinata a **distribuzione**? Da chiarire prima di pubblicare asset/regole.
2. **Stack**: confermare **Web (TypeScript + boardgame.io + React)** vs **Godot**.
3. **Priorità**: hot-seat prima e online dopo (consigliato) oppure online da subito?
4. **Piattaforme target**: solo browser, oppure anche desktop/mobile nativi?
5. **IA**: necessaria per la 1.0 o rimandabile?

---

## 9. Riferimenti

- `Tabelle_Materiali/World Order/Rules.pdf` — regolamento ufficiale V1.0
- `Tabelle_Materiali/World Order/3362153615.json` — prototipo Tabletop Simulator (logica Lua di riferimento)
- `Tabelle_Materiali/World Order/Images/` — asset grafici (carte, token, plance, tabellone)
- [boardgame.io](https://boardgame.io) — framework consigliato per il motore/multiplayer

---

*Crediti gioco originale — Game Design: Varnavas Timotheou, Vangelis Bagiartakis · © 2025 Hegemonic Project Limited. "World Order" è un marchio di Hegemonic Project Limited.*
