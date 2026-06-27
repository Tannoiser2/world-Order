extends SceneTree
## Azioni sulla MAPPA (elementi condivisi) solo per CHI AGISCE. Durante il turno del client,
## l'HOST non deve poter posare l'Influenza al posto suo (era "le azioni sulla finestra
## sbagliata"). Verifica che il click dell'host (non di turno) sia ignorato e che quello del
## client risolva.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_acting_guard.gd

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
	# giocare una carta che posa Influenza sulla mappa.
	host._begin_action_phase()
	# Turno della Cina (client, seggio 1). Carta che posa Influenza sulla mappa.
	host.active_seat = 1
	host._plays_left = 1
	host._played_this_turn = false
	host.gs.players[1].hand.clear()
	host.gs.players[1].hand.append({"display_name": "Test Influence", "effect_ops": [{"op": "add_influence"}], "effect_modifiers": []})
	host._net_sync()
	await process_frame

	# Il client gioca la carta: entrambi in attesa di una casella Influenza.
	client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame
	var s0: bool = host.awaiting == "influence_cell" and client.awaiting == "influence_cell"
	print("[%s] preludio: entrambi in attesa della casella Influenza" % ["OK" if s0 else "FAIL"])
	if not s0: fails += 1

	var rid0 := String(host.gs.regions.keys()[0])

	# 1) L'HOST (USA, NON di turno) prova a posare l'Influenza della Cina: deve essere IGNORATO.
	host._cmd_pick_influence_cell(rid0, "permanent")
	await process_frame
	var blocked: bool = host.awaiting == "influence_cell" and not host.playing_card.is_empty()
	print("[%s] click dell'host (non di turno) IGNORATO (awaiting ancora '%s')" % [
		"OK" if blocked else "FAIL", host.awaiting])
	if not blocked: fails += 1

	# 2) Il CLIENT (Cina, di turno) posa l'Influenza: la carta si risolve su entrambi.
	client._cmd_pick_influence_cell(rid0, "permanent")
	await process_frame
	var resolved: bool = host.awaiting == "" and host.playing_card.is_empty() \
		and client.awaiting == "" and client.playing_card.is_empty()
	print("[%s] click del client (di turno) risolve la carta su entrambi" % ["OK" if resolved else "FAIL"])
	if not resolved: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica guardia 'solo chi agisce' sulla mappa: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
