# World Order — Design del multiplayer (LAN, host-authoritative)

> Stato: **bozza di design** per la rete. La Fase 0a (serializzazione + redazione)
> è già in `main` (v0.7.75). Questo documento descrive il pezzo successivo — il
> **command bus** — e il quadro completo fino al gioco in LAN.

## 1. Scelte fatte (con l'utente)

| Decisione | Scelta | Conseguenza |
|---|---|---|
| Topologia | **Host-giocatore** (un giocatore fa da arbitro) | Niente server di gioco nel cloud |
| Ambito iniziale | **Solo LAN** | Niente relay/NAT: l'host è raggiungibile per IP locale |
| Trasporto | **WebSocket** (`WebSocketMultiplayerPeer`) | Funziona per client nativi **e** browser; stesso codice riusabile per Internet (basterà aggiungere un relay) |
| Modello di autorità | **Host-authoritative** | L'host possiede l'unico `GameState`, valida e ribroadcasta lo stato **redatto** |

L'host-authoritative non è negoziabile per via dell'**informazione nascosta** (le mani):
mai inviare lo stato completo ai client, solo `state_for_seat()`.

## 2. Architettura a tre livelli

```
   ┌─────────────────────────────┐
   │  VISTA  (board_view.gd)     │  raccoglie input, DISEGNA lo stato redatto
   └──────────────┬──────────────┘
                  │ emette COMANDI (non muta più gs direttamente)
   ┌──────────────▼──────────────┐
   │  COMMAND BUS (nuovo)        │  apply(ctx, seat, cmd) -> esito
   │  + SessionContext           │  ospita awaiting/playing_card/trade/produce
   └──────────────┬──────────────┘
                  │ chiama il motore (validazione regole)
   ┌──────────────▼──────────────┐
   │  MOTORE  (Actions, Phases,  │  pura logica su GameState  ✓ già separato
   │  EffectExecutor, Scoring…)  │
   └──────────────┬──────────────┘
   ┌──────────────▼──────────────┐
   │  STATO  (GameState)         │  serializzabile  ✓ già fatto (v0.7.75)
   └─────────────────────────────┘
```

Oggi la **Vista** muta `gs` direttamente (chiama il motore sparso nei suoi handler).
Il command bus introduce **un unico punto** attraverso cui passa ogni input di gioco.
Lo stesso `apply()` gira:
- in **hot-seat**: chiamato localmente (nessuna rete);
- in **rete**: chiamato **solo sull'host**, su comandi ricevuti dai client.

## 3. Principio del command bus

1. La Vista, in risposta a un input, **costruisce un comando** (un Dictionary serializzabile)
   e lo passa al bus invece di mutare lo stato.
2. Il bus **valida** (seggio di turno, fase, legalità via motore) e **applica**.
3. Dopo l'applicazione, per ogni seggio si calcola `gs.state_for_seat(seat)` e si **ridisegna**
   (in locale) o si **invia** (in rete).

In hot-seat i punti 2–3 sono immediati; in rete diventano messaggi (§7).

## 4. Catalogo dei comandi

Ricavato dai veri entry-point di `board_view.gd` e dalla macchina a stati `awaiting`
(`region`, `move`, `convert_influence`, `reset_influence`, `board_country`,
`influence_cell`, `allied_country`).

### 4.1 Preparazione
| Comando | Args | Oggi in | Note |
|---|---|---|---|
| `choose_focus` | `{focus}` | `_do_focus(f)` | round 1 = auto Domestic |

### 4.2 Azione (turno del giocatore attivo)
| Comando | Args | Oggi in |
|---|---|---|
| `play_card` | `{card_id}` | `_play_card(card)` |
| `play_strategic_asset` | `{asset_id, facedown_card_id}` | token asset in mano |
| `pass_turn` | `{}` (+10 money) | token money in mano |
| `produce` | `{levels:{res:qty}, armies_delta}` | `_produce_confirm()` |
| `trade` | `{from_seller, sells:[...], products:[...]}` | `_trade_confirm()` |
| `buy_growth` | `{card_id, level}` | `_buy_growth_action()` |
| `buy_market` | `{card_id}` | `_buy_market()` |
| `exhaust_ally` | `{country_id}` | `_on_exhaust_toggle()` |
| `use_ongoing` | `{tag}` | `_use_ongoing()` |
| `end_turn` | `{}` | `_end_turn()` |

### 4.3 Sotto-scelte (risolvono un `awaiting`, dentro la risoluzione di una carta/azione)
| Comando | Args | Oggi in | awaiting |
|---|---|---|---|
| `pick_region` | `{region}` | `_on_region_pressed()` | `region` |
| `pick_board_country` | `{country_id}` | `_on_allied_pressed()` | `board_country` |
| `pick_allied_country` | `{country_id}` | `_on_allied_pressed()` | `allied_country` |
| `pick_influence_cell` | `{region, slot_type, index}` | clic cella | `influence_cell` |
| `move_army` | `{from, to, count}` | `_region_do_drop()` | `move` |
| `convert_influence` | `{region}` | `_on_region_pressed()` | `convert_influence` |
| `reset_influence` | `{region}` | `_on_region_pressed()` | `reset_influence` |
| `pick_hand_card` | `{card_id}` | `_pick_hand_card()` cb | (discard/trash) |

