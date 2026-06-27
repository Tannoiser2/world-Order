# Regole degli Automa (Bot) — World Order: Diplomacy & Dominance

Trascrizione strutturata delle regole degli **Automa** (i "bot") dall'espansione
ufficiale *Diplomacy & Dominance* (Rulebook v1.0, © 2025 Hegemonic Project Limited),
per uso personale come riferimento di sviluppo del porting digitale.

Gli Automa permettono di giocare **in solitario** (contro 1–3 Automa) o di **completare
i tavoli** 2–3 giocatori sostituendo i giocatori mancanti. Due livelli di difficoltà:
**Normal** e **Hard** (le differenze Hard sono nei box marcati `HARD`).

> Stato nel codice: oggi è implementata solo la parte **Add Auto-Influence** del
> regolamento base (vedi `game/scripts/engine/game_phases.gd::add_auto_influence` e
> `game/data/auto_influence.json`). Il sistema Automa completo qui sotto NON è ancora
> implementato (è la "Fase 4 — IA/bot" del ROADMAP). Vedi §"Dati ancora necessari".

---

## Principi generali

- Un Automa gioca come un umano, con differenze:
  - **Non tiene risorse e non usa la Player board.** Quando dovrebbe **spendere** risorse,
    spende **money**; quando dovrebbe **guadagnare** risorse, guadagna **money**.
  - **Eccezione: le Armate (Army token).** Si assume che l'Automa ne abbia sempre quante
    gliene servono e non paga nulla per produrle.
  - **Country alleate:** le tiene e le usa, ma **non le esaurisce mai**. Va tenuto traccia,
    per ogni Regione, di: numero di Country alleate, quante consentono una **Base militare**,
    e numero di simboli **Export** sulle carte.

---

## Setup

1. Player card dell'Automa sul tavolo.
2. Mischia il mazzo iniziale di Ability dell'Automa, coperto accanto alla Player card.
   Accanto: Starting Country cards, money iniziale (dalla Player card), Prosperity marker,
   una riserva di Army token e cubi Influenza.
3. Scoring marker dell'Automa sulla casella **10 VP** della Main board.
4. Automa board a portata di mano. Metti un Production cube di ogni Automa nelle Action
   space: **Improve Relations, Invest, Build a Base**. Focus marker su **Domestic**.
5. Un Production cube aggiuntivo di ogni Automa sulle caselle Round **2, 4, 6**.
   - `HARD`: anche sulla casella **5**.
6. Mischia il **Decision deck** e l'**Auto-Influence deck** vicino all'Automa board.
7. Ordine di turno come di consueto (più VP gioca primo). Essendo tutti gli Automa a 10 VP,
   parte chi ha **meno money iniziale**, poi gli altri a seguire.

---

## Fase di Preparazione

- **Draw Cards:** l'Automa NON pesca e NON tiene una mano.
- **Turn Order:** l'Automa sceglie sempre lo **slot disponibile più a destra**.
- **Choose Focus & Produce:** pesca una **Decision card** e leggi la riga corrispondente
  all'Automa → determina il Focus. (Con più Automa, una Decision card a testa.)
  L'Automa non produce risorse: in base al Focus riceve **money** = round × moltiplicatore:
  - **Domestic:** round × **10**
  - **Diplomatic:** round × **5**
  - **Military:** round × **3**

  Esempio: Diplomatic al round 4 → 4 × 5 = 20 money.

- **Bonus di Focus:**
  - **Domestic:** +2 [punti Research] durante lo step Research.
  - **Diplomatic:** Engage costa **5 in meno**; inoltre l'Automa **Improve Relations subito**
    con una Country sul tabellone **fuori** dalla sua zona di interesse. (Scegli la Country
    come al solito per Improve Relations, ignorando le Auto-Influence card che mostrano
    Regioni nella sua zona di interesse.)
  - **Military:** **+1 THREAT** dove ha Armate, **+1 Difesa** nella sua zona di interesse.

---

## Fase Azione

**Mappa dell'Automa board** (universale, uguale per tutti gli Automa — estratta dal
regolamento, vedi §"Dati dei componenti"):

| Tipo carta | Spazio SINISTRO | Spazio DESTRO |
|---|---|---|
| **Diplomatic** | Engage | Improve Relations |
| **Economic** | Invest | Trade |
| **Military** | Build a Base | Move |

