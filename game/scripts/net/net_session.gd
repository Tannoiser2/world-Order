class_name NetSession
extends Node
## Sessione di rete per il multiplayer host-authoritative (vedi docs/multiplayer-design.md).
##
## L'HOST possiede il gioco: riceve COMANDI dai client (command_received -> board.apply_command),
## li applica e RIBROADCASTA a ciascun client lo stato REDATTO (state_for_seat). I client
## inviano comandi e renderizzano gli snapshot ricevuti.
##
## Trasporto: WebSocket (LAN ora; Internet poi con un relay - cambia solo l'indirizzo).
## Per i TEST esiste un trasporto LOOPBACK in-process (link_loopback): il protocollo si
## verifica senza socket reali.

signal lobby_changed(players: Array)          # host+client: [{peer, seat, name}]
signal snapshot_received(state: Dictionary)   # client: nuovo stato (redatto) dall'host
signal command_received(seat: int, cmd: Dictionary)  # host: comando da applicare
signal started(seat: int, powers: Array)      # tutti: partita avviata
signal connection_failed()
signal peer_left()

enum Role { NONE, HOST, CLIENT }

const PORT_DEFAULT := 8910
const HOST_ID := 1

var role: int = Role.NONE
var my_seat: int = -1
var powers: Array = []

var _peer: WebSocketMultiplayerPeer = null
# Lobby host: peer_id -> {seat, name}. L'host e' peer 1 / seggio 0.
var _seats: Dictionary = {}
var _next_seat := 0
var _started := false

# Trasporto LOOPBACK (solo test): host -> lista client; client -> host + id fittizio.
var _loop_clients: Array = []
var _loop_host: NetSession = null
var _loop_id := HOST_ID


# --- Avvio (WebSocket reale) -------------------------------------------------

func host_lan(port: int = PORT_DEFAULT, host_name := "Host") -> int:
	role = Role.HOST
	my_seat = 0
	_seats[HOST_ID] = {"seat": 0, "name": host_name}
	_next_seat = 1
	_peer = WebSocketMultiplayerPeer.new()
	var err := _peer.create_server(port)
	if err != OK:
		_peer = null
		role = Role.NONE
		return err
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	_emit_lobby()
	return OK


func join_lan(ip: String, port: int = PORT_DEFAULT) -> int:
	role = Role.CLIENT
	_peer = WebSocketMultiplayerPeer.new()
	var err := _peer.create_client("ws://%s:%d" % [ip, port])
	if err != OK:
		_peer = null
		role = Role.NONE
		return err
	return OK


## HOST senza socket (test / setup locale): seggio 0, pronto per link_loopback.
func host_loopback() -> void:
	role = Role.HOST
	my_seat = 0
	_seats[HOST_ID] = {"seat": 0, "name": "Host"}
	_next_seat = 1
	_emit_lobby()


func is_active() -> bool:
	return role != Role.NONE


## Chiude il trasporto e azzera il ruolo (da chiamare prima di liberare il nodo, così la
## porta del server si libera SUBITO e un nuovo host non trova "porta occupata").
func close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	role = Role.NONE
	_started = false


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


# --- Loop di rete reale ------------------------------------------------------

