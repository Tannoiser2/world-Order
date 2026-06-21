# World Order — Stato (TODO) · regole ↔ meccanica

Legenda: 🟢 fatto · 🟡 fatto ma da correggere/raffinare · 🔴 mancante

Confronto tra il **regolamento** (`Rules.pdf`, 24 pp.) e la **meccanica** implementata
(`game/scripts/engine/` + UI `board_view.gd`). Il motore ha **95 test headless verdi**
che riproducono molti esempi numerici del manuale (vedi `game/RULES_COVERAGE.md`).

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

- 🟡 **Calibrazione fine segnalini**: produzione ora centrata; prosperità/risorse buone — restano ritocchi al pixel su feedback.
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
