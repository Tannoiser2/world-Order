# Multiplayer: LAN (app native) e Internet (relay)

Ci sono **due modi** di giocare in rete:

- **LAN** — tra **app native** (PC/Mac/Android) sulla **stessa rete Wi-Fi/LAN**. Diretto, nessun
  server esterno. Dal browser **non** si può (una pagina web non fa da server e una pagina HTTPS
  non si collega a un `ws://`).
- **Internet (relay `wss://`)** — funziona **anche da browser/telefono** e **fuori dalla LAN**.
  Host e client si collegano tutti a un piccolo server relay; ci si trova con un **codice stanza**.
  Richiede di aver messo online il relay una volta (vedi `relay/README.md`).

## Come ottenere le app

Le build native si generano da GitHub Actions:

1. Vai su **Actions → "Build native apps (LAN multiplayer)"**.
2. Premi **Run workflow** (oppure pubblica un tag `v*`).
3. A fine run scarica gli **artifacts**:
   - `world-order-desktop` → eseguibili **Linux** (`world-order.x86_64`) e **Windows** (`world-order.exe`). ✅ **Disponibile.**
   - `world-order-macos` → **`world-order.zip`** (dentro c'è `world-order.app`), build **universale** Intel + Apple Silicon (M1/M2/M3). ✅ **Disponibile.**
   - `world-order-android` → **`world-order.apk`** (Android). ✅ **Disponibile.** APK firmata con **debug keystore** (per uso personale va bene; Android può chiedere di consentire l'installazione da "origini sconosciute").

> Gli eseguibili Linux/Windows hanno il `.pck` incorporato: un singolo file da lanciare.

## macOS — primo avvio (importante)

L'app `.app` **non è firmata né notarizzata** (è una build personale via CI), quindi al primo avvio macOS la blocca come "di sviluppatore non identificato". Per sbloccarla, una volta sola:

1. Scarica `world-order-macos`, **scompatta** lo `.zip` → ottieni `world-order.app`.
2. Apri il **Terminale** nella cartella dove sta l'app ed esegui:
   ```sh
   xattr -dr com.apple.quarantine world-order.app
   ```
   In alternativa: **click destro** sull'app → **Apri** → confermi **Apri** nel dialogo.
3. Da lì in poi si avvia con un doppio clic come una normale app.

> Se vuoi una build firmata/notarizzata (apertura senza passaggi extra) serve un account Apple Developer: si può aggiungere più avanti.

## Come giocare in LAN

1. Tutti i dispositivi sulla **stessa rete locale**.
2. Su un dispositivo (PC o telefono): **Online → Ospita (LAN)**. Compare il suo **IP**.
3. Sugli altri: **Online → Unisciti**, inserendo quell'**IP**.
4. Quando tutti sono collegati, l'host preme **Avvia partita**.

La porta usata è la **8910** (TCP/WebSocket): se un firewall la blocca, sbloccala sull'host.

## Come giocare via Internet (relay)

Prerequisito: il relay deve essere **online** (deploy una tantum, istruzioni in `relay/README.md`).
Ottieni un URL tipo `wss://tuo-relay.onrender.com`.

1. Nella lobby (**Online**), incolla l'URL nel campo **«URL relay»** (viene ricordato).
2. L'host preme **«Ospita (Internet)»** → compare un **codice stanza** (es. `Z3AC`). Lo condivide.
3. Gli altri inseriscono lo **stesso URL** + il **codice** e premono **«Entra (Internet)»**.
4. Quando ci sono abbastanza giocatori, l'host preme **Avvia partita**.

Funziona anche **da browser** (il sito web): a differenza della LAN, dal browser **si può**
ospitare, perché il relay è una connessione in uscita e non un server locale.

## Come funziona (entrambe le modalità)

L'host fa da **arbitro** (possiede lo stato) e invia a ciascuno solo la propria mano; gli altri
inviano le mosse all'host. In LAN i client si collegano direttamente all'host; via relay tutti si
collegano al relay, che smista i messaggi (senza leggerne il contenuto). Il codice di rete è in
`game/scripts/net/net_session.gd` (`host_lan`/`join_lan` per la LAN, `host_relay`/`join_relay`
per il relay).

## Note

- **Android può ospitare** (è un'app nativa): un telefono fa da host e un altro telefono/PC si unisce.
- Se "Ospita (LAN)" dà errore su PC dopo vari tentativi, chiudi e riapri (la porta si libera subito
  quando lasci la lobby).
- Relay su **free tier** (es. Render): dopo un po' di inattività il server si "addormenta"; la prima
  connessione può metterci ~30s a svegliarlo.
