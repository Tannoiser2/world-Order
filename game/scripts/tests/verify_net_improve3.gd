extends SceneTree
## Improve Relations in rete CON sconto (il giocatore ha un alleato esauribile nella Regione):
## il flusso passa per la barra dello sconto (_exhaust_ctx). Verifica che il client la veda,
## possa Saltare/Confermare, e che la risoluzione si chiuda (turno terminabile).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_improve3.gd

func _ids(arr: Array) -> Array:
	var o := []
	for c in arr:
		o.append(String((c as Dictionary).get("id", "")))
	return o


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

	# Round 1 ora passa dalla PREPARATION (scelta Focus): forziamo la fase Azione per
	# testare la risoluzione di una carta (la barra di scelta deve restare vuota a fine turno).
	host._begin_action_phase()
	host.active_seat = 1
	host._plays_left = 1
	host._played_this_turn = false
	host.gs.players[1].resources["diplomacy"] = 100
	# Regione con Country da alleare.
	var rid0 := ""
	for rid in host.region_countries:
		if not (host.region_countries[rid] as Dictionary).get("available", []).is_empty():
			rid0 = rid
			break
	var target_id := String(((host.region_countries.get(rid0, {}) as Dictionary).get("available", [])[0] as Dictionary).get("id", ""))
	# Alleato ESAURIBILE nella stessa Regione -> attiva la barra dello sconto.
	host.gs.players[1].allied_countries.append({"id": "ally_test", "display_name": "Ally Test", "region": rid0, "value": 2})
	# Carta Improve in mano.
	host.gs.players[1].hand.clear()
	host.gs.players[1].hand.append({"display_name": "Test Improve", "effect_ops": [{"op": "improve_relations"}], "effect_modifiers": []})
	host._net_sync()
	await process_frame

	# Gioca la carta e scegli la Country: con un alleato esauribile parte lo SCONTO.
	client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame
	client.apply_command(GameCommands.pick_board_country(1, 2, rid0, target_id))
	await process_frame

	# 1) Il client vede la barra dello sconto (Improve non ancora risolto, Country ancora lì).
	var d1: bool = not client._exhaust_ctx.is_empty() and (target_id in _ids(
		(client.region_countries.get(rid0, {}) as Dictionary).get("available", [])))
	print("[%s] sconto attivo sul client, Country ancora sul tabellone (exhaust=%s)" % [
		"OK" if d1 else "FAIL", str(not client._exhaust_ctx.is_empty())])
	if not d1: fails += 1

	# 2) Il client SALTA lo sconto -> l'host risolve.
	var sent: bool = client.apply_command(GameCommands.exhaust_skip(1, 3))
	await process_frame
	var gone: bool = not (target_id in _ids((client.region_countries.get(rid0, {}) as Dictionary).get("available", [])))
	var d2: bool = sent and gone
	print("[%s] saltato lo sconto: la Country viene allleata e sparisce dal tabellone" % ["OK" if d2 else "FAIL"])
	if not d2: fails += 1

	# 3) Risoluzione COMPLETA e turno terminabile (era questo a 'morire lì').
	var done: bool = host.playing_card.is_empty() and host.awaiting == "" and host._exhaust_ctx.is_empty() \
		and client.playing_card.is_empty() and client.awaiting == "" and client._exhaust_ctx.is_empty()
	var endable: bool = host._played_this_turn or host._plays_left <= 0
	var d3: bool = done and endable
	print("[%s] risoluzione chiusa e turno terminabile (done=%s, played=%s)" % [
		"OK" if d3 else "FAIL", str(done), str(host._played_this_turn)])
	if not d3: fails += 1

	# 4) La barra dello sconto si SVUOTA sul client dopo la risoluzione (era questa a restare
	#    appesa facendo sembrare il turno bloccato).
	var d4: bool = client.choice_flow.get_child_count() == 0
	print("[%s] barra dello sconto svuotata sul client (controlli=%d)" % [
		"OK" if d4 else "FAIL", client.choice_flow.get_child_count()])
	if not d4: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Improve Relations con sconto in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
