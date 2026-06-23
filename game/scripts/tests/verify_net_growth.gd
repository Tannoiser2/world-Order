extends SceneTree
## "Get a Growth Card" in rete: il selettore a carte deve apparire a CHI agisce (il client),
## NON sullo schermo dell'host che arbitra (era il bug: "la Growth scelta dalla Cina compariva
## sulla finestra USA"). Verifica che lo stato sia sincronizzato, che l'host NON costruisca
## l'overlay in locale, che il client SÌ, e che "Salta"/acquisto chiudano la scelta su entrambi.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_growth.gd

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

	# Turno della Cina (client, seggio 1). Carta con "Get a Growth Card" in mano.
	host.active_seat = 1
	host._plays_left = 1
	host._played_this_turn = false
	host.gs.players[1].hand.clear()
	host.gs.players[1].hand.append({"display_name": "Test Growth", "effect_ops": [{"op": "get_growth"}], "effect_modifiers": []})
	host._net_sync()
	await process_frame

	# Il client gioca la carta: l'host risolve -> selettore Growth attivo, sincronizzato.
	client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame

	var s1: bool = not host._growth_pick.is_empty() and not client._growth_pick.is_empty()
	print("[%s] selettore Growth sincronizzato (host=%s, client=%s)" % [
		"OK" if s1 else "FAIL", str(not host._growth_pick.is_empty()), str(not client._growth_pick.is_empty())])
	if not s1: fails += 1

	# Il NOCCIOLO del bug: l'host (USA, arbitro) NON costruisce l'overlay; il client (Cina) SÌ.
	var s2: bool = not host._growth_pick_shown and client._growth_pick_shown
	print("[%s] overlay solo su CHI agisce (host_shown=%s, client_shown=%s)" % [
		"OK" if s2 else "FAIL", str(host._growth_pick_shown), str(client._growth_pick_shown)])
	if not s2: fails += 1

	# Il client SALTA: il comando arriva all'host, che chiude la scelta e prosegue.
	var sent: bool = client.apply_command(GameCommands.growth_skip(1, 2))
	await process_frame

	var closed: bool = host._growth_pick.is_empty() and client._growth_pick.is_empty() \
		and not host._growth_pick_shown and not client._growth_pick_shown
	print("[%s] 'Salta' chiude il selettore su entrambi (inviato=%s)" % ["OK" if (sent and closed) else "FAIL", str(sent)])
	if not (sent and closed): fails += 1

	# Risoluzione completa e turno terminabile.
	var done: bool = host.playing_card.is_empty() and host.awaiting == "" \
		and client.playing_card.is_empty() and client.awaiting == ""
	var endable: bool = host._played_this_turn or host._plays_left <= 0
	print("[%s] risoluzione chiusa e turno terminabile (done=%s, played=%s)" % [
		"OK" if (done and endable) else "FAIL", str(done), str(host._played_this_turn)])
	if not (done and endable): fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Get a Growth Card in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
