extends SceneTree
## Riproduce il flusso REALE di Improve Relations in rete: il client GIOCA la carta, poi
## sceglie la Country sul tabellone. Verifica che la risoluzione si chiuda (playing_card e
## awaiting vuoti) e che si possa terminare il turno (_played_this_turn).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_improve2.gd

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

	# Turno della Cina (client). Carta Improve Relations in mano (indice 0), diplomazia alta.
	host.active_seat = 1
	host._plays_left = 1
	host._played_this_turn = false
	host.gs.players[1].resources["diplomacy"] = 100
	var card := {"display_name": "Test Improve", "effect_ops": [{"op": "improve_relations"}], "effect_modifiers": []}
	host.gs.players[1].hand.clear()
	host.gs.players[1].hand.append(card)
	host._net_sync()
	await process_frame

	# 1) Il client GIOCA la carta -> l'host la risolve: awaiting board_country su entrambi.
	var played: bool = client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame
	var s1: bool = played and host.awaiting == "board_country" and client.awaiting == "board_country"
	print("[%s] carta giocata: awaiting board_country (host=%s, client=%s)" % [
		"OK" if s1 else "FAIL", host.awaiting, client.awaiting])
	if not s1: fails += 1

	# 2) Il client sceglie la Country sul tabellone.
	var rid0 := ""
	for rid in host.region_countries:
		if not (host.region_countries[rid] as Dictionary).get("available", []).is_empty():
			rid0 = rid
			break
	var target_id := String(((host.region_countries.get(rid0, {}) as Dictionary).get("available", [])[0] as Dictionary).get("id", ""))
	client.apply_command(GameCommands.pick_board_country(1, 2, rid0, target_id))
	await process_frame

	var gone: bool = not (target_id in _ids((client.region_countries.get(rid0, {}) as Dictionary).get("available", [])))
	print("[%s] Country scelta sparita dalla mappa sul client (%s in %s)" % ["OK" if gone else "FAIL", target_id, rid0])
	if not gone: fails += 1

	# 3) Risoluzione COMPLETA: niente carta in gioco, niente awaiting -> si prosegue.
	var done: bool = host.playing_card.is_empty() and host.awaiting == "" \
		and client.playing_card.is_empty() and client.awaiting == ""
	print("[%s] risoluzione chiusa (host playing=%s awaiting='%s' | client playing=%s awaiting='%s')" % [
		"OK" if done else "FAIL", str(not host.playing_card.is_empty()), host.awaiting,
		str(not client.playing_card.is_empty()), client.awaiting])
	if not done: fails += 1

	# 4) Si puo' terminare il turno: la carta risulta GIOCATA (must_play diventa false).
	var can_end: bool = host._played_this_turn or host.gs.players[1].hand.is_empty() or host._plays_left <= 0
	print("[%s] turno terminabile (played=%s, plays_left=%d, hand=%d)" % [
		"OK" if can_end else "FAIL", str(host._played_this_turn), host._plays_left, host.gs.players[1].hand.size()])
	if not can_end: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Improve Relations (flusso reale) in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
