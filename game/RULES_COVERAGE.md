# Copertura delle regole — motore World Order

Stato dell'implementazione del regolamento nel motore (`scripts/engine/`).
**88 test** headless verdi (Godot 4.3), molti riproducono gli esempi numerici del manuale.

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
| Setup partita da dati | `game_setup.gd` | cubi iniziali, Engage MENA=6 |
| Simulazione end-to-end (6 round → vincitore) | `game_runner.gd` | partita a 4 completa |

## 🚧 Modellato ma da raffinare (nuance)

Codificati nei dati come `effect_modifiers` / op `ongoing`, da applicare automaticamente
durante il flusso di gioco interattivo (richiedono il turno completo guidato da UI/bot):

- **Sconti/bonus condizionali** delle carte (es. *Engage spendendo 1 Diplomacy in meno per Armata*,
  *Improve Relations pagando money invece di Diplomacy*, *count Energy ×2*).
- **Abilità continuative** (Growth + alcune carte): *pesca extra/round*, *gioca una carta in più al primo turno*,
  *once-per-round draw/trash*, ecc. — l'op `ongoing` le marca; vanno agganciate ai passi del round.
- **Trade tra giocatori** con Commerce card (export/import inter-player + 1 Services di bonus): le tabelle
  e i Trade Deals sono in `data/`, manca l'orchestrazione inter-giocatore.
- **Improve Relations su Country già alleato** (stacking + 1 Influenza) e ricerca Country sul board.
- **Focus**: *Ready N Country cards* e *Produce X* nei passi di Focus (i bonus chiave — Engage −2,
  +2 Research, +1 THREAT/Defense — sono già attivi).

## ▶️ Prossimi passi suggeriti

1. Applicare automaticamente gli `effect_modifiers` e le abilità `ongoing` nel flusso del round.
2. Trade inter-giocatore con Commerce card.
3. Fase 2 — UI hot-seat che guida le scelte (target di azioni, Focus, acquisti Market).
