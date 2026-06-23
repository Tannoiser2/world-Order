extends SceneTree
## Riepilogo di fine round ("le conseguenze": THREAT, Scoring, Token Maggioranza) in rete.
## Prima era un popup costruito SOLO dall'host: il client non vedeva mai le conseguenze
## ("tutte le conseguenze fuori sync"). Ora è uno stato SINCRONIZZATO: lo vedono entrambi e
## il "Continua" (avanza il round) passa dall'host. Verifica sync, rendering su entrambi e
## che il "Continua" del client faccia avanzare il round.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_summary.gd

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

	var round0: int = host.gs.round

	# Porta l'Aftermath fino al RIEPILOGO: ogni giocatore "Continua", poi si risolve.
	host._run_aftermath()
	await process_frame
	host._aftermath_continue()   # giocatore 0 -> 1
	await process_frame
	host._aftermath_continue()   # giocatore 1 -> risoluzione + riepilogo
	await process_frame

	# 1) Il riepilogo è attivo e SINCRONIZZATO su entrambi (stesse righe).
	var s1: bool = not host._summary.is_empty() and not client._summary.is_empty() \
		and (host._summary.get("lines", []) as Array).size() == (client._summary.get("lines", []) as Array).size() \
		and (client._summary.get("lines", []) as Array).size() > 0
	print("[%s] riepilogo sincronizzato (host=%d righe, client=%d righe)" % [
		"OK" if s1 else "FAIL",
		(host._summary.get("lines", []) as Array).size(),
		(client._summary.get("lines", []) as Array).size()])
	if not s1: fails += 1

	# 2) È un recap CONDIVISO: il pannello è costruito su ENTRAMBE le viste (non solo sull'host).
	var s2: bool = host._summary_shown and client._summary_shown
	print("[%s] pannello costruito su entrambi (host_shown=%s, client_shown=%s)" % [
		"OK" if s2 else "FAIL", str(host._summary_shown), str(client._summary_shown)])
	if not s2: fails += 1

	# 3) Il "Continua" del CLIENT avanza il round (autorità host) e chiude il recap ovunque.
	var sent: bool = client.apply_command(GameCommands.summary_continue(1, 1))
	await process_frame
	var advanced: bool = host.gs.round == round0 + 1
	var closed: bool = host._summary.is_empty() and client._summary.is_empty() \
		and not host._summary_shown and not client._summary_shown
	print("[%s] 'Continua' del client: round %d->%d, recap chiuso ovunque (inviato=%s)" % [
		"OK" if (sent and advanced and closed) else "FAIL", round0, host.gs.round, str(sent)])
	if not (sent and advanced and closed): fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica riepilogo conseguenze in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
