extends SceneTree
## Prova che la LOGICA messa a punto a 2 giocatori vale anche a 4: rotazione dei turni su tutti
## e quattro i seggi, attribuzione dei comandi AUTENTICATA (un client non puo' agire per un
## altro), e un'azione interattiva (Improve Relations) di un seggio CENTRALE (Russia, seggio 2)
## che si risolve e si sincronizza su TUTTE le finestre.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_4p_flow.gd

func _ids(arr: Array) -> Array:
	var o := []
	for c in arr:
		o.append(String((c as Dictionary).get("id", "")))
	return o


func _all_active(insts: Array) -> Array:
	var o := []
	for x in insts:
		o.append(int(x.active_seat))
	return o


func _init() -> void:
	var fails := 0

	var powers := ["usa", "china", "russia", "eu"]
	var host_net := NetSession.new()
	host_net.host_loopback()
	host_net.powers = powers
	get_root().add_child(host_net)
	var client_nets := []
	for i in 3:
		var cn := NetSession.new()
		NetSession.link_loopback(host_net, cn)
		cn.powers = powers
		get_root().add_child(cn)
		client_nets.append(cn)

	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = host_net
	GameConfig.powers = powers
	var host: Variant = board_packed.instantiate()
	get_root().add_child(host)
	await process_frame
	var clients := []
	for cn in client_nets:
		GameConfig.net = cn
		var c: Variant = board_packed.instantiate()
		get_root().add_child(c)
		await process_frame
		clients.append(c)
	GameConfig.net = null
	var all := [host, clients[0], clients[1], clients[2]]   # seggi 0,1,2,3

	# Fase Azione, ordine 0,1,2,3, mani vuote (cosi' "Fine turno" e' sempre lecito).
	host._ui_phase = "Azione"
	host.gs.phase = WO.Phase.ACTION
	host.gs.turn_order.assign([0, 1, 2, 3])
	host.round_turn_count = 0
	host.active_seat = 0
	host._reset_plays()
	for p in host.gs.players:
		p.hand.clear()
	host._net_sync()
	await process_frame

	# 1) ROTAZIONE: ogni seggio chiude il turno dalla PROPRIA finestra; active_seat avanza e si
	#    sincronizza ovunque (0 -> 1 -> 2 -> 3 -> 0).
	var enders := [host, clients[0], clients[1], clients[2]]   # chi agisce a ogni passo
	var expected := [1, 2, 3, 0]
	for step in 4:
		enders[step]._cmd_end_turn()
		await process_frame
		var seats := _all_active(all)
		var ok: bool = seats.all(func(s): return s == expected[step])
		print("[%s] turno del seggio %d chiuso -> active_seat=%d su tutti (%s)" % [
			"OK" if ok else "FAIL", step, expected[step], str(seats)])
		if not ok: fails += 1

	# 2) ATTRIBUZIONE AUTENTICATA: il client del seggio 1 prova a SPACCIARSI per il seggio 3
	#    (payload seat=3). L'host deve attribuire al MITTENTE reale (1), non a 3.
	var captured := {"seat": -99}
	host_net.command_received.connect(func(seat: int, _cmd: Dictionary): captured["seat"] = seat)
	# from_id 101 = client loopback del seggio 1; payload mente dicendo seat=3.
	host_net._handle(101, {"t": "command", "seat": 3, "cmd": GameCommands.end_turn(3, 999)})
	await process_frame
	var s2: bool = int(captured["seat"]) == 1
	print("[%s] comando spacciato per seggio 3 attribuito al MITTENTE reale (seggio %d)" % [
		"OK" if s2 else "FAIL", int(captured["seat"])])
	if not s2: fails += 1

	# 3) AZIONE INTERATTIVA di un seggio CENTRALE (Russia, seggio 2): Improve Relations.
	host.active_seat = 2
	host.round_turn_count = 2
	host._plays_left = 1
	host._played_this_turn = false
	host.gs.players[2].resources["diplomacy"] = 100
	host.gs.players[2].hand.clear()
	host.gs.players[2].hand.append({"display_name": "Test Improve", "effect_ops": [{"op": "improve_relations"}], "effect_modifiers": []})
	host._net_sync()
	await process_frame

	# Trova una Country che la Russia PUO' allearsi (alcune sono vietate per certe potenze).
	var rid0 := ""
	var target_id := ""
	for rid in host.region_countries:
		for c in ((host.region_countries.get(rid, {}) as Dictionary).get("available", []) as Array):
			if not ("russia" in (c as Dictionary).get("no_relations_powers", [])):
				rid0 = rid
				target_id = String((c as Dictionary).get("id", ""))
				break
		if target_id != "":
			break

	# Il seggio 2 (clients[1]) gioca la carta e sceglie la Country sul tabellone.
	clients[1].apply_command(GameCommands.play_card(2, 10, 0))
	await process_frame
	clients[1].apply_command(GameCommands.pick_board_country(2, 11, rid0, target_id))
	await process_frame
	# Se la Russia ha alleati esauribili nella Regione, parte la barra dello SCONTO: il seggio 2
	# la salta (anch'essa instradata). Poi l'Improve si risolve.
	if not host._exhaust_ctx.is_empty():
		clients[1].apply_command(GameCommands.exhaust_skip(2, 12))
		await process_frame

	# La Country scelta e' sparita dal tabellone su TUTTE e quattro le finestre (sync completo).
	var gone_all := true
	var present := []
	for x in all:
		var still: bool = target_id in _ids((x.region_countries.get(rid0, {}) as Dictionary).get("available", []))
		present.append(not still)
		if still: gone_all = false
	var s3: bool = gone_all and host.playing_card.is_empty() and host.awaiting == ""
	print("[%s] Improve del seggio 2 risolto e sincronizzato su tutti (Country via=%s)" % [
		"OK" if s3 else "FAIL", str(present)])
	if not s3: fails += 1

	host.queue_free()
	for c in clients:
		c.queue_free()
	await process_frame

	print("Verifica flusso a 4 giocatori (rotazione + attribuzione + azione centrale): %s" % (
		"OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
