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
		# La plancia reale viene mostrata con l'immagine (aprendo il cassetto).
		board._on_power_tab(board._active().power)
		var bg_ok: bool = board.board_bg != null and board.board_bg.texture != null
		print("[%s] immagine reale della plancia caricata nel cassetto" % ["OK" if bg_ok else "FAIL"])
		if not bg_ok: fails += 1
		board.drawer_open = false
		board._refresh()

		# flusso di click: Engage in Europe (le risorse iniziali sono 0: la Diplomacy
		# si produce in gioco, qui la forniamo per testare il flusso).
		board._active().resources["diplomacy"] = 8
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

		# Improve Relations via Country sul tabellone (awaiting board_country).
		ac.resources["diplomacy"] = 20
		var rid := gs_first_region(board)
		var avail: Array = board.region_countries[rid]["available"]
		var n_av: int = avail.size()
		var target: Dictionary = avail[0]
		var allied_b: int = ac.allied_countries.size()
		var card_ir := {"display_name": "Test IR", "effect_ops": [{"op": "improve_relations"}]}
		ac.hand.append(card_ir)
		board._play_card(card_ir)
		var ir_await: bool = board.awaiting == "board_country"
		print("[%s] play carta Improve Relations -> attende una Country sul board" % ["OK" if ir_await else "FAIL"])
		if not ir_await: fails += 1
		board._on_country_pressed(target, rid)
		var ir_ok: bool = ac.allied_countries.size() == allied_b + 1 and (target in ac.allied_countries) \
			and board.region_countries[rid]["available"].size() == n_av \
			and not (target in board.region_countries[rid]["available"]) \
			and (card_ir in ac.played)
		print("[%s] Improve Relations da board: alleato +1, Country rifornita, carta in scarti" % ["OK" if ir_ok else "FAIL"])
		if not ir_ok: fails += 1

		# Invest via Country alleata davanti al giocatore (awaiting allied_country).
		ac.money = 50
		var ally: Dictionary = ac.allied_countries[0]
		ac.exhausted[ally.get("id", "")] = false
		var money_pre: int = ac.money
		var card_inv := {"display_name": "Test Invest", "effect_ops": [{"op": "invest"}]}
		ac.hand.append(card_inv)
		board._play_card(card_inv)
		var inv_await: bool = board.awaiting == "allied_country"
		print("[%s] play carta Invest -> attende una Country alleata" % ["OK" if inv_await else "FAIL"])
		if not inv_await: fails += 1
		board._on_allied_pressed(ally)
		var inv_ok: bool = ac.money < money_pre and (card_inv in ac.played) and board.awaiting == ""
		print("[%s] Invest da Country alleata: spesa money, carta in scarti" % ["OK" if inv_ok else "FAIL"])
		if not inv_ok: fails += 1

		# Carta auto-risolta (gain_money), nessun target.
		var money_b: int = ac.money
		var card_auto := {"display_name": "Test Money", "effect_ops": [{"op": "gain_money", "amount": 7}]}
		ac.hand.append(card_auto)
		board._play_card(card_auto)
		var auto_ok: bool = ac.money == money_b + 7 and (card_auto in ac.played) and board.playing_card.is_empty()
		print("[%s] carta auto (gain_money) risolta subito (+7 money)" % ["OK" if auto_ok else "FAIL"])
		if not auto_ok: fails += 1

		# Move multi-Regione: "Move up to 2" → tocca 2 Regioni, 1 Armata ciascuna.
		var pm: PlayerState = board._active()
		pm.armies_available = 3
		pm.money = 30
		var eu0: int = board.gs.regions["europe"]["armies"].get(pm.power, 0)
		var af0: int = board.gs.regions["africa"]["armies"].get(pm.power, 0)
		var card_move := {"display_name": "Test Move", "effect_ops": [{"op": "move", "max": 2}]}
		pm.hand.append(card_move)
		board._play_card(card_move)
		board._on_region_pressed("europe")
		board._on_region_pressed("africa")   # raggiunge max 2 → applica
		var eu1: int = board.gs.regions["europe"]["armies"].get(pm.power, 0)
		var af1: int = board.gs.regions["africa"]["armies"].get(pm.power, 0)
		var move_ok: bool = eu1 == eu0 + 1 and af1 == af0 + 1 and pm.armies_available == 1 and board.playing_card.is_empty()
		print("[%s] Move multi-Regione: 2 Armate in 2 Regioni, riserva 3->1" % ["OK" if move_ok else "FAIL"])
		if not move_ok: fails += 1

		# Abilità ongoing: "extra_draw_per_round" → pesca 7 invece di 6 a inizio round.
		var po: PlayerState = board.gs.players[0]
		po.growth_cards.append({"display_name": "Tactical Flexibility", "effect_ops": [{"op": "ongoing", "tag": "extra_draw_per_round"}]})
		board.gs.round = 1
		board._next_round()
		var draw_ok: bool = po.hand.size() == 7
		print("[%s] ongoing extra_draw_per_round: pesca 7 (6+1)" % ["OK" if draw_ok else "FAIL"])
		if not draw_ok: fails += 1

		# Drawer plancia: la scheda della potenza la apre/chiude (toggle) e mostra
		# la mano del giocatore di turno; l'interazione con la mappa la richiude.
		board.drawer_open = false
		board._on_power_tab(ac.power)
		var opened: bool = board.drawer_open and board.drawer_power == ac.power \
			and board.hand_box != null and board.hand_box.get_child_count() == ac.hand.size()
		print("[%s] scheda potenza apre la plancia con la mano (%d carte)" % ["OK" if opened else "FAIL", ac.hand.size()])
		if not opened: fails += 1
		board._on_power_tab(ac.power)  # ri-tocco la stessa scheda -> chiude
		var toggled: bool = board.drawer_open == false
		print("[%s] ri-toccando la scheda attiva il cassetto si chiude" % ["OK" if toggled else "FAIL"])
		if not toggled: fails += 1
		board._on_power_tab(ac.power)  # riapro per il test di auto-chiusura
		ac.resources["diplomacy"] = 20
		var card_close := {"display_name": "Engage close", "effect_ops": [{"op": "engage"}]}
		ac.hand.append(card_close)
		board._play_card(card_close)
		var auto_closed: bool = board.awaiting == "region" and board.drawer_open == false
		print("[%s] interazione mappa: il cassetto si richiude da solo" % ["OK" if auto_closed else "FAIL"])
		if not auto_closed: fails += 1
		board._on_region_pressed("south_asia")  # risolve e chiude la carta

		# Modifiers: carta Engage con sconto -1 Diplomacy per Armata schierata.
		ac.resources["diplomacy"] = 20
		var mreg := "central_asia"
		board.gs.regions[mreg]["armies"][ac.power] = 3
		var raw_cost: int = int(board.gs.regions[mreg]["engage_cost"])
		var diplo := ac.focus == WO.Focus.DIPLOMATIC
		var expected_cost: int = Actions.engage_cost(raw_cost, [], diplo, 3)
		var dip_pre: int = ac.resources["diplomacy"]
		var card_mod := {"display_name": "Engage scontato", "effect_ops": [{"op": "engage"}],
			"effect_modifiers": ["engage_discount_per_army"]}
		ac.hand.append(card_mod)
		board._play_card(card_mod)
		board._on_region_pressed(mreg)
		var spent: int = dip_pre - ac.resources["diplomacy"]
		var mod_ok: bool = spent == expected_cost and (card_mod in ac.played)
		print("[%s] effect_modifier: Engage costa %d (sconto -3 per Armata)" % ["OK" if mod_ok else "FAIL", spent])
		if not mod_ok: fails += 1

		# Research/Market: il mercato e' rifornito; l'acquisto consuma Research.
		var mkt_full: bool = board.market_display.size() == board.MARKET_SLOTS
		print("[%s] Market rifornito a %d carte scoperte" % ["OK" if mkt_full else "FAIL", board.market_display.size()])
		if not mkt_full: fails += 1
		board._research_points = 99
		var deck_pre: int = ac.deck.size()
		var buy: Dictionary = board.market_display[0]
		board._buy_market(buy)
		var buy_ok: bool = ac.deck.size() == deck_pre + 1 and not (buy in board.market_display) \
			and board.market_display.size() == board.MARKET_SLOTS and board._research_points < 99
		print("[%s] acquisto Market: carta nel mazzo, slot rifornito, Research speso" % ["OK" if buy_ok else "FAIL"])
		if not buy_ok: fails += 1

		# Growth: acquisto della prossima Growth (livello 1) spendendo risorse.
		var ag: Array = board._available_growth(ac)
		if ag.size() > 0:
			var gcard: Dictionary = ag[0]
			ac.money = 50
			for rt in ac.resources: ac.resources[rt] = 10
			var vp_pre: int = ac.victory_points
			var growth_pre: int = ac.growth_cards.size()
			board._buy_growth(gcard)
			var g_ok: bool = ac.growth_cards.size() == growth_pre + 1 \
				and ac.victory_points == vp_pre + int(gcard.get("victory_points", 0))
			print("[%s] acquisto Growth: carta acquisita (+%d VP)" % ["OK" if g_ok else "FAIL", int(gcard.get("victory_points", 0))])
			if not g_ok: fails += 1

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


## Prima Regione con almeno una Country disponibile.
func gs_first_region(board: Node) -> String:
	for rid in board.region_countries:
		if (board.region_countries[rid]["available"] as Array).size() > 0:
			return rid
	return ""


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
