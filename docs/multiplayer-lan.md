# Multiplayer in LAN (app native)

Il multiplayer in rete locale funziona **tra app native** (PC e/o Android) sulla
**stessa rete Wi-Fi/LAN**. **Dal browser non si può** (una pagina web non può fare da
server, e una pagina HTTPS non può collegarsi a un host `ws://`): per il browser/telefono
servirà in futuro un relay `wss://`.

## Come ottenere le app

Le build native si generano da GitHub Actions:

1. Vai su **Actions → "Build native apps (LAN multiplayer)"**.
2. Premi **Run workflow** (oppure pubblica un tag `v*`).
3. A fine run scarica gli **artifacts**:
   - `world-order-desktop` → eseguibili **Linux** (`world-order.x86_64`) e **Windows** (`world-order.exe`).
   - `world-order-android` → **`world-order.apk`** (Android).

> Gli eseguibili hanno il `.pck` incorporato: un singolo file da lanciare.
> L'APK è firmato con una **debug keystore** (va bene per uso personale; Android può
> chiedere di consentire l'installazione da "origini sconosciute").

## Come giocare

1. Tutti i dispositivi sulla **stessa rete locale**.
2. Su un dispositivo (PC o telefono): **Online (LAN) → Ospita (LAN)**. Compare il suo **IP**.
3. Sugli altri: **Online (LAN) → Unisciti**, inserendo quell'**IP**.
4. Quando tutti sono collegati, l'host preme **Avvia partita**.

L'host fa da **arbitro** (possiede lo stato) e invia a ciascuno solo la propria mano; gli
altri inviano le mosse all'host. La porta usata è la **8910** (TCP/WebSocket): se un firewall
la blocca, sbloccala sull'host.

## Note

- **Android può ospitare** (è un'app nativa): un telefono fa da host e un altro telefono/PC
  si unisce.
- Se "Ospita" dà errore su PC dopo vari tentativi, chiudi e riapri (la porta si libera subito
  quando lasci la lobby).
- macOS: non incluso negli export automatici (richiede firma/notarizzazione). Si può
  esportare a mano dall'editor se serve.
