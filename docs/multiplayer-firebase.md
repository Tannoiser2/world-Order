# Multiplayer via Internet con Firebase

Dalla v0.7.172 «Ospita (Internet)» / «Entra (Internet)» passano dal **Realtime Database di Firebase**
(stesso progetto degli altri giochi: Ultimo chilometro, Snow Tails, STATUS; piano gratuito).
Il relay su Render resta disponibile come alternativa: basta scrivere un URL `wss://…` nel campo relay.

## Perché
Il relay gratuito su Render si addormenta dopo ~15 minuti: la prima connessione dopo una pausa
impiegava 30–60 s o falliva ("Relay irraggiungibile"). Firebase è sempre acceso e non c'è un
server da mantenere.

## Come funziona
Il modello non cambia: **l'host è l'arbitro** e a ogni giocatore arriva solo il suo stato
**redatto** (`state_for_seat`). Cambia solo il trasporto (`game/scripts/net/fb_transport.gd`):

```
worldorder/rooms/<CODICE>
  info              {host, status, created, seen}  leggibile da chi ha fatto l'accesso
  members/<uid>     {name, cn, seen}               scrive il giocatore; legge lui e l'host
  cmd/<uid>/<n>     comandi del giocatore          scrive il giocatore; legge l'host
  box/<uid>         casella PRIVATA                scrive l'host; legge solo quel giocatore
    q/<n>           welcome, lobby, start (in ordine)
    snap            ultimo stato redatto
    meta            {qn, sv}
```

- **Privacy**: le regole (`firebase/database.rules.json`) impediscono a un client di leggere la
  casella di un altro, quindi le mani restano nascoste anche sulla rete.
- **Mittente autenticato**: il seggio di un comando si ricava dall'uid nel percorso (accesso
  anonimo Firebase), non dal contenuto del messaggio — come con LAN e relay.
- **Poco traffico**: i client leggono ogni ~0,8 s solo `meta` (pochi byte) e scaricano lo stato
  solo quando cambia versione; l'host non riscrive uno stato identico (il ribroadcast di
  heartbeat del gioco non costa nulla).
- **Rientro**: chi perde la linea rientra con lo stesso codice dallo stesso dispositivo e ritrova
  il suo posto e l'ultimo stato. L'host deve restare collegato (è l'arbitro).

## Configurazione
Le regole sono in `firebase/database.rules.json` (comprendono anche gli altri giochi): vanno
pubblicate nella console Firebase (Realtime Database → Regole). L'accesso *Anonimo* in
Authentication è già attivo.

## Test
```sh
python3 game/scripts/tests/firebase_mock.py 18924 &
export WO_DB_URL=http://127.0.0.1:18924/db WO_AUTH_URL=http://127.0.0.1:18924/signup WO_REFRESH_URL=http://127.0.0.1:18924/refresh
godot --headless --path game --script res://scripts/tests/verify_firebase.gd        # trasporto + privacy
# dal menu, due istanze (host e ospite) fino al tabellone:
WO_ROLE=host  WO_SESSION=user://h.cfg WO_CODEFILE=/tmp/code godot --headless --path game --script res://scripts/tests/verify_firebase_lobby.gd &
WO_ROLE=guest WO_SESSION=user://g.cfg WO_CODEFILE=/tmp/code godot --headless --path game --script res://scripts/tests/verify_firebase_lobby.gd
```