(Lo spazio **Trade** è il destro della riga Economic; lo spazio **Invest** è il sinistro:
il fallback "se non puoi → Trade, sposta i cubi da Trade a Invest" lavora su questa riga.)

A inizio turno l'Automa **pesca una carta dal suo mazzo** e ne guarda **solo il tipo**
(colore/simbolo), NON applica l'effetto scritto. Poi consulta l'**Automa board**:

- **Diplomatic / Economic / Military:** guarda la riga dell'Automa board corrispondente
  al tipo della carta.
  - Se ci sono cubi dell'Automa nello **spazio sinistro** → esegue **quell'**azione e sposta
    **1** cubo da sinistra a destra.
  - Se NON ci sono cubi nello spazio sinistro → esegue l'azione dello **spazio destro** e
    sposta **tutti** i suoi cubi da destra a sinistra.
  - Se l'azione non è eseguibile per mancanza di money → esegue invece un **Trade**,
    spostando tutti i suoi cubi (se presenti) dallo spazio **Trade** allo spazio **Invest** a
    sinistra.
- **Domestic:** l'Automa **Gets a Growth Card** se può permettersela; altrimenti guadagna
  **30 money**.

Ogni azione è eseguita come nelle regole del gioco base. Sotto, come l'Automa decide i
dettagli di ciascuna azione. **Importante:** muovi i cubi sull'Automa board solo per
l'azione **effettivamente** eseguita.

### Improve Relations
1. Pesca una **Auto-Influence card** → Regione.
2. Scegli la Country da quella Regione con questi criteri, dall'alto in basso; se più
   opzioni restano valide, usa il punto successivo per restringere:
   - Una delle **Starting Country** dell'Automa.
   - Una Country in cui può **Build a Base**.
   - La Country con il **valore più alto** che può permettersi.
   - La Country card **più a sinistra**.
3. Costo: **5 money per ogni Diplomazia richiesta**. L'Automa **non** ottiene sconto per
   Country già alleate della stessa Regione.
4. Se ha **meno di 15 money**, considera solo Country che può permettersi (ripesca una
   Auto-Influence card se serve). Se non può permettersi nessuna Country disponibile →
   esegue **Trade** invece di Improve Relations.
5. Se Improve Relations con una sua Starting Country, rimetti la Starting Country nella
   scatola e tieni solo la nuova Country card; poi aggiungi un cubo Influenza alla Regione.
6. Se l'Improve Relations deriva dal bonus **Diplomatic Focus** (Preparazione): esegui
   normalmente ma **non muovere cubi** sull'Automa board.

### Engage
1. Pesca una **Auto-Influence card** → Regione. Se l'Automa non ha Country alleate in
   quella Regione, ripesca.
2. Costo: **5 money per ogni Diplomazia richiesta**, ridotto di **5 per ogni Country
   alleata** che ha da quella Regione (a prescindere dal valore), e di **altri 5** se ha
   **Diplomatic Focus**.
3. Se non può permettersi il costo, ripesca. Se non può Engage in nessuna Regione → **Trade**.
4. **L'Automa non mette mai Engage token sulla Main board.**

### Trade
- Guadagna **5 money per ogni simbolo Export** in fondo alle sue Country alleate.
- Poi pesca una **Decision card**: se nella riga dell'Automa è elencato un altro giocatore
  (umano o Automa), commercia con lui: dà a quel giocatore **10 money** dalla riserva e
  **5 money** dalla riserva all'Automa. Se il destinatario è un giocatore reale, gira una sua
  Commerce card come al solito; se tutte le sue Commerce card sono già girate, lo scambio
  non avviene.

### Invest
1. Pesca una **Auto-Influence card** → Regione. Se non ha Country alleate lì, o non può più
   investire lì (vedi sotto), ripesca.
2. Non investe in una Country specifica: paga sempre **15 money** e mette un **FDI token**
   sotto la colonna delle Country alleate di quella Regione.
3. Max FDI per Regione = **1 + numero di Country alleate** di quella Regione. Se finisse con
   più FDI che Country alleate, non può investire lì → ripesca.
4. Se ha già investito il massimo in **tutte** le Regioni → esegue **Improve Relations**.
   Se non può investire per mancanza di money → **Trade**.

