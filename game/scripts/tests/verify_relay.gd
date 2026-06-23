extends SceneTree
## Test d'integrazione END-TO-END del trasporto RELAY (NetSession <-> relay <-> NetSession).
##
## Diversamente dai test loopback (verify_net*.gd), qui si usano SOCKET veri verso un relay
## in esecuzione: serve avviare prima il server (relay/server.js) e passare la sua porta.
##
## Uso:
##   PORT=18923 node relay/server.js &           # avvia il relay
##   RELAY_PORT=18923 godot --headless --path game --script res://scripts/tests/verify_relay.gd
##
## Esce 0 se un comando del client viaggia client -> relay -> host e lo snapshot torna
## host -> relay -> client; 1 su timeout/errore.

var _host: NetSession
var _client: NetSession
var _t := 0.0
var _sent := false
var _done := false
var _room := ""
var _url := ""


func _initialize() -> void:
	var penv := OS.get_environment("RELAY_PORT")
	var port := int(penv) if penv != "" else 18923
	_url = "ws://127.0.0.1:%d" % port
	print("[verify_relay] relay atteso su %s" % _url)

	_host = NetSession.new()
	_client = NetSession.new()
	get_root().add_child(_host)
	get_root().add_child(_client)

	_host.relay_ready.connect(_on_host_ready)
	_host.command_received.connect(_on_host_cmd)
	_host.relay_error.connect(func(c, m): _fail("relay_error host: %s %s" % [c, m]))
	_client.snapshot_received.connect(_on_client_snap)
	_client.relay_error.connect(func(c, m): _fail("relay_error client: %s %s" % [c, m]))
	_client.connection_failed.connect(func(): _fail("client connection_failed (relay spento?)"))
	_host.connection_failed.connect(func(): _fail("host connection_failed (relay spento?)"))

	var err := _host.host_relay(_url)
	if err != OK:
		_fail("host_relay err %d" % err)


func _on_host_ready(room: String) -> void:
	_room = room
	print("[verify_relay] stanza assegnata: %s" % room)
	var e := _client.join_relay(_url, room)
	if e != OK:
		_fail("join_relay err %d" % e)


func _on_host_cmd(seat: int, cmd: Dictionary) -> void:
	print("[verify_relay] host ha ricevuto il comando dal seggio %d: %s" % [seat, str(cmd)])
	# L'host "applica" e rimanda uno snapshot ai client (qui basta un eco).
	_host.broadcast_snapshots(func(_s): return {"ack": true, "cmd": cmd})


func _on_client_snap(state: Dictionary) -> void:
	print("[verify_relay] OK ✅ il client ha ricevuto lo snapshot: %s" % str(state))
	_done = true


func _process(delta: float) -> bool:
	_t += delta
	if _done:
		print("[verify_relay] PASS — round-trip via relay completato (stanza %s)" % _room)
		quit(0)
		return true
	# Appena il client e' entrato e ha ricevuto il seggio (welcome), invia un comando.
	if not _sent and _client.is_client() and _client.my_seat >= 0:
		_sent = true
		print("[verify_relay] client (seggio %d) invia un comando" % _client.my_seat)
		_client.send_command({"t": "PING", "n": 42})
	if _t > 15.0:
		_fail("TIMEOUT (sent=%s room=%s)" % [str(_sent), _room])
		return true
	return false


func _fail(msg: String) -> void:
	push_error("[verify_relay] FAIL — %s" % msg)
	print("[verify_relay] FAIL — %s" % msg)
	quit(1)
