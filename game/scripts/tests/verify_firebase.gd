extends SceneTree
## Test d'integrazione END-TO-END del trasporto FIREBASE (NetSession <-> Firebase <-> NetSession).
##
## Usa il finto Firebase locale (scripts/tests/firebase_mock.py), che applica una versione
## semplificata delle regole di firebase/database.rules.json.
##
## Uso:
##   python3 game/scripts/tests/firebase_mock.py 18924 &
##   WO_DB_URL=http://127.0.0.1:18924/db WO_AUTH_URL=http://127.0.0.1:18924/signup \
##   WO_REFRESH_URL=http://127.0.0.1:18924/refresh \
##   godot --headless --path game --script res://scripts/tests/verify_firebase.gd
##
## Verifica: lobby con il nome del giocatore, comando client -> host con il seggio giusto,
## stato redatto host -> client, e che un terzo giocatore NON possa leggere la casella altrui.
## Esce 0 se tutto va, 1 su timeout/errore.

var _host: NetSession
var _client: NetSession
var _t := 0.0
var _sent := false
var _snap_ok := false
var _spy_ok := false
var _spy_started := false
var _lobby_name_ok := false
var _room := ""


func _initialize() -> void:
	if OS.get_environment("WO_DB_URL") == "":
		_fail("serve WO_DB_URL (finto Firebase)")
		return
	OS.set_environment("WO_SESSION", "user://t_fb_host.cfg")
	_host = NetSession.new()
	get_root().add_child(_host)
	_host.relay_ready.connect(_on_host_ready)
	_host.command_received.connect(_on_host_cmd)
	_host.relay_error.connect(func(c, m): _fail("errore host: %s %s" % [c, m]))
	_host.lobby_changed.connect(func(players):
		for pl in players:
			if String(pl.get("name", "")) == "Ospite" and int(pl.get("seat", -1)) == 1:
				_lobby_name_ok = true)
	_host.host_firebase("Host")


func _on_host_ready(room: String) -> void:
	_room = room
	print("[verify_firebase] stanza: %s" % room)
	OS.set_environment("WO_SESSION", "user://t_fb_client.cfg")
	_client = NetSession.new()
	get_root().add_child(_client)
	_client.snapshot_received.connect(_on_client_snap)
	_client.relay_error.connect(func(c, m): _fail("errore client: %s %s" % [c, m]))
	_client.join_firebase(room, "Ospite")


func _on_host_cmd(seat: int, cmd: Dictionary) -> void:
	print("[verify_firebase] host: comando dal seggio %d: %s" % [seat, str(cmd)])
	if seat != 1:
		_fail("seggio del mittente sbagliato: %d" % seat)
		return
	_host.broadcast_snapshots(func(s): return {"ack": true, "seat": s, "hand": ["carta segreta"], "cmd": cmd})


func _on_client_snap(state: Dictionary) -> void:
	print("[verify_firebase] client: stato ricevuto: %s" % str(state))
	if state.get("ack", false) and int(state.get("seat", -1)) == 1:
		_snap_ok = true
		_spy()


## Un terzo giocatore prova a leggere la casella del client: deve essere rifiutato.
func _spy() -> void:
	if _spy_started:
		return
	_spy_started = true
	OS.set_environment("WO_SESSION", "user://t_fb_spy.cfg")
	var spy := FbRest.new()
	get_root().add_child(spy)
	await spy.sign_in()
	var r := await spy.db_get("%s/%s/box/%s/snap" % [FbRest.ROOT, _room, _client._fb.my_uid])
	print("[verify_firebase] lettura della casella altrui: codice %d" % r["code"])
	_spy_ok = r["code"] == 401 or r["code"] == 403


func _process(delta: float) -> bool:
	_t += delta
	if _snap_ok and _spy_ok and _lobby_name_ok:
		print("[verify_firebase] PASS — lobby, comando, stato redatto e privacy via Firebase (stanza %s)" % _room)
		quit(0)
		return true
	if not _sent and _client != null and _client.is_client() and _client.my_seat >= 0:
		_sent = true
		print("[verify_firebase] client (seggio %d) invia un comando" % _client.my_seat)
		_client.send_command({"t": "PING", "n": 42})
	if _t > 30.0:
		_fail("TIMEOUT (sent=%s snap=%s spy=%s lobby=%s)" % [_sent, _snap_ok, _spy_ok, _lobby_name_ok])
		return true
	return false


func _fail(msg: String) -> void:
	push_error("[verify_firebase] FAIL — %s" % msg)
	print("[verify_firebase] FAIL — %s" % msg)
	quit(1)
