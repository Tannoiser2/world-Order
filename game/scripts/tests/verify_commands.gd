extends SceneTree
## Verifica headless del COMMAND BUS (Step A): gli input di gioco choose_focus /
## play_card / end_turn passano per board.apply_command(), con validazione di forma
## e gating per seggio. Vedi docs/multiplayer-design.md.
## Uso: godot --headless --path game --script res://scripts/tests/verify_commands.gd

func _init() -> void:
	var fails := 0
	var check := func(name: String, cond: bool) -> void:
		print("[%s] %s" % ["OK" if cond else "FAIL", name])
		if not cond:
			fails += 1

	GameConfig.powers = ["usa", "china", "russia", "eu"]
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	# Aspetta che _ready() crei gs (altrimenti _begin_action_phase troverebbe gs == null).
	for _i in range(6):
		await process_frame
	board._begin_action_phase()   # fase Azione (round 1, focus Domestic)
	await process_frame
	await process_frame

	var n: int = board.gs.players.size()

	# 1) Forma: comandi malformati rifiutati.
	check.call("comando vuoto rifiutato", board.apply_command({}) == false)
	check.call("type sconosciuto rifiutato",
		board.apply_command({"type": "bogus", "seat": board.active_seat, "seq": 1, "args": {}}) == false)
	check.call("focus fuori range rifiutato (shape)",
		GameCommands.valid_shape(GameCommands.choose_focus(0, 1, 9)) == false)

	# 2) Gating: comando da un seggio NON attivo rifiutato, nessun effetto.
	var other: int = (board.active_seat + 1) % n
	var rtc_before: int = board.round_turn_count
	check.call("comando fuori turno rifiutato",
		board.apply_command(GameCommands.end_turn(other, board._next_seq())) == false)
	check.call("fuori turno: nessun avanzamento", board.round_turn_count == rtc_before)

	# 3) end_turn dal seggio attivo: avanza il conteggio turni e cambia seggio.
	board.playing_card = {}
	var seat0: int = board.active_seat
	var ok_end: bool = board.apply_command(GameCommands.end_turn(seat0, board._next_seq()))
	check.call("end_turn accettato", ok_end)
	check.call("end_turn: round_turn_count +1", board.round_turn_count == rtc_before + 1)
	check.call("end_turn: registrato nel command_log",
		board._command_log.size() > 0 and String(board._command_log.back()["type"]) == "end_turn")

	# 4) play_card dal seggio attivo: la carta entra in risoluzione (playing_card o
	#    awaiting impostati, oppure la mano cambia).
	var p = board._active()
	board._plays_left = 1
	board.playing_card = {}
	board.awaiting = ""
	var play_idx := -1
	for i in p.hand.size():
		if (p.hand[i] as Dictionary).has("effect_ops"):
			play_idx = i
			break
	if play_idx >= 0:
		var h_before: int = p.hand.size()
		var ok_play: bool = board.apply_command(GameCommands.play_card(board.active_seat, board._next_seq(), play_idx))
		var something_happened: bool = (not board.playing_card.is_empty()) or board.awaiting != "" or p.hand.size() < h_before
		check.call("play_card accettato", ok_play)
		check.call("play_card: la carta è entrata in gioco", something_happened)
	else:
		check.call("play_card: nessuna carta con effetto in mano (skip)", true)

	# 5) play_card con indice fuori range rifiutato.
	check.call("play_card indice fuori range rifiutato",
		board.apply_command(GameCommands.play_card(board.active_seat, board._next_seq(), 999)) == false)

	# 6) Sotto-scelte + use_ongoing: forma, gating, nessun effetto fuori contesto.
	board.playing_card = {}
	board.awaiting = ""
	check.call("pick_region shape ok", GameCommands.valid_shape(GameCommands.pick_region(0, 1, "europe")))
	check.call("pick_region shape: region vuota rifiutata",
		GameCommands.valid_shape(GameCommands.pick_region(0, 1, "")) == false)
	check.call("pick_influence_cell shape: slot valido",
		GameCommands.valid_shape(GameCommands.pick_influence_cell(0, 1, "europe", "permanent")))
	check.call("pick_influence_cell shape: slot non valido rifiutato",
		GameCommands.valid_shape(GameCommands.pick_influence_cell(0, 1, "europe", "boh")) == false)
	check.call("use_ongoing shape: tag vuoto rifiutato",
		GameCommands.valid_shape(GameCommands.use_ongoing(0, 1, "")) == false)
	check.call("exhaust_ally shape ok",
		GameCommands.valid_shape(GameCommands.exhaust_ally(0, 1, "country_x")))
	# pick_region senza carta in gioco: accettata dal bus ma SENZA effetto (come la UI).
	var pw: String = board._active().power
	var inf_before: int = board.gs.regions["europe"]["track"].count(pw)
	var ok_pr: bool = board.apply_command(GameCommands.pick_region(board.active_seat, board._next_seq(), "europe"))
	var inf_after: int = board.gs.regions["europe"]["track"].count(pw)
	check.call("pick_region accettata dal seggio attivo", ok_pr)
	check.call("pick_region senza carta: nessuna Influenza aggiunta", inf_after == inf_before)
	check.call("pick_region fuori turno rifiutata",
		board.apply_command(GameCommands.pick_region((board.active_seat + 1) % n, board._next_seq(), "europe")) == false)

	print("Verifica command bus: %s" % ("OK" if fails == 0 else "FALLITA (%d)" % fails))
	board.queue_free()
	await process_frame
	quit()
