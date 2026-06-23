# Relay `wss://` per World Order

Piccolo server che permette di giocare **da browser/telefono** e **via Internet** (non solo in LAN).

## Perché serve

Il multiplayer è *host-authoritative*: un giocatore fa da **host** (arbitro) e gli altri da **client**.
In LAN l'host apre una porta e i client si collegano direttamente. Ma:

- dal **browser** non si può fare da server (una pagina web non apre porte);
- una pagina **HTTPS** non può collegarsi a un host **`ws://`** in chiaro (mixed content).

Con questo relay, **host e client si collegano tutti in uscita** allo stesso server **`wss://`**
(sicuro, quindi ok anche da pagina HTTPS), e il relay smista i messaggi tra loro. L'host resta
l'arbitro: il relay **non guarda dentro** i messaggi di gioco, li inoltra e basta.

## Come funziona (stanze a codice)

1. L'host preme **«Ospita (Internet)»** → il relay crea una **stanza** e restituisce un **codice** (es. `BJ6X`).
2. L'host condivide il codice; gli altri inseriscono URL + codice e premono **«Entra (Internet)»**.
3. Quando ci sono abbastanza giocatori, l'host preme **«Avvia partita»**. Fine: nessun vincolo di rete.

## Provarlo in locale

```sh
cd relay
npm install
npm start            # in ascolto su ws://localhost:8080
npm test             # test del protocollo (host/client, errori, host uscito)
```

Nel gioco, come URL relay metti `ws://localhost:8080` (in locale; in produzione sarà `wss://…`).

## Deploy (per giocare davvero su Internet)

Serve un URL pubblico con **HTTPS/WSS**. Il relay tiene lo stato in memoria, quindi gira su **una
sola istanza** (va benissimo per partite tra amici).

### Opzione A — Render (consigliata, free)

1. Vai su [render.com](https://render.com) → **New +** → **Blueprint** → collega questo repo.
2. Render legge [`render.yaml`](../render.yaml) (nella radice del repo), builda la cartella `relay/` e avvia il server.
3. Ottieni un URL tipo `https://world-order-relay.onrender.com`.
4. Nel gioco usa la versione **`wss://`**: `wss://world-order-relay.onrender.com`.

> Nota free tier: dopo ~15 min di inattività il servizio si "addormenta"; la prima connessione
> può metterci ~30s a svegliarlo. Per partite occasionali è accettabile.

### Opzione B — Fly.io

```sh
cd relay
fly launch --no-deploy --copy-config   # usa fly.toml + Dockerfile
fly deploy
```

Ottieni `https://<app>.fly.dev` → nel gioco usa `wss://<app>.fly.dev`.

### Opzione C — qualsiasi host Node

Esegui `node server.js` dietro un reverse proxy con TLS (Caddy/Nginx) che inoltra il WebSocket.
Il server ascolta su `$PORT` (default 8080) e risponde `200` su `GET /` (health-check).

## Dove si incolla l'URL nel gioco

Nel menù **Online**, nella lobby, campo **«URL relay»**. Viene **ricordato** per le volte successive.
In alternativa puoi impostarlo come default in `game/scripts/ui/main_menu.gd` (costante `RELAY_URL_DEFAULT`).

## Protocollo (sintesi)

Tutti i frame sono **testo JSON**. Il payload di gioco (`d`) è una *variant* Godot serializzata in
base64: il relay non la interpreta.

| Da → a | Messaggio |
|---|---|
| game → relay | `{"t":"hello","role":"host"\|"client","room":"CODE"}` (room vuota = generala il relay) |
| game → relay | `{"t":"to","id":<dest>,"d":"<b64>"}` · `{"t":"all","d":"<b64>"}` · `{"t":"ping"}` |
| relay → game | `{"t":"welcome","id":<id>,"room":"CODE"}` (id 1 = host) · `{"t":"error","code":…}` |
| relay → host | `{"t":"join","id":<id>}` · `{"t":"leave","id":<id>}` |
| relay → client | `{"t":"host_gone"}` |
| relay → game | `{"t":"from","id":<src>,"d":"<b64>"}` (src 1 = host) |

Lato gioco è implementato in `game/scripts/net/net_session.gd` (`host_relay` / `join_relay`).
