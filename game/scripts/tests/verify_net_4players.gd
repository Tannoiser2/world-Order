extends SceneTree
## 4 GIOCATORI: 1 host + 3 client. Verifica che il broadcast dell'host raggiunga e sincronizzi
## TUTTI i client (non solo il primo). Bug dal vivo: in 4 giocatori i seggi 2 e 3 (Russia/Europa)
## non aggiornavano nulla (mappa, segnalini, ordine di turno, PV) -> restavano sul setup locale.
## I test esistenti erano tutti a 2 giocatori, quindi un problema multi-client sfuggiva.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_4players.gd

func _init() -> void:
	var fails := 0

	var powers := ["usa", "china", "russia", "eu"]
	var host_net := NetSession.new()
	host_net.host_loopback()
	host_net.powers = powers
	get_root().add_child(host_net)

	var client_nets := []
	for i in 3:
		var cn := NetSession.new()
		NetSession.link_loopback(host_net, cn)
		cn.powers = powers
		get_root().add_child(cn)
		client_nets.append(cn)

	var board_packed: PackedScene = load("res://scenes/board.tscn")

	GameConfig.net = host_net
	GameConfig.powers = powers
	var host: Variant = board_packed.instantiate()
	get_root().add_child(host)
	await process_frame

	var clients := []
	for cn in client_nets:
		GameConfig.net = cn
		var c: Variant = board_packed.instantiate()
		get_root().add_child(c)
		await process_frame
		clients.append(c)
	GameConfig.net = null

	# L'host impone uno stato DISTINTIVO e lo ribroadcasta.
	host.active_seat = 2
	host.gs.players[3].victory_points = 42   # PV distintivi per il seggio 3 (Europa)
	host.gs.round = 1
	host._net_sync()
	await process_frame
	await process_frame

	# Ogni client (seggi 1,2,3) deve riflettere lo stato dell'host: active_seat E i PV.
	for i in clients.size():
		var seat := i + 1
		var c: Variant = clients[i]
		var ok_seat: bool = c.active_seat == 2
		var ok_vp: bool = c.gs.players[3].victory_points == 42
		var ok: bool = ok_seat and ok_vp
		print("[%s] client seggio %d sincronizzato (active_seat=%d, PV[3]=%d)" % [
			"OK" if ok else "FAIL", seat, c.active_seat, c.gs.players[3].victory_points])
		if not ok: fails += 1

	# Il HEARTBEAT (ribroadcast periodico) deve riallineare un client rimasto indietro: lo
	# forzo "indietro" e batto il colpo.
	var laggard: Variant = clients[2]   # seggio 3 (Europa), quello che dal vivo non si aggiornava
	laggard.active_seat = 0
	laggard._last_snapshot_sig = 0
	host.active_seat = 1
	host._net_sync()
	await process_frame
	var healed: bool = laggard.active_seat == 1
	print("[%s] heartbeat riallinea il seggio 3 rimasto indietro (active_seat=%d)" % [
		"OK" if healed else "FAIL", laggard.active_seat])
	if not healed: fails += 1

	host.queue_free()
	for c in clients:
		c.queue_free()
	await process_frame

	print("Verifica 4 giocatori (sync di tutti i client): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
