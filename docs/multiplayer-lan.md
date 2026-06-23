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