### 4.4 Aftermath (per ogni giocatore, in parte simultaneo)
| Comando | Args | Oggi in |
|---|---|---|
| `aftermath_token` | `{kind:"money"\|"defense", region}` | `_aftermath_token_*()` |
| `aftermath_prosperity` | `{}` | `_aftermath_prosperity()` |
| `aftermath_continue` | `{}` | `_aftermath_continue()` |

> Le aperture di pannello puramente locali (`_open_trade_ui`, cambio linguetta board,
> zoom/pan mappa, collassare la mano) **non** sono comandi: sono stato di sola Vista.

## 5. Formato del comando

```gdscript
{
  "type": "play_card",   # vedi catalogo
  "seat": 2,             # seggio mittente (indice in turn_order/players)
  "seq":  17,            # progressivo per-seggio: ordina e rende idempotente
  "args": { "card_id": "ability_trade_deal_3" }
}
```

- `seq` consente all'host di **scartare duplicati** e ordinare; il client lo incrementa.
- Tutti gli `args` sono **id stabili** (mai riferimenti a oggetti vivi): card_id, country_id,
  region, indici. Questo li rende serializzabili e validabili lato host.

## 6. Validazione, gating e RNG

- **Gating**: l'host accetta un comando solo se `seat` è il `active_seat` (turno) — eccezione
  per le fasi **simultanee** (Aftermath/Preparazione), dove ogni seggio agisce sui propri pezzi.
- **Legalità**: il motore valida già (risorse, slot influenza, costi Engage, ecc.). Comando
  illegale → **NACK** al mittente, **nessuna** mutazione.
- **RNG centralizzato**: pescate, shuffle e Market li fa **solo l'host**. I client non
  riproducono casualità: ricevono i risultati nello snapshot. Niente seed condivisi, niente
  desync. (Già oggi il motore usa `RandomNumberGenerator` lato logica.)
- **Anti-cheat**: validazione lato host + redazione = un client non può vedere né alterare
  l'informazione nascosta. Sufficiente anche oltre la LAN.

## 7. Flusso dei messaggi (host-authoritative)

```
CLIENT (seggio s)                         HOST (arbitro)
   │  submit_command(cmd) ───────────────▶ │
   │                                       │  valida (gating + motore)
   │                                       │  applica a GameState
   │                                       │  per ogni seggio k: state_for_seat(k)
   │  ◀──────────── apply_snapshot(view_s) │  (broadcast mirato)
   │  _refresh() dallo stato redatto        │
```

- **v1**: dopo ogni comando l'host invia lo **snapshot redatto completo** a ciascun client
  (semplice, robusto; una partita è piccola). 
- **Ottimizzazione futura**: inviare **eventi/delta** invece dello snapshot intero.
- **Pending input**: lo stato redatto includerà un campo che descrive *cosa* l'host attende
  dal seggio attivo (es. `{await:"influence_cell", regioni:[...]}`), così il client sa quali
  elementi evidenziare — è la versione "in chiaro" dell'attuale `awaiting`.

## 8. Dove vive la macchina a stati `awaiting`

Oggi `awaiting`, `playing_card`, `play_queue`, lo stato temporaneo di trade/produce vivono nel
**nodo Vista** (`board_view.gd`). Per la rete devono vivere **sull'host** (sono autorità).

→ Si estrae un **`SessionContext`** (oggetto puro, non-nodo) che contiene: `gs` + lo stato di
interazione in corso. Il command bus opera su `SessionContext`. In hot-seat la Vista ne possiede
una; in rete la possiede l'host, e la Vista del client tiene solo lo **stato redatto** + il
**pending input**.

## 9. Piano di refactor incrementale (a rischio controllato)

1. **Step A — Bus locale (hot-seat).** Creare `GameCommands.apply(ctx, cmd)` spostandoci la
   logica già presente in board_view. La Vista diventa "sottile": input → `cmd` → `apply` →
   `_refresh`. **Nessuna rete.** Test: una partita hot-seat completa pilotata da soli comandi.
2. **Step B — SessionContext.** Spostare `awaiting`/`playing_card`/trade/produce dal nodo Vista
   al contesto. Aggiungere `pending_input` allo stato redatto.
3. **Step C — Trasporto (Fase 1).** `WebSocketMultiplayerPeer`: host in ascolto, client per IP;
   lobby con codice stanza / auto-discovery UDP; assegnazione potenze.
4. **Step D — Sincronizzazione (Fase 2).** `submit_command` (client→host), `apply_snapshot`
   (host→client), gating per turno/fase.
5. **Step E — Robustezza (Fase 3).** Riconnessione/resync, AFK/timeout, disconnessioni.

Gli Step A–B sono **testabili in hot-seat** e non introducono dipendenze di rete: stessa
strategia "a rischio zero" usata per la serializzazione.

## 10. Fuori scope per la v1
Spettatori, ripresa di partite salvate, sostituzione con bot dei disconnessi, matchmaking online.
Tutti compatibili con questa architettura ma rimandati.

## 11. Stato di avanzamento
- [x] **Fase 0a** — serializzazione `GameState`/`PlayerState`/`InfluenceTrack` + `state_for_seat` (v0.7.75, +9 test)
- [ ] **Fase 0b** — command bus locale (Step A–B)
- [ ] **Fase 1** — trasporto + lobby (Step C)
- [ ] **Fase 2** — sincronizzazione (Step D)
- [ ] **Fase 3** — robustezza (Step E)
