# Copertura delle regole — motore World Order

Stato dell'implementazione del regolamento nel motore (`scripts/engine/`).
**95 test** headless verdi (Godot 4.3), molti riproducono gli esempi numerici del manuale.

## ✅ Implementato e testato

| Area | Modulo | Note / verifica |
|------|--------|-----------------|
| Influenza: slot perm./temp., push FIFO | `influence_track.gd` | Europe 5-4-3-2 |
| Influenza: Reset, Convert temp→perm | `influence_track.gd` | spostamento/scorrimento cubi |
| Scoring Regione: VP/cubo + maggioranze + spareggi + cubi locali | `scoring.gd` | esempio MENA (USA 14, Russia 10, EU 7, China 1) |
| THREAT/Defense: Armate, Military Focus, Engage, NATO | `threat.gd` | esempi 1 e 2 |
| Le 8 azioni (costi + effetti) | `actions.gd` | Improve Relations, Engage, Trade, Invest, Move, Build a Base, Get Growth, Produce |
| Produzione primaria/secondaria + cap 10→money | `actions.gd`, `game_phases.gd` | requisiti secondarie |
| Prosperità | `game_phases.gd` | costo CG → VP+money |
| Ordine di turno (meno VP per primo) | `game_phases.gd` | — |
| Macchina fasi/round (3 fasi × 6 round) | `game_phases.gd` | advance_phase |
| Research/Market (bonus, +2 Domestic, acquisto) | `game_phases.gd` | — |
| Add Auto-Influence (2-3 giocatori) | `game_phases.gd` | Influenza/Armata + trade flag |
| Aftermath: Return on Investments | `aftermath.gd` | esempio pag. 19 (20 money) |
| Aftermath: 3 token Maggioranza + spareggi + regola 2p | `aftermath.gd` | esempio pag. 21 (riprodotto esatto) |
| Abilità speciali potenze | `aftermath.gd` | Global Superpower Status, Secured Sphere, Global FDI Network |
| Effetti carte come `effect_ops` (97 carte) | `effect_executor.gd` + dati | 0 op sconosciute |
| Sconti condizionali delle carte (`effect_modifiers`) | `modifiers.gd` | Improve −N, Engage −1/Armata, −1/alleato, −1 in certe Regioni, money↔Servizi/Diplomazia |
| Setup partita da dati | `game_setup.gd` | cubi iniziali, Engage MENA=6 |
| Simulazione end-to-end (6 round → vincitore) | `game_runner.gd` | partita a 4 completa |

### Agganciato al flusso interattivo (UI, `scripts/ui/board_view.gd`)

| Area | Note |
|------|------|
| Selezione Country sul tabellone | 2 disponibili/Regione (Improve Relations) + alleati davanti al giocatore (Invest/Build a Base) |
| Fase Research/Market di fine round | reveal mano → top bonus + Research (+2 Domestic), acquisto carte Market e Growth (in ordine di livello) |
| `effect_modifiers` applicati alla carta giocata | sconti su Engage/Improve Relations calcolati a runtime via `modifiers.gd` |
| Plancia di produzione della potenza | immagine reale come fondale del pannello + tracciato Prosperità con segnalino |

## 🚧 Modellato ma da raffinare (nuance)

Codificati nei dati come `effect_modifiers` / op `ongoing`, da applicare automaticamente
durante il flusso di gioco interattivo (richiedono il turno completo guidato da UI/bot):

- **Sconti/bonus condizionali residui**: gli sconti su Engage/Improve Relations sono attivi
  (`modifiers.gd`); restano da agganciare i condizionali sull'Influenza (*count Energy ×2*,
  *aggiungi Influenza se hai esportato …*) e il pagamento money↔Servizi nel costo delle Growth.
- **Abilità continuative** (Growth): **agganciate** — *pesca extra/round*, *gioca una carta in più
  al primo turno*, *prepara 1 Country in più col Focus*, e le 4 *once-per-round*. Restano gli
  `effect_modifiers` condizionali sull'Influenza (*count Energy ×2*).
- **Trade tra giocatori** (Commerce card): **fatto** — importando da un altro giocatore lui incassa il
  money e +1 Servizio, e la sua Commerce card si gira (1×/round); cap d'import = `import_from`.
- **Improve Relations su Country già alleato** (stacking + 1 Influenza) e ricerca Country sul board.
- **Focus**: *Ready N Country cards* **fatto** (Focus = azione del turno); resta *Produce X* nei passi di
  Focus (i bonus chiave — Engage −2, +2 Research, +1 THREAT/Defense — sono già attivi).

## ▶️ Prossimi passi suggeriti

1. Fase 2 — UI hot-seat che guida le scelte (target di azioni, Focus, acquisti Market).
2. `effect_modifiers` condizionali rimanenti e *Produce X* nei passi di Focus.
3. Armate iniziali = produzione; eventuale bot/AI.
