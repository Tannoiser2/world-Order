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

		# Senza una carta in gioco, toccare una Regione NON fa Engage: ogni azione
		# richiede di giocare la carta corrispondente.
		board._active().resources["diplomacy"] = 8
		var before: int = board.gs.regions["europe"]["track"].count(board._active().power)
		board._on_region_pressed("europe")
		var after: int = board.gs.regions["europe"]["track"].count(board._active().power)
		var ok2 := after == before   # nessun cambiamento
		print("[%s] niente Engage rapido senza carta (serve giocare la carta)" % ["OK" if ok2 else "FAIL"])
		if not ok2: fails += 1
		var hand_n: int = board._active().hand.size()
		print("[%s] mano del giocatore popolata (%d carte)" % ["OK" if hand_n > 0 else "FAIL", hand_n])
		if hand_n == 0: fails += 1

		# Gioco di una carta che richiede una Regione (Engage).
		var ac: PlayerState = board._active()
		ac.resources["diplomacy"] = 20  # isola il test dal consumo precedente
		var card_region := {"display_name": "Test Engage", "effect_ops": [{"op": "engage"}]}
		ac.hand.append(card_region)
		for c0 in ac.allied_countries: ac.exhausted[String(c0.get("id", ""))] = true  # niente popup sconto
		board._plays_left = 9
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
		for c1 in ac.allied_countries: ac.exhausted[String(c1.get("id", ""))] = true  # niente popup sconto
		board._plays_left = 9
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

		# Sconto diplomatico: esaurendo un alleato della Regione, l'Engage costa meno
		# Diplomazia (e l'alleato resta esaurito).
		var pdsc: PlayerState = board._active()
		pdsc.allied_countries.append({"id": "ally_disc", "display_name": "Disc Ally", "region": "europe", "value": 3, "exports": [], "imports": []})
		pdsc.exhausted["ally_disc"] = false
		pdsc.resources["diplomacy"] = 100
		var base_cost: int = int(board.gs.regions["europe"]["engage_cost"])
		var card_eng := {"display_name": "Eng disc", "effect_ops": [{"op": "engage"}]}
		pdsc.hand.append(card_eng)
		board._plays_left = 9
		board._play_card(card_eng)
		var dip_pre2: int = pdsc.resources["diplomacy"]
		board._on_region_pressed("europe")   # apre il popup sconto (1 alleato in europe)
		board._exhaust_sel = {"ally_disc": true}
		var ok_btn: Button = _find_button(board.popup_layer, "Conferma")
		if ok_btn: ok_btn.pressed.emit()
		var spent2: int = dip_pre2 - pdsc.resources["diplomacy"]
		var expected2: int = Actions.engage_cost(base_cost, [3], pdsc.focus == WO.Focus.DIPLOMATIC, 0)
		var disc_ok: bool = ok_btn != null and spent2 == expected2 and bool(pdsc.exhausted.get("ally_disc", false)) \
			and (card_eng in pdsc.played)
		print("[%s] Engage scontato esaurendo un alleato (−3 valore: speso %d, atteso %d)" % ["OK" if disc_ok else "FAIL", spent2, expected2])
		if not disc_ok: fails += 1

		# Invest via Country alleata davanti al giocatore (awaiting allied_country).
		ac.money = 50
		var ally: Dictionary = ac.allied_countries[0]
		ac.exhausted[ally.get("id", "")] = false
		var money_pre: int = ac.money
		var card_inv := {"display_name": "Test Invest", "effect_ops": [{"op": "invest"}]}
		ac.hand.append(card_inv)
		board._plays_left = 9
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
		board._plays_left = 9
		board._play_card(card_auto)
		var auto_ok: bool = ac.money == money_b + 7 and (card_auto in ac.played) and board.playing_card.is_empty()
		print("[%s] carta auto (gain_money) risolta subito (+7 money)" % ["OK" if auto_ok else "FAIL"])
		if not auto_ok: fails += 1

		# Move: dispiega 2 Armate dalla Riserva in 2 Regioni (sorgente = Riserva,
		# poi destinazione). "Move up to 2": paga 5 money/Armata.
		var pm: PlayerState = board._active()
		pm.armies_available = 3
		pm.money = 30
		var eu0: int = board.gs.regions["europe"]["armies"].get(pm.power, 0)
		var af0: int = board.gs.regions["africa"]["armies"].get(pm.power, 0)
		var card_move := {"display_name": "Test Move", "effect_ops": [{"op": "move", "max": 2}]}
		pm.hand.append(card_move)
		board._plays_left = 9
		board._play_card(card_move)
		board._move_pick_reserve()             # sorgente = riserva
		board._on_region_pressed("europe")     # destinazione 1
		board._move_pick_reserve()
		board._on_region_pressed("africa")     # destinazione 2 → raggiunge max 2
		var eu1: int = board.gs.regions["europe"]["armies"].get(pm.power, 0)
		var af1: int = board.gs.regions["africa"]["armies"].get(pm.power, 0)
		var move_ok: bool = eu1 == eu0 + 1 and af1 == af0 + 1 and pm.armies_available == 1 \
			and pm.money == 20 and board.playing_card.is_empty()
		print("[%s] Move da Riserva: 2 Armate in 2 Regioni, riserva 3->1, −10 money" % ["OK" if move_ok else "FAIL"])
		if not move_ok: fails += 1

		# Move tra Regioni: sposta 1 Armata da una Regione all'altra (libero, paga 5).
		var pmr: PlayerState = board._active()
		pmr.money = 30
		board.gs.regions["europe"]["armies"][pmr.power] = 2
		board.gs.regions["africa"]["armies"][pmr.power] = 0
		var card_relo := {"display_name": "Relo", "effect_ops": [{"op": "move", "max": 1}]}
		pmr.hand.append(card_relo)
		board._plays_left = 9
		board._play_card(card_relo)
		board._on_region_pressed("europe")     # sorgente = Regione con tue Armate
		board._on_region_pressed("africa")     # destinazione → sposta 1
		var relo_ok: bool = board.gs.regions["europe"]["armies"][pmr.power] == 1 \
			and board.gs.regions["africa"]["armies"][pmr.power] == 1 \
			and pmr.money == 25 and board.playing_card.is_empty()
		print("[%s] Move tra Regioni: Europa 2->1, Africa 0->1, −5 money" % ["OK" if relo_ok else "FAIL"])
		if not relo_ok: fails += 1

		# Produce multi-traccia con quantità: primarie + secondaria + Armate in riserva.
		var ppr: PlayerState = board._active()
		ppr.production = {"energy": 3, "consumer_goods": 1, "armies": 1}
		ppr.resources["energy"] = 5; ppr.resources["raw_materials"] = 5; ppr.resources["consumer_goods"] = 0
		ppr.armies_available = 0
		var card_prod := {"display_name": "Prod", "effect_ops": [{"op": "produce"}]}
		ppr.hand.append(card_prod)
		board._plays_left = 9
		board._play_card(card_prod)                       # apre la UI Produce
		var prod_popup: bool = board.popup_layer.get_child_count() > 0
		board._produce_sel = {"energy": 2, "consumer_goods": 1, "armies": 1}
		board._produce_confirm()
		# energy 5 +2 -1(CG) = 6 ; rawmat 5 -1(CG) -1(armata) = 3 ; CG +1 ; riserva +1
		var prod_ok: bool = prod_popup and ppr.resources["energy"] == 6 and ppr.resources["raw_materials"] == 3 \
			and ppr.resources["consumer_goods"] == 1 and ppr.armies_available == 1 and board.playing_card.is_empty()
		print("[%s] Produce multi-traccia: +2 Energia, +1 Beni, +1 Armata in riserva" % ["OK" if prod_ok else "FAIL"])
		if not prod_ok: fails += 1

		# Get a Growth Card: popup con le carte, clic acquista (+VP, +1 Growth).
		var pg: PlayerState = board._active()
		pg.growth_cards.clear()
		for rt0 in pg.resources: pg.resources[rt0] = 20
		pg.money = 100
		var av: Array = board._available_growth(pg)
		if av.size() > 0:
			var card_gg := {"display_name": "GG", "effect_ops": [{"op": "get_growth"}]}
			pg.hand.append(card_gg)
			board._plays_left = 9
			var gc_pre: int = pg.growth_cards.size()
			var vp_pre: int = pg.victory_points
			board._play_card(card_gg)                     # apre il picker delle Growth
			var gg_popup: bool = board.popup_layer.get_child_count() > 0
			board._buy_growth_action(av[0], 1)
			var gg_ok: bool = gg_popup and pg.growth_cards.size() == gc_pre + 1 \
				and pg.victory_points == vp_pre + int(av[0].get("victory_points", 0)) \
				and board.playing_card.is_empty()
			print("[%s] Get a Growth Card: popup carte + acquisto (+%d VP)" % ["OK" if gg_ok else "FAIL", int(av[0].get("victory_points", 0))])
			if not gg_ok: fails += 1

		# Auto-Influence: con 2 giocatori (usa, china) la potenza NEUTRALE Russia
		# piazza Influenza da una carta Auto-Influence (board 2p dedicato).
		var saved_powers: Array = GameConfig.powers
		GameConfig.powers = ["usa", "china"]
		var b3: Node = load("res://scenes/board.tscn").instantiate()
		get_root().add_child(b3)
		await process_frame
		var neutral := "russia"
		var inf_before := 0
		for rid0 in b3.gs.regions: inf_before += b3.gs.regions[rid0]["track"].count(neutral)
		var ai_lines := []
		var ai_art: String = b3._apply_auto_influence(ai_lines)
		var inf_after := 0
		for rid1 in b3.gs.regions: inf_after += b3.gs.regions[rid1]["track"].count(neutral)
		var ai_ok: bool = inf_after > inf_before and ai_art != "" and ai_lines.size() > 0
		print("[%s] Auto-Influence (2p): Russia neutrale piazza Influenza (%d->%d)" % ["OK" if ai_ok else "FAIL", inf_before, inf_after])
		if not ai_ok: fails += 1
		b3.queue_free()
		GameConfig.powers = saved_powers
		await process_frame

		# Trade action interattiva: export di una risorsa (cap dai simboli amici) e
		# import di un'altra; +1 Diplomazia comprando dagli altri.
		var pt: PlayerState = board._active()
		pt.allied_countries = [
			{"id": "ally_exp", "exports": ["energy", "energy"], "imports": []},
			{"id": "ally_imp", "exports": [], "imports": ["food"]},
		]
		pt.resources["energy"] = 5
		pt.resources["food"] = 0
		pt.resources["diplomacy"] = 0
		pt.money = 0
		var exp_cap: int = board._trade_export_cap(pt, "energy")  # min(2 simboli, 5 possedute) = 2
		var imp_cap: int = board._trade_import_cap(pt, "food")    # 1 simbolo Import
		board._open_trade_ui()
		board._trade_adjust("energy", "export", 1)
		board._trade_adjust("energy", "export", 1)   # esporto 2 Energia
		board._trade_adjust("food", "import", 1)     # importo 1 Cibo
		var en_pre: int = pt.resources["energy"]
		var money_t0: int = pt.money
		board._trade_confirm()
		var trade_ok: bool = exp_cap == 2 and imp_cap == 1 \
			and pt.resources["energy"] == en_pre - 2 \
			and pt.resources["food"] == 1 \
			and pt.resources["diplomacy"] == 1 \
			and pt.money == money_t0 + Actions.EXPORT_GAIN["energy"] * 2 - Actions.IMPORT_COST["food"]
		print("[%s] Trade UI: export 2 Energia, import 1 Cibo, +1 Diplomazia" % ["OK" if trade_ok else "FAIL"])
		if not trade_ok: fails += 1

		# Cap Trade: non puoi esportare oltre i simboli delle nazioni amiche.
		board._open_trade_ui()
		for _i in 5:
			board._trade_adjust("energy", "export", 1)
		var cap_ok: bool = int((board._trade_sel["export"] as Dictionary).get("energy", 0)) == exp_cap
		print("[%s] Trade UI: export limitato dal cap (%d)" % ["OK" if cap_ok else "FAIL", exp_cap])
		if not cap_ok: fails += 1
		board._trade_sel = {}
		board._close_popup()

		# Carte nazione impilate: più carte della STESSA nazione sommano i simboli
		# Export → più capacità di commercio (e il cap cresce di conseguenza).
		var stack_card := {"id": "irl", "exports": ["energy"], "imports": []}
		pt.allied_countries = [stack_card.duplicate(), stack_card.duplicate(), stack_card.duplicate()]
		pt.resources["energy"] = 10
		var stack_cap: int = board._trade_export_cap(pt, "energy")  # 3 carte × 1 simbolo = 3
		print("[%s] Carte impilate: 3 copie → export cap 3 (era 1)" % ["OK" if stack_cap == 3 else "FAIL"])
		if stack_cap != 3: fails += 1

		# Stato "esaurita": la carta nazione appare grigia e ruotata (tapped).
		var ex_card: Control = board._ally_stack({"id": "x", "art": ""}, 1, Vector2(40, 56), false, false, true)
		var ex_ok: bool = ex_card.modulate != Color(1, 1, 1, 1) and not is_zero_approx(ex_card.rotation_degrees)
		print("[%s] carta nazione esaurita: grigia e ruotata" % ["OK" if ex_ok else "FAIL"])
		if not ex_ok: fails += 1

		# Trade fra giocatori: importo Servizi dalla Commerce card di un altro
		# giocatore → quel giocatore incassa il money e +1 Servizio, la sua Commerce
		# card si gira (non riusabile nel round).
		var buyer: PlayerState = board._active()
		var seller_power := "russia" if buyer.power != "russia" else "china"
		var seller: PlayerState = board.gs.player_by_power(seller_power)
		if seller != null:
			buyer.allied_countries = []  # niente import "dal mercato": solo dai giocatori
			buyer.money = 50
			seller.money = 0
			var serv_pre: int = seller.resources["services"]
			# Forziamo una Trade Deals con import_from dal venditore (1 risorsa offerta).
			board.trade_deals = {"cards": [{"power": buyer.power, "exports": 2, "imports": 2,
				"import_from": {seller_power: ["consumer_goods"]}}]}
			var src: Array = board._import_sources(buyer, "consumer_goods")
			board._open_trade_ui()
			board._trade_adjust("consumer_goods", "import", 1)
			var b_money_pre: int = buyer.money
			board._trade_confirm()
			var cost: int = Actions.IMPORT_COST["consumer_goods"]
			var p2p_ok: bool = src.size() == 1 and String(src[0]["src"]) == seller_power \
				and seller.money == cost \
				and seller.resources["services"] == serv_pre + 1 \
				and buyer.money == b_money_pre - cost \
				and ("consumer_goods" in (board._commerce_flipped.get(seller_power, []) as Array)) \
				and board._trade_import_cap(buyer, "consumer_goods") == 0  # card girata
			print("[%s] Trade P2P: venditore +money +1 Servizio, Commerce card girata" % ["OK" if p2p_ok else "FAIL"])
			if not p2p_ok: fails += 1
			board._trade_sel = {}
			board.trade_deals = DataLoader.load_trade_deals()  # ripristino

		# Focus action: prepara (ready) le Country card (Military=2, +1 con
		# "ready_extra_on_focus") E produce il tipo del Focus (Armate → riserva).
		var pf: PlayerState = board._active()
		pf.exhausted = {"a": true, "b": true, "c": true, "d": true}
		pf.growth_cards.append({"effect_ops": [{"op": "ongoing", "tag": "ready_extra_on_focus"}]})
		pf.production["armies"] = 2
		pf.resources["raw_materials"] = 5
		pf.armies_available = 0
		board._plays_left = 1
		board._do_focus(WO.Focus.MILITARY)
		var readied: int = pf.exhausted.values().count(false)
		var focus_ok: bool = pf.focus == WO.Focus.MILITARY and readied == 3 and board._plays_left == 0 \
			and pf.armies_available == 2 and pf.resources["raw_materials"] == 3   # Produce armi → riserva
		print("[%s] Focus Military: ready 3 (2+1) + produce 2 Armate in riserva" % ["OK" if focus_ok else "FAIL"])
		if not focus_ok: fails += 1
		pf.growth_cards.clear()

		# extra_play_first_turn: al primo turno del round +1 carta giocabile.
		var pe: PlayerState = board._active()
		pe.growth_cards.append({"effect_ops": [{"op": "ongoing", "tag": "extra_play_first_turn"}]})
		board.round_turn_count = 0  # primo giro del round
		board._reset_plays()
		var first_ok: bool = board._plays_left == 2
		board.round_turn_count = board.gs.players.size()  # non più primo turno
		board._reset_plays()
		first_ok = first_ok and board._plays_left == 1
		print("[%s] ongoing extra_play_first_turn: 2 giocate al 1° turno, poi 1" % ["OK" if first_ok else "FAIL"])
		if not first_ok: fails += 1
		pe.growth_cards.clear()

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
		board._plays_left = 9
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
		board._plays_left = 9
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
