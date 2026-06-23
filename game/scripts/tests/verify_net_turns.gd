extends SceneTree
## Regressione: SEQUENZA DEI TURNI in rete (host <-> client via loopback).
## Riproduce il bug "un giocatore avanti, l'altro bloccato": un input del CLIENT inviato
## fuori dal proprio turno NON deve essere attribuito al giocatore di turno, e i passaggi
## di turno/fase devono restare sincronizzati tra host e client.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_turns.gd

func _init() -> void:
	var fails := 0

	# host (seggio 0 = usa) + client (seggio 1 = china) via loopback
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

	# Stato deterministico: fase Azione, turno di USA (seggio 0). Mani vuote così "Fine turno"
	# non richiede di giocare una carta. turn_order [0,1].
	host.gs.turn_order.assign([0, 1])
	host.active_seat = 0
	host.round_turn_count = 0
	host._ui_phase = "Azione"
	host.gs.players[0].hand.clear()
	host.gs.players[1].hand.clear()
	host._played_this_turn = true
	host._net_sync()
	await process_frame

	# Il client riceve: tocca a USA (seggio 0).
	var c0: bool = client.active_seat == 0
	print("[%s] setup: client allineato sul turno di USA (active_seat=%d)" % ["OK" if c0 else "FAIL", client.active_seat])
	if not c0: fails += 1

	# 1) BUG STORICO: il CLIENT (china, seggio 1) tocca "Fine turno" mentre tocca a USA.
	#    Il vecchio codice taggava il comando con active_seat (0) -> l'host chiudeva il turno
	#    di USA! Ora il client non lo invia nemmeno (seggio != mio) e comunque l'host lo
	#    scarterebbe. L'active_seat dell'host NON deve cambiare.
	var sent: bool = client.apply_command(GameCommands.end_turn(0, 1))
	await process_frame
	var ok1: bool = (not sent) and host.active_seat == 0
	print("[%s] input del client fuori turno IGNORATO (inviato=%s, host active_seat=%d)" % [
		"OK" if ok1 else "FAIL", str(sent), host.active_seat])
	if not ok1: fails += 1

	# 2) Difesa lato HOST: anche un comando "grezzo" dal client autenticato come seggio 1
	#    ma che dichiara seat 0 viene forzato al mittente (1) e scartato dal gating.
	host._on_net_command(1, GameCommands.end_turn(0, 2))
	await process_frame
	var ok2: bool = host.active_seat == 0
	print("[%s] host forza il seggio del mittente: comando spacciato per USA scartato (active_seat=%d)" % [
		"OK" if ok2 else "FAIL", host.active_seat])
	if not ok2: fails += 1

	# 3) Passaggio di turno LEGITTIMO: USA (host) chiude il turno -> tocca a China; il client
	#    deve riceverlo. Poi China (client) chiude il proprio turno -> torna a USA, in sync.
	host._cmd_end_turn()                       # USA chiude: active_seat 0 -> 1
	await process_frame
	var ok3a: bool = host.active_seat == 1 and client.active_seat == 1
	print("[%s] USA chiude il turno: host=%d, client=%d (tocca a China)" % [
		"OK" if ok3a else "FAIL", host.active_seat, client.active_seat])
	if not ok3a: fails += 1

	client.apply_command(GameCommands.end_turn(1, 3))   # China chiude (legittimo)
	await process_frame
	var ok3b: bool = host.active_seat == 0 and client.active_seat == 0
	print("[%s] China chiude il turno: host=%d, client=%d (torna a USA)" % [
		"OK" if ok3b else "FAIL", host.active_seat, client.active_seat])
	if not ok3b: fails += 1

	# 4) Avanzamento NON da comando (fase): l'host entra in Azione via _begin_action_phase
	#    (turn_order [1,0] -> active_seat 1). Il client deve sincronizzarsi grazie al
	#    broadcast in _after_change.
	host.gs.turn_order.assign([1, 0])
	host._begin_action_phase()
	await process_frame
	var ok4: bool = host.active_seat == 1 and client.active_seat == 1
	print("[%s] avanzamento di fase (non da comando) sincronizzato: host=%d, client=%d" % [
		"OK" if ok4 else "FAIL", host.active_seat, client.active_seat])
	if not ok4: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica sequenza turni in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