### Move
- Sposta **1 Armata** dalla riserva alla Main board pagando il costo (**5 money**).
- Dove piazzarla (dall'alto in basso; a parità, a caso):
  1. Una Regione **nella sua zona di interesse** in cui è **sotto minaccia**. Se più Regioni,
     scegli quella con la **minima differenza** tra THREAT e Difesa.
  2. Una Regione **nella sua zona di interesse** dove metterà **almeno un altro giocatore
     sotto minaccia** (che ora non lo è). Se più Regioni, scegli quella dove un altro
     giocatore ha più [Armate] dell'Automa. Se nessuna, quella dove il **maggior numero**
     di giocatori va sotto minaccia.
  3. Una Regione **fuori** dalla sua zona di interesse, se possibile, dove il maggior numero
     di giocatori va sotto minaccia.
  4. Una Regione **a caso** dove può muovere.
- "Sotto minaccia" in una Regione della tua zona di interesse = un altro giocatore ha più
  THREAT della tua Difesa.
- Se ha **meno di 5 money** (non può muovere) → **Trade**.

### Build a Base
- Criteri per la Regione (come Move: minaccia in zona → metti altri sotto minaccia in zona →
  fuori zona → a caso). Non considerare Regioni dove non ha Country alleate che permettano
  una Base, o dove non può più costruire (vedi sotto).
- Non costruisce in una Country specifica: muove **1 Armata** dalla riserva nella Regione,
  paga **10 money** totali, e mette un **Military Base token** sotto la colonna delle Country
  alleate di quella Regione.
- Max Basi per Regione = **1 + numero di Country alleate** di quella Regione che permettono
  all'Automa di costruirvi una Base.
- `HARD`: dopo aver scelto la Regione, pesca una Auto-Influence card; se mostra il simbolo
  Armata sulla riga dell'Automa, muove **1 Armata aggiuntiva** nella Regione (pagando 5).
- Se non può costruire in **nessuna** Regione (max Basi ovunque) → **Improve Relations**
  (ma scegli la Regione/Country a caso tra quelle dove può costruire una Base, non con
  Auto-Influence). Se non può per mancanza di money, o non c'è Country adatta → **Trade**.

### Get a Growth Card
- Converti il costo delle Growth card disponibili del Livello opportuno in money:
  - Energia: 5 each · Materie/Cibo/(simboli intermedi): 10 each · CG/Serv/Dipl: 3 each ·
    qualsiasi altro simbolo: 15 each. *(mappare i simboli esatti in fase di implementazione)*
- Se può permettersi entrambe le carte → ne sceglie una a caso. Se solo una → quella.
  Se nessuna → guadagna **30 money**.
- Quando prende una Growth card, NON ottiene abilità, solo **VP**: i VP della carta **+** VP
  pari al **Livello** della carta (1 per Liv.1, 2 per Liv.2, …). Es. Tactical Flexibility (Liv.3,
  6 VP) → 6 + 3 = **9 VP**.

### Research Step
- Rivela **2 carte** dal mazzo dell'Automa e dagli le risorse [money] elencate nelle sezioni
  Bonus delle carte (se altri simboli, usa i valori della conversione di Get a Growth Card).
- A fine round **2 e 4**, le 2 carte rivelate nel Research devono essere le **ultime 2** del
  mazzo (vedi "Playing Cards From the Market"); quando capita, **rimischia subito le 12
  carte** e riforma il mazzo (prima di prendere una nuova carta).
- Poi l'Automa spende money per prendere **una carta dal Market**. Oltre al money dalle 2
  carte, guadagna **+1 money ogni 3 Country alleate**, e **+2** se ha Domestic Focus.
- Prende dal Market la carta con il **costo più alto** che può permettersi. A parità, usa la
  **Market Priority** sulla sua Player card (Diplomatic/Economic/Military/Domestic). A parità
  ancora, la carta aggiunta più di recente (più vicina al mazzo Ability).
- Se gli resta money dopo la carta, NON prende altre carte: per ogni money rimasto **scarta
  1 carta dal fondo della fila Market**.
- La carta presa va **in cima al mazzo** (sarà la prima del prossimo round).

---

## Aftermath

- **Return on Investments:** l'Automa prende **5 money per ogni FDI token**.
- **Increase Prosperity:** la Player card ha la sua Prosperity track (ogni spazio indica il
  money richiesto). Se ha il money richiesto per il prossimo spazio, lo spende e avanza,
  guadagnando i VP corrispondenti.
- **Resolve THREAT:** l'Automa riceve e applica THREAT come un giocatore reale.
- **Adding Influence:** quando aggiunge Influenza a una Regione:
  - se è disponibile **un solo** tipo di slot (permanente o temporaneo) → metti lì il cubo;
  - se sono disponibili **entrambi** → pesca una **Decision card** e guarda la sezione
    INFLUENCE per il round corrente: quadrato in alto nero → slot **permanente**; quadrato
    in basso nero → slot **temporaneo** più a sinistra.
  - L'Automa **non** aggiunge mai Influenza temporanea se così **spingerebbe fuori** una
    propria Influenza; in tal caso sceglie un'altra Regione per la stessa azione (ripesca
    Auto-Influence o riapplica i criteri ignorando quella Regione).
  - `HARD`: in quel caso aggiunge invece un'Influenza **permanente**, anche se non c'è slot
    disponibile.
