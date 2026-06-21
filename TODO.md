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
- **Produzione** primaria/secondaria + cap 10 → money; **Prosperità** (CG → VP+money) (`game_phases.gd`).
- **Macchina fasi/round** (3 fasi × 6 round), **Research/Market** (bonus, +2 Domestic, acquisto), **Add Auto-Influence** (2–3 giocatori).
- **Aftermath**: Return on Investments, 3 token Maggioranza + spareggi + regola 2 giocatori (esempi pag. 19/21 riprodotti).
- **Abilità speciali** potenze (Global Superpower Status, ecc.) (`aftermath.gd`).
- **Effetti carte** come `effect_ops` (~97 carte, 0 op sconosciute) (`effect_executor.gd`).
- **Setup da dati** + simulazione end‑to‑end (partita a 4 fino al vincitore) (`game_runner.gd`).

### Setup iniziale (regolamento pag. 8–9) — verificato sulle plance reali
- 🟢 Produzione iniziale corretta per ogni potenza.
- 🟢 **Risorse iniziali = Produzione** (pag. 13: "each one equal to its starting Production").
- 🟡 **Armate iniziali = Produzione di Armate** (pag. 13): correzione pronta ma rompe 2 test che assumevano Armate=0 (engage discount, growth produce) → da applicare insieme all'aggiornamento dei test.
- 🟢 **Focus iniziale = Domestic** (pag. 9).
- 🟢 **Nazioni amiche iniziali** complete (4–5 per potenza, pag. 9 punto 14).
- 🟢 Mazzo iniziale 12 carte (doppioni inclusi).
- 🟢 **Ordine di turno** = più VP per primo (spareggio: meno money), regolamento pag. 9.
- 🟢 **Strategic Asset**: pesca 3 dei 5, ne tiene 2, **VP iniziali = somma** (pag. 9 punto 17). *(Auto: tiene i 2 con più VP; la scelta manuale arriverà col flusso interattivo.)*

### UI / presentazione
- 🟢 Mappa con **zoom + trascinamento**; carte nazione (immagini originali) negli **slot designati** (coordinate dal salvataggio TTS).
- 🟢 Plance reali con **cubi produzione / token risorsa / segnalini** calibrati sull'immagine (3 colonne).
- 🟢 **Mano** con carte reali, **flyover** (hover ingrandisce), **collassabile**.
- 🟢 **Market/Growth** illustrate; **linguette potenze con bandiere** su barra dedicata.
- 🟢 Splash con **versione + changelog**; scaling adattivo (no plancia gigante su desktop).

---

## 🟡 Fatto ma da correggere / raffinare

- 🟡 **Calibrazione fine segnalini**: produzione ora centrata; prosperità/risorse buone — restano ritocchi al pixel su feedback.
- 🟡 **`effect_modifiers` e abilità `ongoing`**: codificate nei dati ma non tutte agganciate al flusso interattivo (es. *count Energy ×2*, pesca extra/round, once‑per‑round, money↔Servizi nel costo Growth).
- 🟡 **Focus (passi)**: *Ready N Country cards* e *Produce X* nei passi di Focus (i bonus chiave — Engage −2, +2 Research, +1 THREAT/Defense — sono attivi).
- 🟡 **Turno guidato dalla UI**: le azioni si fanno, ma manca un flusso hot‑seat completo che guidi tutte le scelte di un turno.
- 🟡 **Mano**: ora pesca 6 da un mazzo di 12; il regolamento divide 12 in 2 pile da 6 (esito equivalente).

---

## 🔴 Mancante

- 🔴 **Trade tra giocatori** con Commerce cards (export/import inter‑player + 1 Services di bonus): tabelle e Trade Deals in `data/`, manca l'orchestrazione.
- 🔴 **Auto‑Influence** completo per le potenze non giocate (parziale).
- 🔴 **Modalità Online** (placeholder nel menu).
- 🔴 **Avversari / bot (AI)**: ora è hot‑seat manuale.
- 🔴 **Comfort**: salvataggio/caricamento partita, annullo robusto, suoni, animazioni.

---

## Prossimi passi suggeriti (priorità)
1. ~~Ordine di turno~~ ✓ · ~~Strategic Asset in setup~~ ✓
2. Agganciare `effect_modifiers` / abilità `ongoing` al flusso del round.
3. **Trade inter‑giocatore** (Commerce cards).
4. Flusso turno guidato dalla UI (hot‑seat completo) + eventuale bot.
5. Armate iniziali = produzione (con aggiornamento dei 2 test).
