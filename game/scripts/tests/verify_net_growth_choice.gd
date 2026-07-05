extends SceneTree
## "Get a Growth Card" quando è avvolto in un "choice" (es. "Growth Strategy": scegli fra Get a
## Growth Card e Produce 3 tipi) - a differenza di verify_net_growth.gd, che gioca "get_growth"
## DIRETTO e non controlla che il selettore contenga DAVVERO delle carte (solo che il pannello
## si apra). Copre anche una 2a Growth nello stesso turno (stessa area del vecchio bug #19),
## qui però passando dalla rete E dal wrapper "choice", combinazione non ancora coperta prima.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_growth_choice.gd

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

	# Turno della Cina (client, seggio 1): carta "Growth Strategy" (choice: get_growth/produce).
	host.active_seat = 1
	host._plays_left = 1
	host._played_this_turn = false
	var china = host.gs.players[1]
	china.hand.clear()
	china.hand.append({"display_name": "Growth Strategy", "effect_ops": [
		{"op": "choice", "options": [[{"op": "get_growth"}], [{"op": "produce", "count": 3}]]}
	]})
	host._net_sync()
	await process_frame

	client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame
	var s1: bool = host._popup_active() and client._popup_active()
	print("[%s] popup scelta (Get a Growth Card / Produce) sincronizzato" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	client.apply_command(GameCommands.popup_choice(1, 2, 0))   # "Get a Growth Card"
	await process_frame
	var s2: bool = not host._growth_pick.is_empty() and not client._growth_pick.is_empty() \
		and client._growth_pick_shown
	print("[%s] selettore Growth sincronizzato e mostrato sul client (host_pick=%s, client_pick=%s, client_shown=%s)" % [
		"OK" if s2 else "FAIL", str(host._growth_pick), str(client._growth_pick), str(client._growth_pick_shown)])
	if not s2: fails += 1

	# Verifica che il selettore mostri DAVVERO delle carte (rendering reale), non solo che il
	# pannello sia aperto (verify_net_growth.gd controllava solo quello).
	var avail: Array = client._available_growth(client._active())
	var card_btn := _find_buy_growth_button(client.popup_layer)
	var s3: bool = avail.size() > 0 and card_btn != null
	print("[%s] il selettore mostra DAVVERO almeno una carta Growth (avail=%d, bottone trovato=%s)" % [
		"OK" if s3 else "FAIL", avail.size(), str(card_btn != null)])
	if not s3: fails += 1

	# Compro la 1a Growth e rigioco subito una 2a "Growth Strategy" nello stesso turno (l'area
	# del vecchio bug #19: "la 2a carta Get a Growth non fa scegliere"), qui via rete + "choice".
	if card_btn != null:
		card_btn.pressed.emit()
		await process_frame
	# La Growth acquistata può avere un proprio effetto immediato (es. "Aumenta 2 Produzioni") da
	# risolvere prima che "Growth Strategy" sia davvero conclusa: lo risolvo per intero via rete.
	while host._free_increase_remaining > 0:
		var rt := ""
		for r in host.RES:
			if not (r in host._free_increase_done):
				rt = r
				break
		client.apply_command(GameCommands.free_increase_pick(1, client._next_seq(), rt))
		await process_frame

	host._plays_left = 1
	china.money = 999
	for r in host.RES:
		china.resources[r] = 10
	china.hand.clear()
	china.hand.append({"display_name": "Growth Strategy 2", "effect_ops": [
		{"op": "choice", "options": [[{"op": "get_growth"}], [{"op": "produce", "count": 3}]]}
	]})
	host._net_sync()
	await process_frame

	client.apply_command(GameCommands.play_card(1, client._next_seq(), 0))
	await process_frame
	client.apply_command(GameCommands.popup_choice(1, client._next_seq(), 0))   # "Get a Growth Card" di nuovo
	await process_frame

	var avail2: Array = client._available_growth(client._active())
	var card_btn2 := _find_buy_growth_button(client.popup_layer)
	var s4: bool = client._growth_pick_shown and avail2.size() > 0 and card_btn2 != null
	print("[%s] 2a Growth nello stesso turno: selettore mostra DAVVERO delle carte (avail=%d, shown=%s, bottone=%s)" % [
		"OK" if s4 else "FAIL", avail2.size(), str(client._growth_pick_shown), str(card_btn2 != null)])
	if not s4: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Growth Strategy (choice -> get_growth) in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)


func _find_buy_growth_button(node: Node) -> Button:
	if node is Button and (node as Button).pressed.get_connections().size() > 0:
		for conn in (node as Button).pressed.get_connections():
			var cb: Callable = conn["callable"]
			if cb.get_method() == "_cmd_buy_growth":
				return node
	for c in node.get_children():
		var f := _find_buy_growth_button(c)
		if f != null:
			return f
	return null
