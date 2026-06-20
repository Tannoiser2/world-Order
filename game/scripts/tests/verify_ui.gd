extends SceneTree
## Verifica headless che le scene UI si istanzino senza errori di script.
## Uso: godot --headless --path game --script res://scripts/tests/verify_ui.gd

func _init() -> void:
	var fails := 0

	# Menu principale.
	var menu_packed: PackedScene = load("res://scenes/main_menu.tscn")
	if menu_packed == null:
		print("[FAIL] main_menu.tscn non caricata"); fails += 1
	else:
		var menu := menu_packed.instantiate()
		get_root().add_child(menu)
		await process_frame
		var ok := menu.get_child_count() > 0
		print("[%s] main_menu.tscn istanziata (%d nodi)" % ["OK" if ok else "FAIL", menu.get_child_count()])
		if not ok: fails += 1
		menu.queue_free()
		await process_frame

	# Scena di gioco.
	var board_packed: PackedScene = load("res://scenes/board.tscn")
	if board_packed == null:
		print("[FAIL] board.tscn non caricata"); fails += 1
	else:
		var board := board_packed.instantiate()
		get_root().add_child(board)
		await process_frame
		await process_frame
		var n: int = board.overlay.get_child_count() if board.overlay else 0
		print("[%s] board.tscn istanziata; overlay Regioni: %d" % ["OK" if n == 7 else "FAIL", n])
		if n != 7: fails += 1
		# flusso di click: Engage in Europe (cost 5, il giocatore ha 8 Diplomacy)
		var before: int = board.gs.regions["europe"]["track"].count(board._active().power)
		board._on_region_pressed("europe")
		var after: int = board.gs.regions["europe"]["track"].count(board._active().power)
		var ok2 := after == before + 1
		print("[%s] click Regione -> Engage aggiunge Influenza (%d->%d)" % ["OK" if ok2 else "FAIL", before, after])
		if not ok2: fails += 1
		var hand_n: int = board._active().hand.size()
		print("[%s] mano del giocatore popolata (%d carte)" % ["OK" if hand_n > 0 else "FAIL", hand_n])
		if hand_n == 0: fails += 1

		# Gioco di una carta che richiede una Regione (Engage).
		var ac: PlayerState = board._active()
		ac.resources["diplomacy"] = 20  # isola il test dal consumo precedente
		var card_region := {"display_name": "Test Engage", "effect_ops": [{"op": "engage"}]}
		ac.hand.append(card_region)
		board._play_card(card_region)
		var aw_ok: bool = board.awaiting == "region"
		print("[%s] play carta Engage -> attende una Regione" % ["OK" if aw_ok else "FAIL"])
		if not aw_ok: fails += 1
		var inf_b: int = board.gs.regions["central_asia"]["track"].count(ac.power)
		board._on_region_pressed("central_asia")
		var inf_a: int = board.gs.regions["central_asia"]["track"].count(ac.power)
		var played_ok: bool = (card_region in ac.played) and not (card_region in ac.hand) and inf_a == inf_b + 1
		print("[%s] risoluzione carta Engage (Influenza %d->%d, carta in scarti)" % ["OK" if played_ok else "FAIL", inf_b, inf_a])
		if not played_ok: fails += 1

		# Carta auto-risolta (gain_money), nessun target.
		var money_b: int = ac.money
		var card_auto := {"display_name": "Test Money", "effect_ops": [{"op": "gain_money", "amount": 7}]}
		ac.hand.append(card_auto)
		board._play_card(card_auto)
		var auto_ok: bool = ac.money == money_b + 7 and (card_auto in ac.played) and board.playing_card.is_empty()
		print("[%s] carta auto (gain_money) risolta subito (+7 money)" % ["OK" if auto_ok else "FAIL"])
		if not auto_ok: fails += 1

	# Partita completa attraverso la UI (Fine turno / Continua fino alla fine).
	var b2: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(b2)
	await process_frame
	await process_frame
	var safety := 0
	while not b2.game_over and safety < 400:
		safety += 1
		var cont: Button = _find_button(b2.popup_layer, "Continua")
		if cont:
			cont.pressed.emit()
		else:
			b2._end_turn()
		await process_frame
	var win := GameRunner.winner(b2.gs)
	var game_ok: bool = b2.game_over and win != "" and b2.gs.round == GameState.TOTAL_ROUNDS
	print("[%s] partita completa via UI: round %d, vincitore %s (%d iter)" % [
		"OK" if game_ok else "FAIL", b2.gs.round, win, safety])
	if not game_ok: fails += 1

	print("Verifica UI: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(fails)


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	for c in node.get_children():
		if c is Button and text in (c as Button).text:
			return c
		var r := _find_button(c, text)
		if r:
			return r
	return null
