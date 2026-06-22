# World Order — Stato (TODO) · regole ↔ meccanica

Legenda: 🟢 fatto · 🟡 fatto ma da correggere/raffinare · 🔴 mancante

Confronto tra il **regolamento** (`Rules.pdf`, 24 pp.) e la **meccanica** implementata
(`game/scripts/engine/` + UI `board_view.gd`). Il motore ha **95 test headless verdi**
che riproducono molti esempi numerici del manuale (vedi `game/RULES_COVERAGE.md`).

---

## 📌 Audit regole↔meccanica (handoff 2026-06-21 → fix 2026-06-22)

Stato deploy: **v0.7.30** su `main`. Test: `verify_ui` OK, engine **124/0**.
Rulebook: `/Tabelle_Materiali/World Order/Rules.pdf` (24 pp.).

> ### ✅ FATTO 2026-06-22 (verificato sul regolamento + test)
> Risolte 11 discrepanze **engine/scoring** (le rules-breaking), con test che le bloccano
> (23 nuovi test → engine 124/0; `verify_ui` 15/15 stabile):
> - **#1** Abilità speciali ora applicate nello scoring REALE: USA (Global Superpower
>   Status, ogni scoring step) · Russia (Secured Sphere, ogni scoring step) · China
>   (Global FDI Network, fine partita). Agganciate sia nel motore sia nella UI.
> - **#2** Executive Order: +3 VP se NON usata (campo `executive_order_used`).
> - **#3** +2 VP per ogni Strategic Asset NON usato a fine partita.
> - **#4** Spareggio vincitore corretto: 1° bonus Maggioranza → più cubi Influenza →
>   vittoria condivisa (`GameRunner.winners`).
> - **#8** NATO non più hardcoded: `Threat.nato_pairs` valida le potenze in gioco.
> - **#14** Trade: il bene da 20 è **Armate** (Diplomazia non commerciabile).
> - **#15** Improve Relations: rispetta `no_relations_powers`.
> - **#16** Engage: richiede ≥1 Country alleata nella Regione.
> - **#17** Invest / Build a Base: una sola volta per Country.
> - **#18** Move: destinazione solo in zona di interesse o dove si ha una Base.
> - **#19** Build a Base: la UI fa scegliere quante Armate muovere (fino al valore
>   del Country), non 1 fissa (`_pick_base_armies`).
> - **#20** Produce: la Diplomazia in eccesso (>10) va **persa**, non in money.
> - **#21** Trade: +1 Diplomazia SOLO comprando da un altro giocatore (non dalla banca).
>
> ### ⏳ DA FARE
> Resta: #13 (spareggio ordine turno con starting money, bassa).
> Più i 🔵 da playtest (Focus in Preparation) e:
> - **Trade: drag&drop** vero (trascinare i token) — iterazione 2, sopra al tap.
> - **Trade: vendita Armate** dalla riserva (20 cad., non sulla resource track) — #14
>   lato vendita-riserva, non ancora nella UI Commercio.
> - **Commerce cards: composizione per-carta** da confermare (ora ogni carta = tutti i
>   prodotti della potenza; se EU/Russia hanno carte "splittate" è solo da editare il
>   dato `commerce_cards` in `data/trade_deals.json`).
>
> ### ✅ FATTO 2026-06-22 (7° giro — carte prodotto multiple)
> - Ogni potenza ha ora **2 carte prodotto (3 la Russia)**, mostrate tutte nel cassetto;
>   quelle usate nel round appaiono **girate/grigie**.
> - Comprando un prodotto da una potenza si **gira la carta specifica** che lo mostra:
>   così può venderlo **una volta per carta scoperta** (prima: una sola volta in assoluto).
>   Il cap d'import dalla potenza = sue carte scoperte che mostrano quel prodotto.
> - Auto-Influence (#10) gira una qualunque sua carta scoperta per i 10 money.
>
> ### ✅ FATTO 2026-06-22 (6° giro — Commercio sulla resource track)
> - Nuovo Commercio: niente più tabella di testo. Ogni risorsa ha la sua **track 0-10**;
>   tocchi una **casella valida** (entro i cap) → verso 0 **vendi**, verso 10 **compri**,
>   col **denaro guadagnato/speso** scritto su ogni casella.
> - **Scelta del venditore via BANDIERINA**: a fianco di ogni risorsa le sorgenti d'import
>   (🏦 banca + bandiere delle potenze che la vendono); clicchi quella da cui comprare e
>   il cap si adatta alla sua offerta. La logica (cap, P2P, +1 Diplomazia) è invariata.
>   Il **drag&drop** vero arriverà come iterazione 2.
>
> ### ✅ FATTO 2026-06-22 (5° giro — Auto-Influence completo)
> - **#9** ora si applicano **2 carte Auto-Influence per round** (non 1).
> - **#10** il money del commercio (10) è **condizionato**: la potenza neutrale lo dà
>   a un giocatore solo se quel giocatore ha una **Commerce card a faccia in su**,
>   che viene girata; se sono tutte girate, niente money (`_flip_one_commerce`).
> - Le piazzazioni di Influenza/Armate di entrambe le carte sono elencate nel
>   riepilogo di fine round (🔵 Auto-Influence a video, di base).
>
> ### ✅ FATTO 2026-06-22 (4° giro — Aftermath interattivo)
> - **#7** Increase Prosperity ora è una **scelta** (bottone), non più automatica.
> - **#6** scarto Engage token → **+5 money × Country** alleate della Regione (ROI).
> - **#5** scarto Engage token → **+2 Difesa × Country** alleate, applicata al THREAT.
> - L'Aftermath è ora una sequenza di popup per giocatore (scelte) + risoluzione
>   THREAT/Scoring. Quota FDI del ROI resta automatica.
>
> ### ✅ FATTO 2026-06-22 (2° giro — Market/Research)
> - **Schermata Research/Market leggibile** (bug playtest): carte dimensionate per stare
>   in riga senza accavallarsi, Growth in orizzontale, pannello scrollabile/adattato.
> - **#11** Market: comprando ne compare una nuova a sinistra; opzione −2 Research per
>   scartare le 3 a destra; scarto di fine Research (2/1/0 per 2/3/4 giocatori).
> - **#12 FATTO**: nel Research puoi esaurire le Country alleate ready per aggiungere
>   **il loro valore** ai punti Research (il Research di una Country = il suo `value`,
>   confermato dall'esempio del regolamento: Singapore 2 + Tajikistan 1 = 3).

### 🔴 Discrepanze rispetto al regolamento (dettaglio originale dell'audit)

Audit regolamento↔codice completo (3 aree: azioni, setup/fasi, aftermath/scoring).

#### Aftermath / Scoring / Fine partita — CRITICHE
1. **Abilità speciali potenze MAI applicate** (pag. 20). `global_superpower_status_penalty` / `secured_sphere_vp` / `global_fdi_network_vp` esistono in `aftermath.gd` ma sono chiamate **solo dai test**: nello scoring reale (`board_view._run_aftermath`, `_game_end`, `game_runner.score_majority_tokens`) non vengono mai invocate. → USA non paga mai la penalità (−12/−8/−5/−2 Regioni), Russia non prende +2/zona con più Armate, Cina non prende i VP per Regioni con FDI.
2. **Executive Orders non implementati** (pag. 21). `executive_orders.json` ha `once_per_game` + `unused_bonus_vp:3`, ma nessun codice li gioca né assegna i **+3 VP se non usati** a fine partita.
3. **+2 VP per ogni Strategic Asset NON usato** mai assegnati a fine partita (pag. 21 + FAQ pag. 22). `_game_end` somma solo i token Maggioranza.
4. **Spareggio vincitore errato** (pag. 21). `game_runner.winner` rompe i pari per **ordine di inserimento**; dovrebbe essere: chi ha preso il **1° bonus Maggioranza** → poi **più cubi Influenza sul tabellone** → poi **vittoria condivisa**.
5. **Resolve THREAT: scarto Engage token per +2 Difesa/Country alleata** non collegato (pag. 19). `board_view:3015` passa `{}` a `Threat.resolve_region`.
6. **Return on Investments: scarto Engage token per 5 money/Country alleata** non collegato (pag. 19). `board_view:2997` passa `[]` a `Aftermath.return_on_investments`.
7. **Increase Prosperity forzata** invece che a scelta (pag. 19): il codice la applica in automatico a tutti se possono permettersela; dovrebbe essere opzionale.
8. **NATO** hardcoded `[["usa","eu"]]` (pag. 19): non validato contro le potenze effettivamente in gioco.

#### Setup / Preparation / Round — CRITICHE/ALTE
9. **Auto-Influence: applicata UNA carta invece di DUE** (pag. 18). `_apply_auto_influence` usa una sola carta; il regolamento ne tiene 2 rivelate e ne pesca 2 nuove. → circa metà di Influenza/Armate/money neutrali in meno (incide su scoring e maggioranze nei giochi 2–3 giocatori).
10. **Auto-Influence: money commercio incondizionato** (pag. 18). `game_phases.add_auto_influence` dà +10 money senza controllare/girare una **Commerce card a faccia in su**.
11. **Research: manca lo scarto/ricambio del Market** (pag. 17): dopo il Research va scartata la carta **più a destra** (1 a 3 giocatori, **2** a 2 giocatori); manca anche l'opzione "spendi 2 Research per scartare le 3 più a destra".
12. **Research: le Country alleate non possono aggiungere Research** (pag. 17). `buy_market_card` ha il parametro `extra_from_countries` ma la UI non lo usa mai.
13. _(Bassa)_ **Spareggio ordine di turno**: a setup usa la money *corrente* invece della *starting money* (pag. 9 punto 19). Per i round 2+ la money corrente è corretta (pag. 11).

#### Le 8 Azioni — CRITICHE/ALTE
14. **Trade: il bene di valore 20 è ARMATE, non Diplomazia** (pag. 13). `EXPORT_GAIN` mappa il 20 su `"diplomacy"` ed esclude le Armate; la Diplomazia **non** è commerciabile. Mancante anche la vendita di Armate (solo dalla plancia, 20 cad., non importabili). UI Trade (`TRADE_RES`) esclude le Armate.
15. **Improve Relations: restrizione "potenza vietata" non applicata** (pag. 12). I Country hanno `no_relations_powers` ma non viene mai usato (es. USA non può allearsi con l'Iran).
16. **Engage: manca il prerequisito** "almeno 1 Country alleata nella Regione" (pag. 13). `execute_engage` non lo controlla.
17. **Invest / Build a Base: limite "una volta per Country" non applicato** (pag. 14/15). Bloccano solo su `exhausted`; con un `ready_country` si può investire/costruire di nuovo sullo stesso Paese. `fdi_countries`/`bases` non usati come guardia.
18. **Move / Build a Base: nessun vincolo zona d'interesse / Base** sulle destinazioni del Move (pag. 14). `_move_valid_dest` non controlla `zone_of_interest` né le `bases`: per un Move generico ogni Regione è valida.
19. **Build a Base: la UI sposta sempre 1 Armata** (pag. 15). `_on_allied_pressed` chiama `execute_build_base(..., 1, ...)` fisso; non si può muovere (né pagare) fino al valore del Country.
20. **Produce: la Diplomazia in eccesso (>10) diventa money invece di andare persa** (pag. 15). `execute_produce` chiama `gain_resource("diplomacy", 1, 10)` (10 money/eccesso).
21. **Trade: +1 Diplomazia dato per QUALSIASI import**, non solo comprando da altri giocatori (pag. 13). `_trade_confirm` dà +1 anche su import dalla banca/potenze neutrali. (Inoltre il path carta `effect_executor "trade"` non dà mai la Diplomazia.)

> Nota: costi/sconti di Improve Relations, Engage (incl. Diplomatic Focus −2), Move (5/Armata), formula Build-a-Base, gating Growth e la logica Influenza temporanea (FIFO/convert/reset) risultano **corretti**. Le tabelle dati delle abilità speciali in `board.json` sono giuste: il problema è che non vengono chiamate.

### 🟡 Aperti / da raffinare (UI, noti da questa sessione)
- [ ] Verificare i dati `board.json` di TUTTE le Regioni vs tabellone stampato (MENA era errata).
- [ ] Engage token: posa calibrata sul simbolo "handshake" stampato.
- [ ] FDI/Base anche sulle Country sul tabellone (non solo nel cassetto).
- [ ] Maggioranza a inizio partita (tutti pari) — valutare se nasconderla.
- [ ] UX dopo Move: cassetto resta chiuso.

### 🔵 Da playtest utente (2026-06-21)
- [ ] **Market/Research: carte ENORMI e sovrapposte, illeggibili.** Nel popup Research il Market e le Growth hanno immagini troppo grandi che coprono il testo e si accavallano. Ridimensionare/impaginare a griglia leggibile (vedi screenshot).
- [ ] **Fase di PREPARATION: manca la scelta del FOCUS e le sue azioni.** Durante la preparazione non c'è la scelta del Focus (Domestic/Diplomatic/Military) né le azioni conseguenti (ready Country + produzione del tipo del Focus). Il changelog la dava come fatta (v0.7.12/0.7.19): verificare se è regredita o non è esposta nel flusso UI.
- [ ] **Fase di AFTERMATH troppo automatizzata + manca l'Increase Prosperity.** La fase conseguenze è tutta automatica; va resa interattiva dove il regolamento prevede scelte, e in particolare **manca l'incremento di Prosperità** (collegare ↔ audit punto 7: Increase Prosperity deve essere una scelta del giocatore, non forzata).
- [ ] **Mancano le carte Auto-Influence delle potenze NON giocanti** (a video). Le potenze neutrali non mostrano/applicano l'Auto-Influence (collegare ↔ audit punti 9–10: vanno 2 carte per round, money commercio condizionato).
- [ ] **Carte "prodotto" delle potenze: sono PIÙ DI UNA.** Russia = **3**, EU / USA / Cina = **2** ciascuna. La UI Commercio ne mostra una sola per potenza: mostrarle tutte (ognuna coi suoi simboli Export/Import).
- [ ] **Commercio (Trade) da rifare: spostando i PRODOTTI sulla board, non con una tabella di testo.** Sostituire il popup tabellare con un'interazione drag/posa dei prodotti sul tabellone.

---

## 🟢 Fatto (regole verificate dai test)

- **Influenza**: slot permanenti/temporanei, push FIFO, Reset, Convert (`influence_track.gd`).
- **Scoring Regione**: VP/cubo + maggioranze + spareggi + cubi locali (`scoring.gd`), esempio MENA del manuale.
- **THREAT / Defense**: Armate, Military Focus, Engage, NATO (`threat.gd`), esempi 1–2.
- **Le 8 azioni** (costi + effetti), **tutte giocabili e risolte sul tabellone** dal flusso UI: Improve Relations, Engage, Trade, Invest, Move, Build a Base, Get a Growth Card, Produce (`actions.gd` + `board_view._advance_play`).
- 🟢 **Trade interattivo**: popup per scegliere Export/Import per risorsa, **cap dai simboli Export/Import delle nazioni amiche** + import dagli altri giocatori (Trade Deals `import_from`), **limite 2/3 transazioni**, una risorsa per transazione. Export → money, Import → spende money, **+1 Diplomazia** comprando dagli altri. Δ money in tempo reale (`board_view._open_trade_ui`).
- **Produzione** primaria/secondaria + cap 10 → money; **Prosperità** (CG → VP+money) (`game_phases.gd`).
- **Macchina fasi/round** (3 fasi × 6 round), **Research/Market** (bonus, +2 Domestic, acquisto), **Add Auto-Influence** (2–3 giocatori).
- **Aftermath**: Return on Investments, 3 token Maggioranza + spareggi + regola 2 giocatori (esempi pag. 19/21 riprodotti).
- **Abilità speciali** potenze (Global Superpower Status, ecc.) (`aftermath.gd`).
- **Effetti carte** come `effect_ops` (~97 carte, 0 op sconosciute) (`effect_executor.gd`).
- **Setup da dati** + simulazione end‑to‑end (partita a 4 fino al vincitore) (`game_runner.gd`).

### Setup iniziale (regolamento pag. 8–9) — verificato sulle plance reali
- 🟢 Produzione iniziale corretta per ogni potenza.
- 🟢 **Risorse iniziali = Produzione** (pag. 13: "each one equal to its starting Production").
- 🟢 **Armate iniziali = Produzione di Armate** (pag. 13): ogni potenza parte con Armate in riserva pari alla sua Produzione di Armate (test di setup incluso).
- 🟢 **Focus iniziale = Domestic** (pag. 9).
- 🟢 **Nazioni amiche iniziali** complete (4–5 per potenza, pag. 9 punto 14).
- 🟢 Mazzo iniziale 12 carte (doppioni inclusi).
- 🟢 **Ordine di turno** = più VP per primo (spareggio: meno money), regolamento pag. 9.
- 🟢 **Strategic Asset**: pesca 3 dei 5, ne tiene 2, **VP iniziali = somma** (pag. 9 punto 17). *(Auto: tiene i 2 con più VP; la scelta manuale arriverà col flusso interattivo.)* **Ora attivabili in partita** giocando una carta a faccia in giù (una volta ciascuno); mostrati nel cassetto.
- 🟢 **Gioco a faccia in giù**: toccando una carta scegli azione normale / +10 money / attiva uno Strategic Asset (la carta di mano è il costo).

### UI / presentazione
- 🟢 Mappa con **zoom + trascinamento**; carte nazione (immagini originali) negli **slot designati** (coordinate dal salvataggio TTS).
- 🟢 Plance reali con **cubi produzione / token risorsa / segnalini** calibrati sull'immagine (3 colonne).
- 🟢 **Mano** con carte reali, **flyover** (hover ingrandisce), **collassabile**.
- 🟢 **Market/Growth** illustrate; **linguette potenze con bandiere** su barra dedicata.
- 🟢 Splash con **versione + changelog**; scaling adattivo (no plancia gigante su desktop).

---

## 🟡 Fatto ma da correggere / raffinare

- 🟢 **Calibrazione fine segnalini** (2026-06-21): ricalibrate tutte le costanti plancia dai template utente (`game/assets/calibration/plance/`) e validate a video sulle 4 plance reali. Template→potenza: 0=USA, 1=China, 2=Russia, 3=EU. Layout condiviso, con `raw_materials` x per-potenza (`RAW_MATERIALS_X`). Riserva carri (`RESERVE_ARMY_POS`) invariata. Errore di fit ≤ ~1px.
- 🟢 **Abilità `ongoing`**: tutte agganciate — *extra_draw_per_round* (+1 pesca/round), *extra_play_first_turn* (+1 carta al 1° turno del round), *ready_extra_on_focus* (+1 Country preparata col Focus) e le 4 *once_per_round* (draw+trash, draw highest+discard, improve again +1, convert influence). **Modificatori condizionali di Trade agganciati**: *count Energy ×2* / *count Energy or Raw ×2* (raddoppiano i simboli Export — es. Energy Titan) e *Influenza solo se hai esportato Beni/Servizi (o 4 Energia)*. Restano da rifinire alcuni modifier rari su Strategic Asset (repeat/optional spend).
- 🟢 **Turno = 1 azione**: ogni turno giochi 1 carta **oppure** fai la **Focus action** (sposta il Focus e prepara 2 Country card, +1 con *ready_extra_on_focus*). 4 turni/round.
- 🟢 **Focus (passi)**: la Focus action prepara le Country card (numero per‑Focus: Domestic 1, Diplomatic 4, Military 2, +1 con *ready_extra_on_focus*) **e produce** il tipo del Focus (Domestic→Beni/Servizi, Diplomatic→Diplomazia, Military→Armate in riserva). Bonus chiave già attivi (Engage −2, +2 Research, +1 THREAT/Defense). Resta opzionale lo step "spendi 8 money per +1 Produzione".
- 🟡 **Turno guidato dalla UI**: le azioni si fanno, ma manca un flusso hot‑seat completo che guidi tutte le scelte di un turno.
- 🟡 **Mano**: ora pesca 6 da un mazzo di 12; il regolamento divide 12 in 2 pile da 6 (esito equivalente).

---

## 🔴 Mancante

- 🟢 **Trade tra giocatori**: importando da un altro giocatore, lui **incassa il money** e **+1 Servizio** (bonus di vendita) e la sua **Commerce card si gira** (riusabile solo dal round dopo); il compratore prende la risorsa +1 Diplomazia. Cap d'import dagli altri = `import_from` della Trade Deals card.
- 🟢 **Auto‑Influence** delle potenze non giocate: con meno di 4 giocatori, ogni Aftermath pesca una carta Auto‑Influence e le potenze neutrali piazzano Influenza/Armate (contano per scoring e maggioranze). La carta è mostrata nel riepilogo di fine round.
- 🔴 **Modalità Online** (placeholder nel menu).
- 🔴 **Avversari / bot (AI)**: ora è hot‑seat manuale.
- 🔴 **Comfort**: salvataggio/caricamento partita, annullo robusto, suoni, animazioni.

---

## Prossimi passi suggeriti (priorità)
1. ~~Ordine di turno~~ ✓ · ~~Strategic Asset in setup~~ ✓ · ~~abilità `ongoing`~~ ✓ · ~~Trade inter‑giocatore~~ ✓
2. Flusso turno guidato dalla UI (hot‑seat completo) + eventuale bot.
3. `effect_modifiers` condizionali rimanenti (es. *count Energy ×2*) e *Produce X* nei passi di Focus.
4. Armate iniziali = produzione (con aggiornamento dei 2 test).
