class_name FbTransport
extends Node
## Trasporto FIREBASE per NetSession: fa lo stesso lavoro del relay wss://, ma i messaggi passano
## dal Realtime Database di Firebase (piano gratuito, nessun server da tenere acceso).
## L'host resta l'arbitro: questo modulo sposta solo i messaggi, non li interpreta.
##
## Struttura di una stanza (worldorder/rooms/<CODICE>):
##   info              {host, status, created, seen}  leggibile da chiunque abbia fatto l'accesso
##   members/<uid>     {name, cn, seen}               scrive solo il giocatore; legge lui e l'host
##   cmd/<uid>/<n>     comando n del giocatore         scrive solo il giocatore; legge l'host
##   box/<uid>         casella PRIVATA del giocatore   scrive l'host; legge solo quel giocatore
##     q/<n>           messaggi in coda (welcome, lobby, start) in ordine
##     snap            ultimo stato REDATTO (sostituisce il precedente)
##     meta            {qn: messaggi in coda, sv: versione dello stato}
## Le regole (firebase/database.rules.json) fanno sì che nessun client possa leggere la casella
## di un altro: le mani restano nascoste anche sulla rete, come con il relay.
## Il mittente di un comando è l'uid del percorso (autenticato da Firebase), non il contenuto.
##
## Per leggere poco: i client controllano ogni ~0,8 s solo "meta" (pochi byte) e scaricano lo
## stato solo quando la versione cambia; l'host non riscrive uno stato identico a quello già inviato.

const POLL := 0.8
const HOST_SEEN_EVERY := 5.0
const STALE_MS := 30000

var session                    # NetSession
var rest: FbRest
var role := ""                 # "host" | "client"
var room := ""
var alive := true
var my_uid := ""

# host
var _uid_to_id := {}           # uid -> id peer (2, 3, …): NetSession lavora con id interi
var _id_to_uid := {}
var _next_id := 2
var _cmd_read := {}            # uid -> comandi già letti
var _q_len := {}               # uid -> messaggi in coda scritti
var _last_snap := {}           # uid -> ultimo stato inviato (per non riscriverlo identico)
var _sv := {}                  # uid -> versione dello stato
var _stale := {}               # uid -> true se segnalato come assente
var _pending := {}             # aggiornamenti da scrivere al prossimo giro (percorso -> valore)

# client
var _q_read := 0
var _sv_read := -1
var _cmd_sent := 0
var _host_seen = null
var _host_seen_t := 0


func _exit_tree() -> void:
	alive = false


## Il modulo REST va creato nell'albero della scena (le richieste HTTP sono nodi).
func _ensure_rest() -> void:
	if not is_inside_tree():
		await tree_entered
	if rest == null:
		rest = FbRest.new()
		add_child(rest)


func _ts() -> Dictionary:
	return {".sv": "timestamp"}


func _p(path: String) -> String:
	return "%s/%s/%s" % [FbRest.ROOT, room, path] if path != "" else "%s/%s" % [FbRest.ROOT, room]


# --- Avvio ------------------------------------------------------------------

func start_host(host_name: String) -> void:
	role = "host"
	await _ensure_rest()
	if not await rest.sign_in():
		_fail_conn()
		return
	my_uid = rest.uid
	var g := RandomNumberGenerator.new()
	g.randomize()
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	for attempt in 8:
		var code := ""
		for k in 4:
			code += letters[g.randi() % letters.length()]
		var ex := await rest.db_get("%s/%s/info" % [FbRest.ROOT, code])
		if ex["code"] == 200 and ex["data"] != null:
			continue
		room = code
		var r := await rest.db_patch(_p(""), {"info": {"host": my_uid, "status": "lobby", "created": _ts(), "seen": _ts(), "name": host_name}})
		if r["code"] == 200:
			rest.remember_room(room, 0)
			session.relay_ready.emit(room)
			_host_loop()
			return
		break
	session.relay_error.emit("no_room", "Non riesco a creare la stanza su Firebase. %s" % rest.last_error)
	session.connection_failed.emit()