- **Moving to a New Round:** quando i Production cube erano sulle caselle Round, rimuovili e
  mettili sull'Automa board nelle Action space secondo l'**Action Cube Priority** della Player
  card (1° cubo → 1ª azione in lista, 2° → 2ª, 3° → 3ª).
  - `HARD`: il 4° Production cube va anch'esso nella **1ª** Action space della lista.
- **Playing Cards From the Market:** a inizio di ogni round dopo il primo, la carta in cima al
  mazzo è quella presa dal Market il round prima. Se ha più simboli di tipo, esegue l'azione
  del tipo col **piccolo simbolo cubo**; se nessuno → tipo a caso. Dopo l'azione, **Trash**
  quella carta (non scartarla); poi pesca la carta successiva ed esegui la sua azione. Così
  l'Automa gioca **una carta in più** al primo turno del round, e il mazzo resta a **12 carte**
  (6 usate per round).
  - `HARD`: se la carta dal Market ha più simboli di tipo, l'Automa esegue **un'azione per
    ciascun simbolo**.

---

## Note importanti

- **Deciding at Random:** per decisioni non coperte da regole/priorità: 2 opzioni → assegna
  A/B; 3 opzioni → I/II/III; più opzioni → dividile in due gruppi e ripeti. Poi pesca una
  Decision card e leggi l'angolo: in basso a sinistra per 2 opzioni (lettera nella stella), in
  basso a destra per 3 (numero romano nel cerchio).
- **Trading with an Automa:** un giocatore può sempre commerciare con un Automa come con
  un giocatore reale. Si assume che l'Automa abbia sempre le risorse che vuoi importare
  secondo la tua Trade Deals card. Dai all'Automa il costo delle risorse importate e prendi
  +1 Diplomazia per import da un altro giocatore, come al solito.
- **Decision/Auto-Influence deck esauriti:** rimischia gli scarti per riformare il mazzo.
- **Con Executive Orders:** non dare carte Executive Order agli Automa; iniziano invece con
  **+3 VP**.
- **Carte interattive (Ability) della D&D:** non compatibili col solo play — escludile quando
  usi gli Automa.

## Superpower Objectives con gli Automa
- Non dare Objective card agli Automa al setup. In ogni Scoring step, pesca **2 Objective
  card** per ciascun Automa, verifica i task raggiunti e assegna i VP, poi scartale. Qualsiasi
  task che un Automa non può completare per le differenze delle sue regole (risorse sulla
  board, Produzioni aumentate, numero di carte nel mazzo, Engage token) è **considerato
  automaticamente raggiunto**.

## Normal vs Hard (riepilogo delle differenze)
- Setup: Hard mette un Production cube anche sulla casella Round **5** (4° cubo).
- Build a Base: Hard può muovere **1 Armata aggiuntiva** (Auto-Influence con simbolo Armata).
- Adding Influence: Hard aggiunge **permanente** invece di spingere fuori la propria temporanea.
- Moving to a New Round: Hard mette il **4° cubo** nella 1ª Action space.
- Playing from Market: Hard esegue **un'azione per ciascun simbolo** della carta.

---

## Mappatura al codice attuale

