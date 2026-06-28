extends SceneTree
## Carta con SCELTA MULTIPLA che concatena una SECONDA azione interattiva, in RETE.
## Caso piu' difficile per il multiplayer: il client gioca una carta tipo "Growth Strategy"
## (scelta: Get a Growth Card OPPURE Produci 3 tipi). Deve: vedere il popup di scelta,
## scegliere "Produci" (l'host esegue la callback), entrare in Produce con il limite di tipi
## sincronizzato, e infine risolvere su ENTRAMBE le finestre. Copre: play_card -> popup ->
## popup_choice -> op concatenato (produce) -> produce_mode/produce_max_types sincronizzati ->
## comando produce -> risoluzione.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_choice_card.gd

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
	host.gs.players[1].production = {"energy": 2, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0, "armies": 0}
	host.gs.players[1].resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	host.gs.players[1].hand = [{
		"display_name": "Test Scelta",
		"effect_ops": [{"op": "choice", "options": [
			[{"op": "get_growth"}],
			[{"op": "produce", "count": 3}]
		]}],
		"effect_modifiers": []
	}]
	host._net_sync()
	await process_frame

	# 1) Il client gioca la carta: appare il POPUP di scelta (2 opzioni) ricostruito dallo snapshot.
	client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame
	var s1: bool = client._popup_active() and client._popup_items.size() == 2
	print("[%s] client vede il popup di scelta (%d opzioni)" % ["OK" if s1 else "FAIL", client._popup_items.size()])
	if not s1: fails += 1

	# 2) Il client sceglie l'opzione 'Produci' (indice 1): l'host esegue la callback e si entra
	#    in Produce, col limite di TIPI (count=3) sincronizzato su entrambi.
	client.apply_command(GameCommands.popup_choice(1, 2, 1))
	await process_frame
	var s2: bool = host._produce_mode and client._produce_mode \
		and host._produce_max_types == 3 and client._produce_max_types == 3
	print("[%s] scelta 'Produci' -> Produce attivo e limite 3 tipi sincronizzato (host=%d client=%d)" % [
		"OK" if s2 else "FAIL", host._produce_max_types, client._produce_max_types])
	if not s2: fails += 1

	# 3) Il client conferma la Produzione (1 Energia): l'host applica e la Produzione si risolve
	#    su entrambi (esce dal Produce, carta risolta).
	client.apply_command(GameCommands.produce(1, 3, {"energy": 1}))
	await process_frame
	var produced: bool = int(host.gs.players[1].resources.get("energy", 0)) >= 1
	var closed: bool = not host._produce_mode and not client._produce_mode \
		and host.playing_card.is_empty() and client.playing_card.is_empty()
	var s3: bool = produced and closed
	print("[%s] Produzione risolta e sincronizzata (energia=%d, produce chiuso=%s)" % [
		"OK" if s3 else "FAIL", int(host.gs.players[1].resources.get("energy", 0)), str(closed)])
	if not s3: fails += 1

	# 4) Turno terminabile (la risoluzione non e' rimasta appesa).
	var s4: bool = host._played_this_turn or host._plays_left <= 0
	print("[%s] turno terminabile dopo la carta a scelta multipla (played=%s)" % [
		"OK" if s4 else "FAIL", str(host._played_this_turn)])
	if not s4: fails += 1

	host.queue_free(); client.queue_free(); await process_frame
	print("Verifica carta a scelta multipla concatenata in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
