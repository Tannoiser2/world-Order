extends SceneTree
## Regressione: composizione del COMMERCIO in rete. La resource track interattiva deve
## essere disponibile SOLO al giocatore locale nel proprio turno (prima entrambe le finestre
## mostravano la plancia del giocatore attivo interattiva, così l'host poteva comporre/validare
## il Commercio del client). Il client deve inoltre inizializzare la propria composizione.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_trade.gd

func _count_buttons(n: Node) -> int:
	var c := 0
	if n is Button:
		c += 1
	for ch in n.get_children():
		c += _count_buttons(ch)
	return c


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

	# L'host entra in Commercio per la CINA (client, seggio 1).
	host.active_seat = 1
	host._trade_sel = {"export": {}, "import": {}}
	host._trade_mode = true
	host._net_sync()
	await process_frame

	# 1) Il client entra in Commercio e INIZIALIZZA la propria composizione locale.
	var t1: bool = client._trade_mode and client._trade_sel.has("export") and client._trade_sel.has("import")
	print("[%s] client in Commercio con composizione inizializzata (sel=%s)" % ["OK" if t1 else "FAIL", str(client._trade_sel)])
	if not t1: fails += 1

	# 2) Gating: tocca alla Cina -> client interattivo, host no.
	var t2: bool = client._is_my_turn() == true and host._is_my_turn() == false
	print("[%s] interattività: client _is_my_turn=%s, host _is_my_turn=%s" % [
		"OK" if t2 else "FAIL", str(client._is_my_turn()), str(host._is_my_turn())])
	if not t2: fails += 1

	# 3) La resource track del Commercio è cliccabile SOLO sul client: la plancia della Cina
	#    costruita sul client ha più pulsanti (overlay Commercio) che sull'host (nessun overlay).
	var cv: Control = client._build_plancia_view(client.gs.players[1], true)
	var hv: Control = host._build_plancia_view(host.gs.players[1], true)
	var nb_c := _count_buttons(cv)
	var nb_h := _count_buttons(hv)
	var t3: bool = nb_c > nb_h
	print("[%s] plancia Commercio interattiva solo sul client (pulsanti client=%d, host=%d)" % [
		"OK" if t3 else "FAIL", nb_c, nb_h])
	if not t3: fails += 1
	cv.queue_free()
	hv.queue_free()

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Commercio in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
