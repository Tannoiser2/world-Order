# Audit delle carte: implementazione e multiplayer

Audit richiesto: tutte le carte (in particolare quelle **multi-azione** e con **scelte multiple**)
sono implementate? Funzionano in multiplayer?

**Esito: sì, con UNA eccezione nota** (il modulo opzionale *Executive Orders*, non ancora
implementato). Dettagli sotto.

## Cosa sono le "carte" (dati)

Le carte giocabili con effetti (`effect_ops`) sono **135**:

| File | N. | Tipo |
|---|---|---|
| `market_cards.json` | 33 | Carte Market (Ability) |
| `abilities/*_starting.json` | 48 | Ability iniziali (12 × 4 potenze) |
| `strategic_assets.json` | 20 | Strategic Asset |
| `auto_influence.json` | 20 | Auto-Influence (potenze neutrali) |
| `growth_cards.json` | 10 | Growth |
| `trade_deals.json` | 4 | Trade Deals |

> `cards_manifest.json` (253 voci) **non** sono carte di gioco: è il manifest delle IMMAGINI
> (slicing degli sheet), senza `effect_ops`. Non rientra nell'audit degli effetti.

Di queste 135: **51 carte multi-azione** (più di un op) e **20 carte con scelta** (`choice`/`choose_n`).

## Op usate e implementazione

Le carte usano **35 op distinte**. TUTTE sono riconosciute dal motore
(`EffectExecutor.KNOWN`) e gestite dal flusso interattivo (`board_view._advance_play`):
nessuna op sconosciuta in nessun file dati.

| Op | Risoluzione | Multiplayer (comando sincronizzato) |
|---|---|---|
| `improve_relations` | scelta Country sul tabellone + sconto | `pick_board_country`, `exhaust_confirm/skip` |
| `engage`, `place_armies` | scelta Regione + sconto | `pick_region`, `exhaust_confirm/skip` |
| `invest`, `build_base` | scelta Country alleata + slot Influenza | `pick_allied_country`, `pick_influence_cell` |
| `move`, `move_free`, `move_to_regions` | spostamento Armate (tap/drag) | `move_army`, `move_finish` |
| `trade` | composizione Export/Import sulla plancia | `trade` |
| `produce` | track sulla plancia (limite tipi = `count`) | `produce` |
| `get_growth` | scelta Growth card | `buy_growth`, `growth_skip` |
| `add_influence` | scelta casella Influenza | `pick_influence_cell` |
| `choice`, `choose_n` | popup di scelta | `popup_choice` |
| `increase_production` | popup tipo risorsa | `popup_choice` |
| `trash`, `discard` | popup carta in mano | `popup_choice` |
| `spend_for_gain`, `research_free` | popup | `popup_choice` |
| `reset_influence`, `convert_influence` | scelta Regione | `pick_region` |
| `ready_country`, `increase_prosperity`, `repeat`, `spend_then` | automatiche (host) | applicate dall'host |
| `gain_money`, `gain_resource`, `gain_armies`, `gain_vp`, `draw`, `spend`, `noop`, `ongoing`, `play_another`, `gain_money_per_fdi`, `sell_armies` | automatiche (host) | `EffectExecutor.run` sull'host |

## Perché funzionano in multiplayer (architettura)

Il sistema è **host-authoritative** e ogni scelta interattiva passa per il **command bus**:

1. Giocare una carta è un comando (`play_card`): la risoluzione degli op gira sull'**host**.
2. Gli op **automatici** si applicano direttamente sull'host (`EffectExecutor.run`), poi lo
   stato redatto viene ribroadcastato a ogni client.
3. Gli op **interattivi** mettono l'host in attesa e raccolgono la scelta del giocatore di turno
   tramite un comando sincronizzato (vedi tabella). La callback non serializzabile resta
   sull'host; il client manda solo l'INDICE/target scelto.
4. Le **carte multi-azione** risolvono gli op in sequenza (`play_queue`); le **scelte** aprono un
   popup sincronizzato e i sub-op scelti vengono anteposti alla coda — anche concatenando una
   seconda azione interattiva.

## Copertura dei test (rete)

25 test d'integrazione in rete (host↔client, loopback), tra cui:
`verify_net_popup` (scelte a popup, anche concatenate), `verify_net_trade` /
`verify_net_trade_money`, `verify_net_move`/`board`, `verify_net_improve[1-3]`,
`verify_net_growth`, `verify_net_research`, `verify_net_aftermath`, `verify_net_4p_flow`
(4 giocatori), `verify_net_acting_guard` (azioni solo a chi agisce), e il nuovo
**`verify_net_choice_card`**: il client gioca una carta a scelta multipla ("Growth Strategy")
che **concatena** una seconda azione interattiva (Produce) — popup → scelta → Produce con
limite di tipi sincronizzato → comando produce → risoluzione su entrambe le finestre.

## Executive Orders (implementato in v0.7.127)

Il modulo **Executive Orders** e' ora implementato. Le 4 carte (una per potenza) sono modellate
come una **scelta a 8 opzioni** (`executive_orders.json` -> `effect_ops`): Improve Relations /
Engage / Trade / Invest / (Gain 1 Army + Move 2) / Build a Base / Get a Growth / Produce 3 tipi.
Una volta per partita, al posto di una carta, il giocatore usa l'Executive Order (bottone "Usa
Executive Order") e sceglie un'azione; consuma una giocata. Se non usata vale +3 VP a fine partita
(gia' nello scoring). E' multiplayer-safe: nuovo comando `use_executive_order` + la scelta passa
per `popup_choice`. Test: `verify_executive_order`, `verify_net_executive_order`.

## Conclusione

Tutte le 135 carte di gioco (incluse multi-azione e a scelta multipla) **e il modulo Executive
Orders** sono **implementate** e **funzionano in multiplayer** grazie all'architettura
host-authoritative + command bus.
