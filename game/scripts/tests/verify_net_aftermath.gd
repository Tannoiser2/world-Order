extends SceneTree
## Regressione: fase AFTERMATH in rete (host <-> client via loopback).
## In Aftermath "chi agisce" NON è active_seat ma il giocatore in scelta: questo dato deve
## essere sincronizzato al client, sia per l'attribuzione dei comandi sia perché il client
## possa vedere/usare la barra delle scelte (e non bloccare la partita a fine round).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_aftermath.gd

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

	host._ui_phase = "Aftermath"

	# --- Aftermath: tocca a USA (seggio 0, l'host) ---
	host._aftermath_idx = 0
	host._show_aftermath_choices(host.gs.players[0])   # broadcast via _after_change
	await process_frame

	var a0: bool = client._acting_seat() == 0 and client._aftermath_choice_p == client.gs.players[0]
	print("[%s] client conosce il giocatore Aftermath (USA, seggio %d)" % ["OK" if a0 else "FAIL", client._acting_seat()])
	if not a0: fails += 1

	# Il client (china, seggio 1) NON può chiudere l'Aftermath di USA: input scartato.
	var sent_wrong: bool = client.apply_command(GameCommands.aftermath_continue(0, 1))
	await process_frame
	var a1: bool = (not sent_wrong) and host._aftermath_idx == 0
	print("[%s] client non agisce sull'Aftermath altrui (inviato=%s, idx host=%d)" % [
		"OK" if a1 else "FAIL", str(sent_wrong), host._aftermath_idx])
	if not a1: fails += 1

	# --- Aftermath: ora tocca a CHINA (seggio 1, il client) ---
	host._aftermath_idx = 1
	host._show_aftermath_choices(host.gs.players[1])
	await process_frame

	var a2: bool = client._acting_seat() == 1 and client._aftermath_choice_p == client.gs.players[1]
	print("[%s] client riconosce il PROPRIO turno di Aftermath (seggio %d)" % ["OK" if a2 else "FAIL", client._acting_seat()])
	if not a2: fails += 1

	# Il client RICOSTRUISCE la barra delle scelte (vede «Continua»): prima si bloccava.
	var a3: bool = client.choice_bar.visible and client.choice_flow.get_child_count() > 0
	print("[%s] client vede la barra Aftermath (%d controlli)" % ["OK" if a3 else "FAIL", client.choice_flow.get_child_count()])
	if not a3: fails += 1

	# Il client chiude il PROPRIO Aftermath: comando accettato dall'host (idx avanza).
	var sent_ok: bool = client.apply_command(GameCommands.aftermath_continue(1, 2))
	await process_frame
	var a4: bool = sent_ok and host._aftermath_idx == 2
	print("[%s] client chiude il proprio Aftermath: accettato (inviato=%s, idx host=%d)" % [
		"OK" if a4 else "FAIL", str(sent_ok), host._aftermath_idx])
	if not a4: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Aftermath in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
