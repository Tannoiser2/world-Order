extends SceneTree
## Bot ONLINE (host-authoritative): in rete i Bot li guida l'HOST; i client li ricevono già
## risolti via snapshot (non eseguono mai la logica Automa). Copre:
##   - propagazione dei seggi-bot (net.automa) dall'host al client nel messaggio "start";
##   - l'host crea lo stato Automa, il client NO (ma sa che il seggio è un Bot, per mostrarlo);
##   - quando tocca al Bot, l'host esegue la sua azione e l'avanzamento si sincronizza al client.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_bot.gd

func _seat(b: Variant, power: String) -> int:
	for i in b.gs.players.size():
		if b.gs.players[i].power == power:
			return i
	return -1

func _init() -> void:
	var fails := 0
	var powers := ["usa", "eu", "china"]

	var host_net := NetSession.new(); host_net.host_loopback()
	var client_net := NetSession.new(); NetSession.link_loopback(host_net, client_net)
	get_root().add_child(host_net); get_root().add_child(client_net)

	# 1) Propagazione: l'host avvia con china = Bot; il client riceve net.automa nel "start".
	host_net.start_game(powers, ["china"])
	await process_frame
	var prop_ok: bool = host_net.automa == ["china"] and client_net.automa == ["china"]
	print("[%s] propagazione net.automa host=%s client=%s" % ["OK" if prop_ok else "FAIL", str(host_net.automa), str(client_net.automa)])
	if not prop_ok: fails += 1

	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.powers = powers
	GameConfig.automa_powers = ["china"]
	GameConfig.automa_difficulty = "normal"
	GameConfig.net = host_net
	var host: Variant = bp.instantiate(); get_root().add_child(host); await process_frame
	GameConfig.net = client_net
	var client: Variant = bp.instantiate(); get_root().add_child(client); await process_frame
	GameConfig.net = null

	# 2) L'host tiene lo stato Automa di china; il client NO (lo riceve via snapshot).
	var setup_ok: bool = host._automa.has("china") and client._automa.is_empty()
	print("[%s] setup Automa: host ha china=%s, client vuoto=%s" % [
		"OK" if setup_ok else "FAIL", str(host._automa.has("china")), str(client._automa.is_empty())])
	if not setup_ok: fails += 1
	# Il client comunque SA che china è un Bot (per banner/etichette).
	var client_knows: bool = GameConfig.is_automa("china")
	print("[%s] il client riconosce china come Bot (per mostrarlo)" % ["OK" if client_knows else "FAIL"])
	if not client_knows: fails += 1

	# 3) Turno del Bot: l'host esegue l'azione di china e l'avanzamento arriva al client.
	var ci: int = _seat(host, "china")
	host._ui_phase = "Azione"; host.gs.phase = WO.Phase.ACTION
	host.gs.turn_order.assign([ci, 0]); host.round_turn_count = 0; host.active_seat = ci
	host.gs.players[ci].money = 200
	host.gs.players[ci].allied_countries = [{"id": "x", "region": "europe", "exports": ["food", "energy"]}]
	host._played_this_turn = false
	host._automa_run()
	await process_frame
	await process_frame
	var advanced: bool = host.active_seat == 0 and host.round_turn_count == 1
	print("[%s] host guida il Bot: turno di china concluso (active=%d, count=%d)" % [
		"OK" if advanced else "FAIL", host.active_seat, host.round_turn_count])
	if not advanced: fails += 1
	var synced: bool = client.active_seat == host.active_seat
	print("[%s] sincronizzazione: il client vede l'avanzamento del Bot (client.active=%d)" % [
		"OK" if synced else "FAIL", client.active_seat])
	if not synced: fails += 1

	# 4) Gating: il client NON esegue mai la logica del Bot (il driver esce subito).
	var c_active0: int = client.active_seat
	client._automa_run()
	var gated: bool = client.active_seat == c_active0
	print("[%s] il client non esegue i Bot (driver inattivo sul client)" % ["OK" if gated else "FAIL"])
	if not gated: fails += 1

	host.queue_free(); client.queue_free()
	await process_frame
	GameConfig.automa_powers = []
	print("Verifica Bot online (host-authoritative): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
