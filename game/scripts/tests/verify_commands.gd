extends SceneTree
## Verifica headless del COMMAND BUS (Step A): gli input di gioco choose_focus /
## play_card / end_turn passano per board.apply_command(), con validazione di forma
## e gating per seggio. Vedi docs/multiplayer-design.md.
## Uso: godot --headless --path game --script res://scripts/tests/verify_commands.gd

func _init() -> void:
	# NB: il contatore deve stare in un Dictionary (riferimento): un int locale verrebbe
	# CATTURATO PER VALORE dalla lambda e i FAIL non si propagherebbero al riepilogo.
	var cnt := {"fails": 0}
	var check := func(name: String, cond: bool) -> void:
		print("[%s] %s" % ["OK" if cond else "FAIL", name])
		if not cond:
			cnt["fails"] += 1

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
	board._played_this_turn = true   # simula che la carta del turno e' gia' stata giocata
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

	# 7) Acquisti (growth/market) + Aftermath: forma e gating per fase.
	check.call("buy_growth shape ok", GameCommands.valid_shape(GameCommands.buy_growth(0, 1, "growth_x")))
	check.call("buy_market shape: id vuoto rifiutato",
		GameCommands.valid_shape(GameCommands.buy_market(0, 1, "")) == false)
	check.call("aftermath_token shape: kind valido",
		GameCommands.valid_shape(GameCommands.aftermath_token(0, 1, "europe", "money")))
	check.call("aftermath_token shape: kind non valido rifiutato",
		GameCommands.valid_shape(GameCommands.aftermath_token(0, 1, "europe", "boh")) == false)
	check.call("aftermath_continue shape ok", GameCommands.valid_shape(GameCommands.aftermath_continue(0, 1)))
	# Fuori dall'Aftermath i comandi aftermath_* sono rifiutati (guardia _aftermath_choice_p).
	check.call("aftermath_continue fuori fase rifiutato",
		board.apply_command(GameCommands.aftermath_continue(board.active_seat, board._next_seq())) == false)
	# _acting_seat() segue il giocatore Aftermath quando attivo, altrimenti = active_seat.
	board._aftermath_choice_p = board.gs.players[2]
	check.call("_acting_seat segue il giocatore Aftermath", board._acting_seat() == 2)
	board._aftermath_choice_p = null
	check.call("_acting_seat fuori Aftermath = active_seat", board._acting_seat() == board.active_seat)

	# 8) Increase Production (passo Choose Focus della Preparazione).
	check.call("increase_production shape: type vuoto ammesso (salta)",
		GameCommands.valid_shape(GameCommands.increase_production(0, 1, "")))
	check.call("increase_production shape ok",
		GameCommands.valid_shape(GameCommands.increase_production(0, 1, "diplomacy")))
	board.playing_card = {}
	board.awaiting = ""
	board.gs.round = 2
	var pp = board.gs.players[board.gs.turn_order[0]]
	pp.money = 20
	pp.production = {"energy":1,"raw_materials":1,"food":1,"consumer_goods":1,"services":1,"diplomacy":1,"armies":1}
	board._begin_preparation()
	for _i in range(2): await process_frame
	var seatp: int = board.active_seat
	var dipl0: int = int(pp.production.get("diplomacy", 0))
	var idxp0: int = board._prep_idx
	# Diplomatic (f=1): produce Diplomazia e OFFRE l'aumento (non avanza ancora).
	board.apply_command(GameCommands.choose_focus(seatp, board._next_seq(), 1))
	for _i in range(2): await process_frame
	check.call("choose_focus in prep: offre aumento, non avanza", board._prep_idx == idxp0)
	# Aumenta la Produzione di Diplomazia: +1 alla traccia e avanza la preparazione.
	board.apply_command(GameCommands.increase_production(seatp, board._next_seq(), "diplomacy"))
	for _i in range(2): await process_frame
	check.call("increase_production: +1 traccia Diplomazia", int(pp.production.get("diplomacy", 0)) == dipl0 + 1)
	check.call("increase_production: avanza la preparazione", board._prep_idx == idxp0 + 1)

	# 9) Effetti carte: 'repeat' esegue il body `times` volte (espansione nella coda).
	board.playing_card = {"display_name": "TestRepeat", "effect_ops": []}
	board.play_queue = [{"op": "repeat", "times": 2, "body": [{"op": "gain_money", "amount": 5}]}]
	var rp = board._active()
	var m0r: int = rp.money
	board._advance_play()
	check.call("repeat: body eseguito 2 volte (+10 money)", rp.money == m0r + 10)

	# 10) 'Fine turno' bloccato finché non si gioca (o si passa) una carta.
	board._ui_phase = "Azione"
	board.playing_card = {}
	board.awaiting = ""
	board._plays_left = 1
	board._played_this_turn = false
	board.game_over = false
	var ap = board._active()
	if ap.hand.is_empty():
		ap.hand = [{"display_name": "X", "effect_ops": []}]
	var rtc_e: int = board.round_turn_count
	board._end_turn()
	check.call("end_turn BLOCCATO senza aver giocato", board.round_turn_count == rtc_e)
	board._play_facedown_money(ap.hand[0])   # passa: +10 money
	check.call("dopo aver passato: _played_this_turn vero", board._played_this_turn)
	board._end_turn()
	check.call("end_turn ora CONSENTITO", board.round_turn_count == rtc_e + 1)

	# 11) Rete: snapshot dello stato di INTERAZIONE (awaiting/influence_pick) round-trip.
	board.awaiting = "region"
	board.awaiting_op = {"op": "engage"}
	board._ui_phase = "Azione"
	board.playing_card = {"display_name": "C"}
	board._influence_pick = {"regions": ["europe", "africa"], "force": "permanent"}
	var snap_ui: Dictionary = board._ui_snapshot()
	check.call("ui_snapshot: cattura awaiting", String(snap_ui.get("awaiting", "")) == "region")
	check.call("ui_snapshot: cattura influence_pick",
		(snap_ui.get("influence_pick", {}).get("regions", []) as Array).size() == 2)
	board.awaiting = ""; board.awaiting_op = {}; board.playing_card = {}; board._influence_pick = {}
	board._apply_ui_snapshot(snap_ui)
	check.call("apply_ui_snapshot: ripristina awaiting", board.awaiting == "region")
	check.call("apply_ui_snapshot: playing segnaposto", not board.playing_card.is_empty())
	check.call("apply_ui_snapshot: ripristina influence_pick",
		(board._influence_pick.get("regions", []) as Array).size() == 2)

	# 12) Azioni a payload pieno: produce / trade / move_army / move_finish.
	check.call("produce shape ok", GameCommands.valid_shape(GameCommands.produce(0, 1, {"energy": 2})))
	check.call("produce shape: sel non-dict rifiutato",
		GameCommands.valid_shape(GameCommands.make("produce", 0, 1, {})) == false)
	check.call("trade shape ok",
		GameCommands.valid_shape(GameCommands.trade(0, 1, {"energy": 2}, {"food": 1}, {"food": "reserve"}, 0)))
	check.call("trade shape: armies non-int rifiutato",
		GameCommands.valid_shape(GameCommands.make("trade", 0, 1, {"export": {}, "import": {}, "import_src": {}, "armies": "x"})) == false)
	check.call("move_army shape ok", GameCommands.valid_shape(GameCommands.move_army(0, 1, "_reserve", "europe")))
	check.call("move_army shape: dest vuota rifiutata",
		GameCommands.valid_shape(GameCommands.move_army(0, 1, "europe", "")) == false)
	check.call("move_finish shape ok", GameCommands.valid_shape(GameCommands.move_finish(0, 1)))
	# Gating per stato: produce/trade rifiutati se la rispettiva modalità non è attiva.
	board._produce_mode = false
	board._trade_mode = false
	board.awaiting = ""
	check.call("produce rifiutato fuori dalla modalità Produce",
		board.apply_command(GameCommands.produce(board.active_seat, board._next_seq(), {"energy": 1})) == false)
	check.call("move_army rifiutato fuori dalla fase Move",
		board.apply_command(GameCommands.move_army(board.active_seat, board._next_seq(), "_reserve", "europe")) == false)
	# move_ctx: round-trip nello snapshot di interazione (per pilotare il client nel Move).
	board._move_ctx = {"free": false, "max": 3, "min": 1, "moved": 1, "source": "europe", "allowed": [], "exclude": []}
	var snap_mc: Dictionary = board._ui_snapshot()
	check.call("ui_snapshot: cattura move_ctx", int(snap_mc.get("move_ctx", {}).get("max", 0)) == 3)
	board._move_ctx = {}
	board._apply_ui_snapshot(snap_mc)
	check.call("apply_ui_snapshot: ripristina move_ctx",
		int(board._move_ctx.get("max", 0)) == 3 and String(board._move_ctx.get("source", "")) == "europe")
	board._move_ctx = {}

	print("Verifica command bus: %s" % ("OK" if cnt["fails"] == 0 else "FALLITA (%d)" % cnt["fails"]))
	board.queue_free()
	await process_frame
	quit()