func start_client(code: String, player_name: String) -> void:
	role = "client"
	room = code.strip_edges().to_upper()
	await _ensure_rest()
	if not await rest.sign_in():
		_fail_conn()
		return
	my_uid = rest.uid
	var info := await rest.db_get(_p("info"))
	if info["code"] != 200:
		_fail_conn()
		return
	if not (info["data"] is Dictionary):
		session.relay_error.emit("no_room", "La stanza %s non esiste." % room)
		session.connection_failed.emit()
		return
	# chi rientra (stesso dispositivo) ritrova la sua casella: si rilegge la coda da capo
	var me := await rest.db_get(_p("members/" + my_uid))
	if me["code"] == 200 and me["data"] is Dictionary:
		_cmd_sent = int(me["data"].get("cn", 0))
	elif String(info["data"].get("status", "")) != "lobby":
		session.relay_error.emit("started", "La partita della stanza %s è già iniziata." % room)
		session.connection_failed.emit()
		return
	var w := await rest.db_patch(_p("members/" + my_uid), {"name": player_name, "cn": _cmd_sent, "seen": _ts()})
	if w["code"] != 200:
		session.relay_error.emit("no_room", "Non riesco a entrare nella stanza %s. %s" % [room, rest.last_error])
		session.connection_failed.emit()
		return
	rest.remember_room(room)
	_host_seen_t = Time.get_ticks_msec()
	session.relay_ready.emit(room)
	_client_loop()


func _fail_conn() -> void:
	session.relay_error.emit("unreachable", "Firebase non raggiungibile. %s" % rest.last_error)
	session.connection_failed.emit()


# --- Invio ------------------------------------------------------------------

## HOST -> client (id) oppure CLIENT -> host (id 1).
func send(to_id: int, msg: Dictionary) -> void:
	if role == "client":
		var n := _cmd_sent
		_cmd_sent += 1
		_pending["cmd/%s/%d" % [my_uid, n]] = Marshalls.variant_to_base64(msg)
		_pending["members/%s/cn" % my_uid] = _cmd_sent
		return
	var uid: String = _id_to_uid.get(to_id, "")
	if uid == "":
		return
	if String(msg.get("t", "")) == "snapshot":
		var b64 := Marshalls.variant_to_base64(msg)
		if _last_snap.get(uid, "") == b64:
			return   # stato identico (il gioco lo ribroadcasta ogni secondo): niente da scrivere
		_last_snap[uid] = b64
		_sv[uid] = int(_sv.get(uid, 0)) + 1
		_pending["box/%s/snap" % uid] = b64
		_pending["box/%s/meta/sv" % uid] = _sv[uid]
		return
	var n2 := int(_q_len.get(uid, 0))
	_q_len[uid] = n2 + 1
	_pending["box/%s/q/%d" % [uid, n2]] = Marshalls.variant_to_base64(msg)
	_pending["box/%s/meta/qn" % uid] = n2 + 1
	if String(msg.get("t", "")) == "start":
		_pending["info/status"] = "playing"


func broadcast(msg: Dictionary) -> void:
	for id in _id_to_uid:
		send(int(id), msg)


func _flush() -> bool:
	if _pending.is_empty():
		return true
	var batch := _pending
	_pending = {}
	var r := await rest.db_patch(_p(""), batch)
	if r["code"] != 200:
		# rimette in coda quanto non scritto (senza sovrascrivere aggiornamenti più recenti)
		for k in batch:
			if not _pending.has(k):
				_pending[k] = batch[k]
		return false
	return true


# --- Ciclo HOST ---------------------------------------------------------------

