// Relay wss:// per il multiplayer host-authoritative di World Order.
//
// PERCHE': dal browser non si puo' fare da server (e una pagina HTTPS non puo'
// collegarsi a un host "ws://"). Con questo relay, SIA l'host SIA i client si
// collegano in USCITA allo stesso server "wss://" e il relay smista i messaggi.
// Cosi' si gioca da browser/telefono e via Internet, non solo in LAN.
//
// MODELLO: l'host resta l'arbitro (id 1). Il relay NON guarda dentro i messaggi
// di gioco (campo "d", una variant Godot in base64): inoltra e basta.
//
// PROTOCOLLO (tutti i frame sono testo JSON):
//   game -> relay
//     {"t":"hello","role":"host","room":"","name":"..."}  // room "" = generala tu
//     {"t":"hello","role":"client","room":"ABCD"}
//     {"t":"to","id":<dest>,"d":"<b64>"}   // host->client (id client) o client->host (id 1)
//     {"t":"all","d":"<b64>"}              // solo host: a tutti i client
//     {"t":"ping"}                          // keepalive applicativo -> {"t":"pong"}
//   relay -> game
//     {"t":"welcome","id":<id>,"room":"ABCD"}   // id 1 = host
//     {"t":"error","code":"...","msg":"..."}
//     {"t":"join","id":<id>}   // all'host: nuovo client
//     {"t":"leave","id":<id>}  // all'host: client uscito
//     {"t":"host_gone"}        // ai client: l'host se n'e' andato
//     {"t":"from","id":<src>,"d":"<b64>"}  // messaggio di gioco inoltrato (src 1 = host)

import http from "node:http";
import { WebSocketServer } from "ws";

const HOST_ID = 1;
const ROOM_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // niente 0/O/1/I
const ROOM_LEN = 4;
const MAX_CLIENTS = 7;          // host + 7 = 8 connessi per stanza
const MAX_PAYLOAD = 1 << 20;    // 1 MiB per messaggio
const HEARTBEAT_MS = 30000;     // ping ws ogni 30s, chiude i morti

/** code -> { host, clients: Map<id, ws>, nextId } */
const rooms = new Map();

function send(ws, obj) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function sanitizeRoom(s) {
  return String(s || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 8);
}

function genRoom() {
  for (let tries = 0; tries < 50; tries++) {
    let c = "";
    for (let i = 0; i < ROOM_LEN; i++) {
      c += ROOM_ALPHABET[(Math.random() * ROOM_ALPHABET.length) | 0];
    }
    if (!rooms.has(c)) return c;
  }
  // estremamente improbabile: allunga il codice
  return genRoom() + ROOM_ALPHABET[(Math.random() * ROOM_ALPHABET.length) | 0];
}

function onHello(ws, msg) {
  if (ws.meta.room) return; // gia' in una stanza
  const role = msg.role === "host" ? "host" : "client";

  if (role === "host") {
    let code = sanitizeRoom(msg.room);
    if (code === "") {
      code = genRoom();
    } else if (rooms.has(code)) {
      return send(ws, { t: "error", code: "room_taken", msg: "Codice gia' in uso." });
    }
    rooms.set(code, { host: ws, clients: new Map(), nextId: HOST_ID + 1 });
    ws.meta = { role: "host", room: code, id: HOST_ID };
    return send(ws, { t: "welcome", id: HOST_ID, room: code });
  }

  // client
  const code = sanitizeRoom(msg.room);
  const room = rooms.get(code);
  if (!room) {
    return send(ws, { t: "error", code: "no_room", msg: "Stanza inesistente." });
  }
  if (room.clients.size >= MAX_CLIENTS) {
    return send(ws, { t: "error", code: "room_full", msg: "Stanza piena." });
  }
  const id = room.nextId++;
  room.clients.set(id, ws);
  ws.meta = { role: "client", room: code, id };
  send(ws, { t: "welcome", id, room: code });
  send(room.host, { t: "join", id });
}

function onTo(ws, msg) {
  const room = rooms.get(ws.meta.room);
  if (!room) return;
  const dest = msg.id | 0;
  if (ws.meta.role === "host") {
    // host -> un client specifico (sorgente = host)
    send(room.clients.get(dest), { t: "from", id: HOST_ID, d: msg.d });
  } else {
    // client -> host (qualunque dest dato dal client, va all'host); sorgente = client
    send(room.host, { t: "from", id: ws.meta.id, d: msg.d });
  }
}

function onAll(ws, msg) {
  if (ws.meta.role !== "host") return; // solo l'host puo' fare broadcast
  const room = rooms.get(ws.meta.room);
  if (!room) return;
  for (const c of room.clients.values()) {
    send(c, { t: "from", id: HOST_ID, d: msg.d });
  }
}

function onClose(ws) {
  const code = ws.meta && ws.meta.room;
  if (!code) return;
  const room = rooms.get(code);
  if (!room) return;
  if (ws.meta.role === "host") {
    for (const c of room.clients.values()) send(c, { t: "host_gone" });
    rooms.delete(code);
  } else {
    room.clients.delete(ws.meta.id);
    send(room.host, { t: "leave", id: ws.meta.id });
  }
}

export function createRelay() {
  const httpServer = http.createServer((req, res) => {
    // pagina/health-check (Render & co. fanno GET /)
    res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
    res.end(`World Order relay OK — stanze attive: ${rooms.size}\n`);
  });

  const wss = new WebSocketServer({ server: httpServer, maxPayload: MAX_PAYLOAD });

  wss.on("connection", (ws) => {
    ws.meta = { role: null, room: null, id: null };
    ws.isAlive = true;
    ws.on("pong", () => { ws.isAlive = true; });

    ws.on("message", (data) => {
      let msg;
      try { msg = JSON.parse(data.toString()); } catch { return; }
      switch (msg && msg.t) {
        case "hello": return onHello(ws, msg);
        case "to":    return ws.meta.room ? onTo(ws, msg) : undefined;
        case "all":   return ws.meta.room ? onAll(ws, msg) : undefined;
        case "ping":  return send(ws, { t: "pong" });
      }
    });

    ws.on("close", () => onClose(ws));
    ws.on("error", () => { /* la chiusura passa comunque da 'close' */ });
  });

  // Heartbeat: chiude le connessioni morte (proxy che droppano gli idle).
  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (ws.isAlive === false) { ws.terminate(); continue; }
      ws.isAlive = false;
      try { ws.ping(); } catch { /* ignora */ }
    }
  }, HEARTBEAT_MS);
  heartbeat.unref?.(); // non tiene vivo il processo da solo (utile ai test e all'arresto)
  wss.on("close", () => clearInterval(heartbeat));

  return { httpServer, wss, rooms };
}

// Avvio diretto (non quando importato dai test).
const isMain = process.argv[1] && import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  const port = process.env.PORT || 8080;
  const { httpServer } = createRelay();
  httpServer.listen(port, () => {
    console.log(`World Order relay in ascolto sulla porta ${port}`);
  });
}
