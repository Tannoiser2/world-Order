extends SceneTree
## Registro e Avviso in rete: le righe del Registro generate dall'host si sincronizzano sul
## client; quando un'azione del client non e' eseguibile, l'AVVISO (banner) arriva al client
## che ha agito (l'host risolve per lui).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_log.gd

func _init() -> void:
	var fails := 0

	var host_net := NetSession.new()
	host_net.host_loopback()
	var client_net := NetSession.new()
	NetSession.link_loopback(host_net, client_net)
	get_root().add_child(host_net)
	get_root().add_child(client_net)
	var powers := ["usa", "china"]
	host_net.powers = powers
	client_net.powers = powers

	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = host_net
	GameConfig.powers = powers
	var host: Variant = board_packed.instantiate()
	get_root().add_child(host)
	await process_frame
	GameConfig.net = client_net
	var client: Variant = board_packed.instantiate()
	get_root().add_child(client)
	await process_frame
	GameConfig.net = null

	# 1) REGISTRO: una riga generata dall'host arriva al client.
	host._event("PROVA: evento di registro")
	host._net_sync()
	await process_frame
	var s1: bool = client._log_lines.has("PROVA: evento di registro")
	print("[%s] riga di Registro sincronizzata sul client (righe client=%d)" % [
		"OK" if s1 else "FAIL", client._log_lines.size()])
	if not s1: fails += 1

	# 2) AVVISO: il client gioca un Improve che non puo' permettersi -> azione non eseguibile ->
	#    carta restituita + AVVISO. L'host risolve per il client; il client (attore) lo riceve.
	host.active_seat = 1
	host._plays_left = 1
	host._played_this_turn = false
	host.gs.players[1].resources["diplomacy"] = 0
	host.gs.players[1].allied_countries = []
	host.gs.players[1].hand.clear()
	host.gs.players[1].hand.append({"display_name": "Improve impossibile", "effect_ops": [{"op": "improve_relations"}], "effect_modifiers": []})
	host._net_sync()
	await process_frame

	var rid0 := ""
	var target_id := ""
	for rid in host.region_countries:
		for c in ((host.region_countries.get(rid, {}) as Dictionary).get("available", []) as Array):
			var cd := c as Dictionary
			if int(cd.get("value", 0)) > 0 and not ("china" in cd.get("no_relations_powers", [])):
				rid0 = rid; target_id = String(cd.get("id", "")); break
		if target_id != "":
			break

	var seq_before: int = host._notify_seq
	client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame
	client.apply_command(GameCommands.pick_board_country(1, 2, rid0, target_id))
	await process_frame

	var s2: bool = host._notify_seq > seq_before and client._last_notify_seq == host._notify_seq
	print("[%s] avviso sincronizzato all'attore (host seq=%d, client seq=%d)" % [
		"OK" if s2 else "FAIL", host._notify_seq, client._last_notify_seq])
	if not s2: fails += 1

	# La carta e' tornata in mano al client (azione non andata a buon fine).
	var s3: bool = host.gs.players[1].hand.size() == 1 and client.gs.players[1].hand.size() == 1 \
		and not host._played_this_turn
	print("[%s] carta restituita su entrambi (host mano=%d, client mano=%d)" % [
		"OK" if s3 else "FAIL", host.gs.players[1].hand.size(), client.gs.players[1].hand.size()])
	if not s3: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame
	print("Verifica Registro + Avviso in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