func _host_loop() -> void:
	var last_seen := 0.0
	while alive and session != null and session.is_active():
		await _flush()
		var now := Time.get_ticks_msec()
		if now - last_seen > HOST_SEEN_EVERY * 1000.0:
			last_seen = now
			_pending["info/seen"] = _ts()
		var r := await rest.db_get(_p("members"))
		if not alive:
			return
		if r["code"] == 200:
			var members := FbRest._as_dict(r["data"])
			for uid in members:
				var m = members[uid]
				if not (m is Dictionary):
					continue
				if not _uid_to_id.has(uid):
					var id := _next_id
					_next_id += 1
					_uid_to_id[uid] = id
					_id_to_uid[id] = uid
					_cmd_read[uid] = int(m.get("cn", 0))   # i comandi di una sessione precedente non contano
					session._on_peer_connected(id)
					var nm := String(m.get("name", "")).strip_edges()
					if nm != "" and session._seats.has(id):
						session._seats[id]["name"] = nm
						session._broadcast({"t": "lobby", "players": session._lobby_list()})
						session._emit_lobby()
				var cn := int(m.get("cn", 0))
				if cn > int(_cmd_read.get(uid, 0)):
					var c := await rest.db_get(_p("cmd/" + uid))
					if not alive:
						return
					if c["code"] == 200:
						var cmds := FbRest._as_dict(c["data"])
						var i := int(_cmd_read[uid])
						while cmds.has(str(i)):
							var msg: Variant = Marshalls.base64_to_variant(String(cmds[str(i)]))
							i += 1
							if msg is Dictionary:
								session._handle(int(_uid_to_id[uid]), msg)
						_cmd_read[uid] = i
				# assenza: nessun segnale da 30 s -> avviso (il posto resta: può rientrare)
				var seen := int(m.get("seen", 0))
				if seen > 0:
					var stale: bool = _stale_by_local(uid, seen)
					if stale and not _stale.get(uid, false):
						_stale[uid] = true
						session.peer_left.emit()
					elif not stale:
						_stale[uid] = false
		await get_tree().create_timer(POLL).timeout


# "seen" è un orario del server: lo confrontiamo con il momento locale in cui è cambiato
var _seen_val := {}
var _seen_at := {}
func _stale_by_local(uid: String, seen: int) -> bool:
	var now := Time.get_ticks_msec()
	if _seen_val.get(uid, -1) != seen:
		_seen_val[uid] = seen
		_seen_at[uid] = now
		return false
	return now - int(_seen_at.get(uid, now)) > STALE_MS


# --- Ciclo CLIENT -------------------------------------------------------------

func _client_loop() -> void:
	var last_seen := 0.0
	while alive and session != null and session.is_active():
		var now := Time.get_ticks_msec()
		if now - last_seen > HOST_SEEN_EVERY * 1000.0:
			last_seen = now
			_pending["members/%s/seen" % my_uid] = _ts()
		await _flush()
		if not alive:
			return
		var r := await rest.db_get(_p("box/%s/meta" % my_uid))
		if not alive:
			return
		if r["code"] == 200 and r["data"] is Dictionary:
			var meta: Dictionary = r["data"]
			var qn := int(meta.get("qn", 0))
			if qn > _q_read:
				var q := await rest.db_get(_p("box/%s/q" % my_uid))
				if not alive:
					return
				if q["code"] == 200:
					var items := FbRest._as_dict(q["data"])
					while items.has(str(_q_read)):
						var msg: Variant = Marshalls.base64_to_variant(String(items[str(_q_read)]))
						_q_read += 1
						if msg is Dictionary:
							session._handle(1, msg)
			var sv := int(meta.get("sv", 0))
			if sv != _sv_read and sv > 0:
				var s := await rest.db_get(_p("box/%s/snap" % my_uid))
				if not alive:
					return
				if s["code"] == 200 and s["data"] != null:
					_sv_read = sv
					var msg2: Variant = Marshalls.base64_to_variant(String(s["data"]))
					if msg2 is Dictionary:
						session._handle(1, msg2)
		# l'host è ancora collegato?
		if now - _host_seen_t > 10000:
			var info := await rest.db_get(_p("info/seen"))
			if not alive:
				return
			if info["code"] == 200:
				if info["data"] != _host_seen:
					_host_seen = info["data"]
					_host_seen_t = Time.get_ticks_msec()
				elif Time.get_ticks_msec() - _host_seen_t > STALE_MS:
					_host_seen_t = Time.get_ticks_msec()
					session.peer_left.emit()
		await get_tree().create_timer(POLL).timeout
