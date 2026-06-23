extends SceneTree
## Audit follow-up: due azioni "condivise" che potevano finire sulla finestra sbagliata.
## A) AFTERMATH - scartare un Engage token: solo il giocatore di turno (Aftermath), non l'host.
## B) COMMERCIO dalla carta Trade Deals: l'avvio è instradato all'host (entra in trade_mode e
##    lo sincronizza), così il client compone davvero il Commercio invece di restare locale.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_audit2.gd

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

	# ---- A) AFTERMATH: token Engage della CINA (seggio 1), turno Aftermath della Cina ----
	var rid0 := String(host.gs.regions.keys()[0])
	host.gs.players[1].engage_tokens = [rid0]
	host._ui_phase = "Aftermath"
	host.gs.phase = WO.Phase.AFTERMATH
	host._aftermath_choice_p = host.gs.players[1]
	host._after_change()
	await process_frame

	# L'host (USA, NON di turno Aftermath) prova a scartare il token della Cina: IGNORATO.
	host._cmd_aftermath_token_money(host.gs.players[1], rid0)
	await process_frame
	var a1: bool = rid0 in host.gs.players[1].engage_tokens
	print("[%s] Aftermath: l'host non scarta il token della Cina (token presente=%s)" % [
		"OK" if a1 else "FAIL", str(a1)])
	if not a1: fails += 1

	# Il client (Cina, di turno Aftermath) scarta il proprio token: applicato e sincronizzato.
	client._cmd_aftermath_token_money(client.gs.players[1], rid0)
	await process_frame
	var a2: bool = not (rid0 in host.gs.players[1].engage_tokens) and not (rid0 in client.gs.players[1].engage_tokens)
	print("[%s] Aftermath: il client scarta il PROPRIO token (sparito su entrambi)" % ["OK" if a2 else "FAIL"])
	if not a2: fails += 1

	# Esci dall'Aftermath per la parte B.
	host._aftermath_choice_p = null
	host._ui_phase = "Azione"
	host.gs.phase = WO.Phase.ACTION
	host.active_seat = 1
	host._trade_mode = false
	host.playing_card = {}
	host._after_change()
	await process_frame

	# ---- B) COMMERCIO: avvio dalla carta Trade Deals instradato all'host ----
	# L'host (non di turno) prova ad avviare il Commercio della Cina: IGNORATO.
	host._cmd_begin_trade()
	await process_frame
	var b1: bool = not host._trade_mode
	print("[%s] Commercio: l'host non avvia il Commercio nel turno del client (trade_mode host=%s)" % [
		"OK" if b1 else "FAIL", str(host._trade_mode)])
	if not b1: fails += 1

	# Il client (di turno) avvia il Commercio: l'host entra in trade_mode e lo sincronizza.
	client._cmd_begin_trade()
	await process_frame
	var b2: bool = host._trade_mode and client._trade_mode
	print("[%s] Commercio: avvio del client -> trade_mode su entrambi (host=%s, client=%s)" % [
		"OK" if b2 else "FAIL", str(host._trade_mode), str(client._trade_mode)])
	if not b2: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica audit (Aftermath token + avvio Commercio) in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
