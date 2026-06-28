extends SceneTree
## Executive Order in RETE: il client usa la sua Executive Order (al posto di una carta),
## sceglie un'azione dalla scelta a 8 opzioni e la risolve. Copre: use_executive_order ->
## scelta sincronizzata (popup_choice) -> azione concatenata (Produce) -> risoluzione su
## host e client; e lo stato "usata" sincronizzato.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_executive_order.gd

func _init() -> void:
	var fails := 0
	var host_net := NetSession.new(); host_net.host_loopback()
	var client_net := NetSession.new(); NetSession.link_loopback(host_net, client_net)
	get_root().add_child(host_net); get_root().add_child(client_net)
	var powers := ["usa", "china"]
	host_net.powers = powers; client_net.powers = powers
	var bp: PackedScene = load("res://scenes/board.tscn")

	GameConfig.net = host_net; GameConfig.powers = powers
	var host: Variant = bp.instantiate(); get_root().add_child(host); await process_frame
	GameConfig.net = client_net
	var client: Variant = bp.instantiate(); get_root().add_child(client); await process_frame
	GameConfig.net = null

	host._begin_action_phase()
	host.active_seat = 1                 # turno della Cina (client)
	host._plays_left = 1
	host._played_this_turn = false
	host.gs.players[1].executive_order_used = false
	host.gs.players[1].production = {"energy": 2, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0, "armies": 0}
	host.gs.players[1].resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	host._net_sync()
	await process_frame

	# 1) Il client usa la Executive Order: appare la scelta a 8 opzioni e l'EO risulta usata.
	client.apply_command(GameCommands.use_executive_order(1, 1))
	await process_frame
	var s1: bool = client._popup_active() and client._popup_items.size() == 8 \
		and host.gs.players[1].executive_order_used and client.gs.players[1].executive_order_used
	print("[%s] client usa EO: scelta a %d opzioni, usata sincronizzata" % [
		"OK" if s1 else "FAIL", client._popup_items.size()])
	if not s1: fails += 1

	# 2) Sceglie 'Produci 3 tipi' (indice 7): Produce attivo e limite sincronizzato.
	client.apply_command(GameCommands.popup_choice(1, 2, 7))
	await process_frame
	var s2: bool = host._produce_mode and client._produce_mode \
		and host._produce_max_types == 3 and client._produce_max_types == 3
	print("[%s] scelta 'Produci' -> Produce attivo, limite 3 sincronizzato" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# 3) Conferma Produce: si risolve su host e client; turno terminabile.
	client.apply_command(GameCommands.produce(1, 3, {"energy": 1}))
	await process_frame
	var produced: bool = int(host.gs.players[1].resources.get("energy", 0)) >= 1
	var closed: bool = not host._produce_mode and not client._produce_mode \
		and host.playing_card.is_empty() and client.playing_card.is_empty()
	var endable: bool = host._played_this_turn or host._plays_left <= 0
	var s3: bool = produced and closed and endable
	print("[%s] EO risolta e sincronizzata (energia=%d, chiuso=%s, terminabile=%s)" % [
		"OK" if s3 else "FAIL", int(host.gs.players[1].resources.get("energy", 0)), str(closed), str(endable)])
	if not s3: fails += 1

	host.queue_free(); client.queue_free(); await process_frame
	print("Verifica Executive Order in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
