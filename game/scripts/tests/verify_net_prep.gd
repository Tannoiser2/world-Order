extends SceneTree
## PREPARAZIONE in rete: la scelta del Focus e l'Aumento Produzione devono apparire a CHI
## agisce, non sempre sull'host. Prima la barra dell'aumento la costruiva l'host -> "la scelta
## di aumentare era sempre da una parte (USA)" e il Focus sembrava fuori sync. Ora _prep_idx /
## _prep_awaiting_increase sono sincronizzati e le barre si ricostruiscono per il giocatore di turno.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_prep.gd

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

	# Forza la PREPARAZIONE guidata sul turno della CINA (seggio 1, il client).
	host.gs.round = 2
	host.gs.turn_order.assign([0, 1])
	host._ui_phase = "Preparazione"
	host.gs.phase = WO.Phase.PREPARATION
	host._prep_idx = 1
	host.active_seat = 1
	host._prep_awaiting_increase = false
	host.gs.players[1].money = 100   # così l'Aumento Produzione ha opzioni accessibili
	host._after_change()
	await process_frame

	# 1) Il client riceve _prep_idx/active_seat e apre la PROPRIA plancia con la barra del Focus.
	var s1: bool = client._prep_idx == 1 and client.active_seat == 1 \
		and client._ui_phase == "Preparazione" and client.drawer_open \
		and client.choice_flow.get_child_count() > 0
	print("[%s] client in Preparazione: plancia aperta + barra Focus (drawer=%s, barra=%d)" % [
		"OK" if s1 else "FAIL", str(client.drawer_open), client.choice_flow.get_child_count()])
	if not s1: fails += 1

	# 2) Il client sceglie il Focus -> si apre la PRODUZIONE del Focus (Produce UI), sincronizzata
	#    a CHI agisce (il client). La produzione non e' piu' automatica.
	client.apply_command(GameCommands.choose_focus(1, 1, 0))   # Domestic
	await process_frame
	var s2: bool = host._produce_mode and client._produce_mode and host._produce_after == "prep" \
		and not host._prep_awaiting_increase
	print("[%s] dopo il Focus: Produce del Focus aperta e sincronizzata (host=%s, client=%s)" % [
		"OK" if s2 else "FAIL", str(host._produce_mode), str(client._produce_mode)])
	if not s2: fails += 1

	# 2b) Il client conferma la produzione (anche a 0) -> ora si offre l'Aumento Produzione.
	client.apply_command(GameCommands.produce(1, 2, {}))
	await process_frame
	var s2b: bool = host._prep_awaiting_increase and client._prep_awaiting_increase and not host._produce_mode
	print("[%s] dopo la Produce -> Aumento Produzione in attesa (host=%s, client=%s)" % [
		"OK" if s2b else "FAIL", str(host._prep_awaiting_increase), str(client._prep_awaiting_increase)])
	if not s2b: fails += 1

	# 3) La barra dell'aumento è sul CLIENT (più bottoni), NON sull'host (USA, non di turno).
	var client_bar: int = client.choice_flow.get_child_count()
	var host_bar: int = host.choice_flow.get_child_count()
	var s3: bool = client_bar > 1 and host_bar == 0
	print("[%s] barra Aumento sul client (%d controlli), NON sull'host (%d)" % [
		"OK" if s3 else "FAIL", client_bar, host_bar])
	if not s3: fails += 1

	# 4) Il client salta l'aumento -> la Preparazione avanza (qui finisce: inizia l'Azione).
	client.apply_command(GameCommands.increase_production(1, 3, ""))
	await process_frame
	var s4: bool = host._ui_phase == "Azione" and client._ui_phase == "Azione"
	print("[%s] dopo l'aumento la Preparazione avanza (host fase=%s, client fase=%s)" % [
		"OK" if s4 else "FAIL", host._ui_phase, client._ui_phase])
	if not s4: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Preparazione (Focus + Aumento) in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
