// Test del relay: host + client via WebSocket reali su una porta effimera.
import { test, afterEach } from "node:test";
import assert from "node:assert/strict";
import { WebSocket } from "ws";
import { createRelay } from "../server.js";

// Risorse aperte dal test corrente, chiuse in afterEach: senza questo i socket
// restano aperti e il processo non termina (test "appesi").
let relay = null;
const conns = [];

// Avvia il relay su una porta random e ritorna {url}.
function startRelay() {
  return new Promise((resolve) => {
    const { httpServer, wss } = createRelay();
    httpServer.listen(0, () => {
      const { port } = httpServer.address();
      relay = { httpServer, wss };
      resolve({ url: `ws://127.0.0.1:${port}` });
    });
  });
}

// Apre una connessione e raccoglie i messaggi; next() attende il prossimo.
function connect(url) {
  const ws = new WebSocket(url);
  conns.push(ws);
  const queue = [];
  const waiters = [];
  ws.on("message", (data) => {
    const msg = JSON.parse(data.toString());
    if (waiters.length) waiters.shift()(msg);
    else queue.push(msg);
  });
  const ready = new Promise((res, rej) => {
    ws.on("open", res);
    ws.on("error", rej);
  });
  return {
    ws,
    ready,
    send: (obj) => ws.send(JSON.stringify(obj)),
    next: () =>
      new Promise((res) => {
        if (queue.length) res(queue.shift());
        else waiters.push(res);
      }),
  };
}

afterEach(async () => {
  for (const ws of conns) {
    try { ws.terminate(); } catch { /* gia' chiuso */ }
  }
  conns.length = 0;
  if (relay) {
    relay.wss.close();
    relay.httpServer.closeAllConnections?.();
    await new Promise((r) => relay.httpServer.close(r));
    relay = null;
  }
});

test("flusso completo: host genera stanza, client entra, messaggi in entrambi i versi", async () => {
  const { url } = await startRelay();
  const host = connect(url);
  await host.ready;
  host.send({ t: "hello", role: "host", room: "" });
  const hw = await host.next();
  assert.equal(hw.t, "welcome");
  assert.equal(hw.id, 1);
  assert.match(hw.room, /^[A-Z0-9]{4}$/);
  const code = hw.room;

  const client = connect(url);
  await client.ready;
  client.send({ t: "hello", role: "client", room: code });
  const cw = await client.next();
  assert.equal(cw.t, "welcome");
  assert.equal(cw.id, 2);
  assert.equal(cw.room, code);

  // l'host viene avvisato del nuovo client
  assert.deepEqual(await host.next(), { t: "join", id: 2 });

  // client -> host
  client.send({ t: "to", id: 1, d: "CMD" });
  assert.deepEqual(await host.next(), { t: "from", id: 2, d: "CMD" });

  // host -> client specifico
  host.send({ t: "to", id: 2, d: "SNAP" });
  assert.deepEqual(await client.next(), { t: "from", id: 1, d: "SNAP" });

  // host -> broadcast
  host.send({ t: "all", d: "START" });
  assert.deepEqual(await client.next(), { t: "from", id: 1, d: "START" });

  // uscita del client -> l'host riceve leave
  client.ws.close();
  assert.deepEqual(await host.next(), { t: "leave", id: 2 });
});

test("errori: stanza inesistente e codice gia' in uso", async () => {
  const { url } = await startRelay();

  // client su stanza che non esiste
  const c = connect(url);
  await c.ready;
  c.send({ t: "hello", role: "client", room: "ZZZZ" });
  assert.equal((await c.next()).code, "no_room");

  // due host sullo stesso codice
  const h1 = connect(url);
  await h1.ready;
  h1.send({ t: "hello", role: "host", room: "ROOM" });
  assert.equal((await h1.next()).room, "ROOM");

  const h2 = connect(url);
  await h2.ready;
  h2.send({ t: "hello", role: "host", room: "ROOM" });
  assert.equal((await h2.next()).code, "room_taken");
});

test("se l'host se ne va, i client ricevono host_gone", async () => {
  const { url } = await startRelay();
  const host = connect(url);
  await host.ready;
  host.send({ t: "hello", role: "host", room: "GONE" });
  await host.next();

  const client = connect(url);
  await client.ready;
  client.send({ t: "hello", role: "client", room: "GONE" });
  await client.next(); // welcome
  await host.next();    // join

  host.ws.close();
  assert.deepEqual(await client.next(), { t: "host_gone" });
});
