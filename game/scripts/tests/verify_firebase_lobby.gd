extends SceneTree
## Prova END-TO-END dal MENU via Firebase (finto Firebase locale): due istanze del gioco.
## WO_ROLE=host crea la stanza da «Ospita (Internet)» con il campo relay vuoto, scrive il codice
## in WO_CODEFILE, aspetta l'ospite e preme «Avvia partita». WO_ROLE=guest entra con il codice.
## Entrambe devono arrivare al tabellone; l'ospite deve ricevere almeno uno stato dall'host.
## Uso (dopo aver avviato scripts/tests/firebase_mock.py e impostato WO_DB_URL & co.):
##   WO_ROLE=host  WO_SESSION=user://h.cfg WO_CODEFILE=/tmp/code godot --headless --path game --script res://scripts/tests/verify_firebase_lobby.gd
##   WO_ROLE=guest WO_SESSION=user://g.cfg WO_CODEFILE=/tmp/code godot --headless --path game --script res://scripts/tests/verify_firebase_lobby.gd

var _snaps := 0

func _initialize() -> void:
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _scene_name() -> String:
	return String(current_scene.scene_file_path) if current_scene != null else ""

func _run() -> void:
	var role := OS.get_environment("WO_ROLE")
	var cf := OS.get_environment("WO_CODEFILE")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(0.5)
	var menu = current_scene
	menu._on_mode("online")
	menu._relay_url_edit.text = ""
	menu._online_name_edit.text = "Host" if role == "host" else "Ospite"
	var t0 := Time.get_ticks_msec()
	if role == "host":
		menu._on_relay_host()
		while menu._relay_room == "":
			await _wait(0.2)
			if Time.get_ticks_msec() - t0 > 20000:
				_fail("nessun codice stanza: %s" % menu._lobby_status.text)
				return
		print("[fb_lobby] host: stanza %s — %s" % [menu._relay_room, menu._lobby_status.text])
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(menu._relay_room)
		f.close()
		while menu._net.lobby_players().size() < 2:
			await _wait(0.3)
			if Time.get_ticks_msec() - t0 > 60000:
				_fail("l'ospite non e' arrivato")
				return
		print("[fb_lobby] host: lobby %s" % str(menu._net.lobby_players()))
		menu._on_play()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		menu._relay_room_edit.text = code
		menu._on_relay_join()
		var net: NetSession = menu._net
		net.snapshot_received.connect(func(_s): _snaps += 1)
	while not _scene_name().ends_with("board.tscn"):
		await _wait(0.3)
		if Time.get_ticks_msec() - t0 > 90000:
			_fail("non si arriva al tabellone (%s)" % _scene_name())
			return
	print("[fb_lobby] %s: tabellone caricato" % role)
	if role == "guest":
		while _snaps < 1:
			await _wait(0.3)
			if Time.get_ticks_msec() - t0 > 90000:
				_fail("nessuno stato ricevuto dall'host")
				return
		print("[fb_lobby] guest: %d stati ricevuti" % _snaps)
	else:
		await _wait(8.0)   # l'host resta acceso finche' l'ospite riceve lo stato
	print("[fb_lobby] PASS %s" % role)
	quit(0)

func _fail(m: String) -> void:
	print("[fb_lobby] FAIL — %s" % m)
	quit(1)
