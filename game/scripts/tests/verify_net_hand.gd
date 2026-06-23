extends SceneTree
## Regressione: NIENTE leak della mano in rete + identità del giocatore locale.
## La mano disegnata deve essere quella del giocatore LOCALE (net.my_seat), non quella del
## giocatore di turno: prima l'host vedeva la mano del client quando toccava al client.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_hand.gd

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

	# Mani distinte e turno della CINA (client, seggio 1).
	while host.gs.players[0].hand.size() > 3:
		host.gs.players[0].hand.pop_back()
	while host.gs.players[1].hand.size() > 1:
		host.gs.players[1].hand.pop_back()
	host.active_seat = 1
	host._net_sync()
	await process_frame

	# 1) L'host mostra la PROPRIA mano (USA, seggio 0) anche se tocca alla Cina (seggio 1).
	var h1: bool = host._view_seat() == 0 and host._view_player() == host.gs.players[0]
	print("[%s] host mostra la propria mano (USA) durante il turno della Cina (view_seat=%d, active=%d)" % [
		"OK" if h1 else "FAIL", host._view_seat(), host.active_seat])
	if not h1: fails += 1

	# 2) Il client mostra la propria mano (Cina, seggio 1).
	var h2: bool = client._view_seat() == 1 and client._view_player() == client.gs.players[1]
	print("[%s] client mostra la propria mano (Cina) (view_seat=%d)" % ["OK" if h2 else "FAIL", client._view_seat()])
	if not h2: fails += 1

	# 3) Redazione: il client non possiede affatto la mano dell'avversario (USA).
	var h3: bool = (client.gs.players[0].hand as Array).is_empty()
	print("[%s] il client NON ha la mano dell'avversario (USA coperta)" % ["OK" if h3 else "FAIL"])
	if not h3: fails += 1

	# 4) Turno: l'host non può agire/chiudere il turno della Cina; il client sì.
	var h4: bool = host._is_my_turn() == false and client._is_my_turn() == true
	print("[%s] gating turno: host _is_my_turn=%s, client _is_my_turn=%s" % [
		"OK" if h4 else "FAIL", str(host._is_my_turn()), str(client._is_my_turn())])
	if not h4: fails += 1

	# 5) Il distintivo identità (bandiera + "TU: …") si costruisce senza errori.
	host._refresh_hud(host._active())
	var h5: bool = host.hud_box.get_child_count() > 0
	print("[%s] distintivo identità costruito (HUD con %d elementi)" % ["OK" if h5 else "FAIL", host.hud_box.get_child_count()])
	if not h5: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica mano/identità in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
