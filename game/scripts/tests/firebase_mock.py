#!/usr/bin/env python3
"""Finto Firebase (Realtime Database REST + accesso anonimo) per provare il gioco online in locale.

Uso:  python3 tests/firebase_mock.py 8765
Poi avviare Godot con
  WO_DB_URL=http://127.0.0.1:8765/db
  WO_AUTH_URL=http://127.0.0.1:8765/signup
  WO_REFRESH_URL=http://127.0.0.1:8765/refresh

Applica una versione semplificata delle regole di firebase/database.rules.json:
stanza creata una volta sola, posti occupabili solo se liberi (o dal proprio titolare o dall'host),
casella privata di ogni giocatore leggibile solo da lui, comandi scrivibili solo dal mittente.
Le stanze di World Order stanno sotto worldorder/rooms.
"""
import gzip
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

TREE = {}
TOKENS = {}
LOCK = threading.Lock()
COUNT = [0]


def resolve(value):
    if isinstance(value, dict):
        if value.get(".sv") == "timestamp":
            return int(time.time() * 1000)
        return {k: resolve(v) for k, v in value.items()}
    return value


def get_node(path):
    node = TREE
    for p in path:
        if not isinstance(node, dict) or p not in node:
            return None
        node = node[p]
    return node


def set_node(path, value):
    if not path:
        raise ValueError("radice")
    node = TREE
    for p in path[:-1]:
        node = node.setdefault(p, {})
    if value is None:
        node.pop(path[-1], None)
    else:
        node[path[-1]] = value


def firebase_json(v):
    """Come Firebase: oggetti con chiavi numeriche dense diventano array."""
    if isinstance(v, dict):
        conv = {k: firebase_json(x) for k, x in v.items()}
        if conv and all(k.isdigit() for k in conv):
            mx = max(int(k) for k in conv)
            if len(conv) * 2 > mx + 1:
                return [conv.get(str(i)) for i in range(mx + 1)]
        return conv
    return v


def allowed(uid, path, new, new_host=None, reading=False):
    """Regole semplificate di firebase/database.rules.json per worldorder/rooms."""
    if path[:2] != ["worldorder", "rooms"] or len(path) < 3:
        return False
    code = path[2]
    info = get_node(["worldorder", "rooms", code, "info"]) or {}
    host = info.get("host") or new_host
    rest = path[3:]
    if not rest:
        return (not reading) and new is not None and host == uid  # creazione (patch multipla) / aggiornamenti host
    key = rest[0]
    if key == "info":
        if reading:
            return True
        if len(rest) == 1:
            return (not info and isinstance(new, dict) and new.get("host") == uid) or info.get("host") == uid
        return info.get("host") == uid
    if key == "members":
        if len(rest) == 1:
            return reading and host == uid
        return rest[1] == uid or (reading and host == uid)
    if key == "cmd":
        if len(rest) < 2:
            return False
        return (rest[1] == uid and not reading) or (reading and host == uid)
    if key == "box":
        if len(rest) < 2:
            return False
        return (reading and rest[1] == uid) or (not reading and host == uid)
    return False


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        gz = "gzip" in (self.headers.get("Accept-Encoding") or "")
        if gz:  # come i server di Google: risposta compressa se il client la accetta
            body = gzip.compress(body)
        self.send_response(code)
        self._cors()
        if gz:
            self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _cors(self):
        # come Firebase: risposte leggibili da qualunque pagina web
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, POST, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Expose-Headers", "*")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _body(self):
        n = int(self.headers.get("Content-Length", 0) or 0)
        return self.rfile.read(n).decode() if n else ""

    def _db(self, method):
        u = urlparse(self.path)
        if not u.path.startswith("/db/") or not u.path.endswith(".json"):
            return self._send(404, {"error": "not found"})
        path = [p for p in u.path[4:-5].split("/") if p]
        uid = TOKENS.get(parse_qs(u.query).get("auth", [""])[0])
        if uid is None:
            return self._send(401, {"error": "Permission denied"})
        with LOCK:
            if method == "GET":
                if not allowed(uid, path, None, reading=True):
                    return self._send(401, {"error": "Permission denied"})
                return self._send(200, firebase_json(get_node(path)))
            if method == "DELETE":
                if not allowed(uid, path, None):
                    return self._send(401, {"error": "Permission denied"})
                set_node(path, None)
                return self._send(200, None)
            data = resolve(json.loads(self._body() or "null"))
            if method == "PUT":
                if not allowed(uid, path, data):
                    return self._send(401, {"error": "Permission denied"})
                set_node(path, data)
                return self._send(200, data)
            if method == "PATCH":
                # aggiornamento a più percorsi: ogni chiave si controlla da sola, tutto o niente
                items = [(path + [p for p in k.split("/") if p], v) for k, v in data.items()]
                new_host = (data.get("info") or {}).get("host") if len(path) == 3 and isinstance(data.get("info"), dict) else None
                for p, v in items:
                    if not allowed(uid, p, v, new_host):
                        return self._send(401, {"error": "Permission denied"})
                for p, v in items:
                    set_node(p, v)
                return self._send(200, data)
        self._send(405, {"error": "method"})

    def do_GET(self):
        self._db("GET")

    def do_PUT(self):
        self._db("PUT")

    def do_PATCH(self):
        self._db("PATCH")

    def do_DELETE(self):
        self._db("DELETE")

    def do_POST(self):
        u = urlparse(self.path)
        body = self._body()
        with LOCK:
            COUNT[0] += 1
            n = COUNT[0]
        if u.path == "/signup":
            tok = "tok%d" % n
            TOKENS[tok] = "uid%d" % n
            return self._send(200, {"idToken": tok, "localId": "uid%d" % n, "refreshToken": "r" + tok, "expiresIn": "3600"})
        if u.path == "/refresh":
            # la stessa identità di prima, con un gettone nuovo
            old = parse_qs(body).get("refresh_token", [""])[0]
            uid = TOKENS.get(old[1:]) if old.startswith("r") else None
            if uid is None:
                return self._send(400, {"error": {"message": "INVALID_REFRESH_TOKEN"}})
            tok = "tok%d" % n
            TOKENS[tok] = uid
            return self._send(200, {"id_token": tok, "refresh_token": "r" + tok, "user_id": uid})
        self._send(404, {"error": "not found"})


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