func _process(_dt: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var from_id := _peer.get_packet_peer()
		var msg: Variant = bytes_to_var(_peer.get_packet())
		if msg is Dictionary:
			_handle(from_id, msg)


func _on_peer_connected(id: int) -> void:
	# HOST: un client si e' connesso -> assegna seggio, avvisa, aggiorna la lobby.
	var seat := _next_seat
	_next_seat += 1
	_seats[id] = {"seat": seat, "name": "Giocatore %d" % seat}
	_send(id, {"t": "welcome", "seat": seat})
	_broadcast({"t": "lobby", "players": _lobby_list()})
	_emit_lobby()


func _on_peer_disconnected(id: int) -> void:
	_seats.erase(id)
	_broadcast({"t": "lobby", "players": _lobby_list()})
	_emit_lobby()
	peer_left.emit()


# --- API pubblica ------------------------------------------------------------

## CLIENT: invia un comando all'host. HOST: applica direttamente (gestito dalla Vista).
func send_command(cmd: Dictionary) -> void:
	if role == Role.CLIENT:
		_send(HOST_ID, {"t": "command", "seat": my_seat, "cmd": cmd})


## HOST: dopo aver applicato un comando, ribroadcasta a ogni CLIENT il suo stato redatto.
## `provider` riceve il seggio e ritorna lo stato (es. func(seat): return gs.state_for_seat(seat)).
func broadcast_snapshots(provider: Callable) -> void:
	if role != Role.HOST:
		return
	for id in _seats:
		if id == HOST_ID:
			continue
		var seat: int = int(_seats[id]["seat"])
		_send(id, {"t": "snapshot", "state": provider.call(seat)})


## HOST: avvia la partita assegnando le potenze ai seggi e avvisando i client.
func start_game(powers_by_seat: Array) -> void:
	if role != Role.HOST:
		return
	powers = powers_by_seat.duplicate()
	_started = true
	for id in _seats:
		if id == HOST_ID:
			continue
		_send(id, {"t": "start", "seat": int(_seats[id]["seat"]), "powers": powers})
	started.emit(0, powers)


func lobby_players() -> Array:
	return _lobby_list()


# --- Dispatch dei messaggi (comune a WebSocket e loopback) -------------------

func _handle(from_id: int, msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"welcome":
			my_seat = int(msg.get("seat", -1))
		"lobby":
			lobby_changed.emit(msg.get("players", []))
		"start":
			my_seat = int(msg.get("seat", my_seat))
			powers = msg.get("powers", [])
			_started = true
			started.emit(my_seat, powers)
		"command":
			# Solo l'HOST riceve comandi: li applica e ribroadcasta (la Vista fa entrambe).
			command_received.emit(int(msg.get("seat", -1)), msg.get("cmd", {}))
		"snapshot":
			snapshot_received.emit(msg.get("state", {}))


func _send(to_id: int, msg: Dictionary) -> void:
	if _loop_host != null or not _loop_clients.is_empty():
		_loop_send(to_id, msg)
		return
	if _peer:
		_peer.set_target_peer(to_id)
		_peer.put_packet(var_to_bytes(msg))


func _broadcast(msg: Dictionary) -> void:
	if not _loop_clients.is_empty():
		for c in _loop_clients:
			(c as NetSession)._handle(HOST_ID, msg)
		return
	if _peer:
		_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
		_peer.put_packet(var_to_bytes(msg))


func _lobby_list() -> Array:
	var out := []
	for id in _seats:
		out.append({"peer": id, "seat": int(_seats[id]["seat"]), "name": String(_seats[id]["name"])})
	out.sort_custom(func(a, b): return int(a["seat"]) < int(b["seat"]))
	return out


func _emit_lobby() -> void:
	lobby_changed.emit(_lobby_list())


# --- Trasporto LOOPBACK (test) ----------------------------------------------

## Collega host<->client in-process (senza socket). Assegna al client il prossimo seggio.
static func link_loopback(host: NetSession, client: NetSession) -> void:
	var seat := host._next_seat
	host._next_seat += 1
	host._seats[100 + seat] = {"seat": seat, "name": "Giocatore %d" % seat}
	host._loop_clients.append(client)
	client.role = Role.CLIENT
	client._loop_host = host
	client._loop_id = 100 + seat
	client.my_seat = seat
	host._emit_lobby()
	host._broadcast({"t": "lobby", "players": host._lobby_list()})


func _loop_send(to_id: int, msg: Dictionary) -> void:
	if role == Role.HOST:
		for c in _loop_clients:
			if (c as NetSession)._loop_id == to_id:
				(c as NetSession)._handle(HOST_ID, msg)
				return
	elif _loop_host != null:
		_loop_host._handle(_loop_id, msg)