| Regola Automa | Stato | Dove |
|---|---|---|
| Add Auto-Influence (region/army/trade per potenza non giocata) | ✅ implementato (gioco base) | `game_phases.gd::add_auto_influence`, `auto_influence.json` |
| Money invece di risorse; Armate gratuite | ⛔ da fare | nuovo `automa.gd` |
| Scelta Focus + money per Focus | ⛔ da fare | richiede Decision deck |
| Azioni via Automa board (card type → azione) | ⛔ da fare | richiede dati Automa board |
| Improve/Engage/Invest/Move/Build/Trade/Growth (logica bot) | ⛔ da fare | nuovo `automa.gd` (riusa `actions.gd`) |
| Research/Market dell'Automa | ⛔ da fare | richiede Market Priority |
| Aftermath: RoI, Prosperity, THREAT, Adding Influence | ⛔ parziale | `scoring.gd`/`threat.gd` esistono |
| Difficoltà Hard | ⛔ da fare | flag in `automa.gd` |

## Dati dei componenti (estratti dal regolamento)

Dalle illustrazioni del regolamento (pag. 4) ho ricavato i componenti **universali** e
l'esempio della Player card USA:

### Automa board (universale)
- Focus spaces (money = round × moltiplicatore): **Domestic ×10**, **Diplomatic ×5**,
  **Military ×3** (+ bonus di Focus descritti nella Preparazione).
- Righe azione (sinistra | destra):
  - **Diplomatic** → Engage | Improve Relations
  - **Economic** → Invest | Trade
  - **Military** → Build a Base | Move

### Automa Player card — USA (esempio completo dal regolamento)
- **Starting money:** 50
- **Market Priority:** Military → Economic → Diplomatic → Domestic
- **Action Cube Priority:** Build a Base → Engage → Invest
- **Prosperity track** (money → VP): 10→2, 15→3, 25→4, 35→5, 45→8
- *(Starting Country: dalla Player card USA — da confermare sull'immagine della carta.)*

### Decision card — formato (con 1 esempio dal regolamento)
- Colonne **POWER | FOCUS | TRADE**: per ogni potenza, il Focus che sceglierà e il
  giocatore con cui commercia. Esempio: USA→Military/EU, EU→Diplomatic/Russia,
  Russia→Military/China, China→Domestic/Russia.
- Sezione **INFLUENCE** (round 1–6): per round, quadrato in alto nero = permanente,
  quadrato in basso nero = temporaneo.
- Angoli: **stella A/B** (random a 2 opzioni), **cerchio I/II/III** (random a 3 opzioni).

## Dati ancora necessari per implementare i bot

Restano da raccogliere (NON nel regolamento, stanno sui componenti fisici dell'espansione —
servono foto/scansioni o trascrizione):

1. **Automa Player card per EU, Russia, China** — money iniziale, Market Priority, Action
   Cube Priority, Prosperity track, Starting Country (ho già completa la **USA**).
2. **Mazzo Decision completo** — tutte le carte del Decision deck (Focus/Trade/Influence
   per round + valori random A/B e I/II/III). Ho solo **1 carta** d'esempio.
3. **Mappa simboli→costo** per Get a Growth Card / Research (conversione esatta dei simboli,
   solo parzialmente indicata nel testo).

> Con questi dati posso aggiungere `game/data/automa_board.json` (già noto),
> `automa_players.json` (USA pronta), `automa_decision.json` e un motore `automa.gd`
> testabile in headless, riusando `actions.gd`/`scoring.gd`/`threat.gd`.

## Piano di implementazione proposto (a fasi)

1. **Dati**: aggiungere `automa_board.json`, `automa_decision.json`, `automa_players.json`
   (dai componenti dell'espansione).
2. **Motore** `engine/automa.gd` (puro, testabile): stato Automa (money, Country alleate,
   FDI/Base, cubi azione, Focus), e funzioni per Preparazione / un turno d'Azione / Research /
   Aftermath, riusando `actions.gd`, `scoring.gd`, `threat.gd`.
3. **Integrazione** nel flusso di `board_view.gd`: turni Automa automatici, rendering dei loro
   segnalini, log delle loro azioni.
4. **Difficoltà** Normal/Hard e **modalità solo** (1–3 Automa) dal menu.
5. **Test** headless per ogni decisione (come per il resto del motore).
