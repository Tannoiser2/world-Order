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
		var n := 0   # conta solo i bottoni-Regione (l'overlay ha anche i segnalini)
		if board.overlay:
			for c in board.overlay.get_children():
				if c is Button: n += 1
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
		# Prerequisito Engage (pag. 13): garantisci un alleato in central_asia (esaurito,
		# così non apre il popup sconto); rimosso dopo il test.
		var ca_ally := {"id": "country_ca_pre", "region": "central_asia", "value": 1}
		ac.allied_countries.append(ca_ally)
		ac.exhausted["country_ca_pre"] = true
		board._plays_left = 9
		board._play_card(card_region)
		var aw_ok: bool = board.awaiting == "region"
		print("[%s] play carta Engage -> attende una Regione" % ["OK" if aw_ok else "FAIL"])
		if not aw_ok: fails += 1
		var inf_b: int = board.gs.regions["central_asia"]["track"].count(ac.power)
		board._on_region_pressed("central_asia")
		var slot_b1: Button = _find_button(board.popup_layer, "Temporanea")  # scelta slot perm/temp
		if slot_b1: slot_b1.pressed.emit()
		var inf_a: int = board.gs.regions["central_asia"]["track"].count(ac.power)
		ac.allied_countries.erase(ca_ally)
		var played_ok: bool = (card_region in ac.played) and not (card_region in ac.hand) and inf_a == inf_b + 1
		print("[%s] risoluzione carta Engage (Influenza %d->%d, carta in scarti)" % ["OK" if played_ok else "FAIL", inf_b, inf_a])
		if not played_ok: fails += 1

		# Improve Relations via Country sul tabellone (awaiting board_country).
		ac.resources["diplomacy"] = 20
		var rid := gs_first_region(board)
		var avail: Array = board.region_countries[rid]["available"]
		var n_av: int = avail.size()
		# Scegli una Country che non vieti l'alleanza alla potenza attiva (pag. 12).
		var target: Dictionary = avail[0]
		for cav in avail:
			if ac.power not in (cav as Dictionary).get("no_relations_powers", []):
				target = cav
				break
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
		var slot_b2: Button = _find_button(board.popup_layer, "Temporanea")  # scelta slot
		if slot_b2: slot_b2.pressed.emit()
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
		var slot_b3: Button = _find_button(board.popup_layer, "Temporanea")  # scelta slot
		if slot_b3: slot_b3.pressed.emit()
		var inv_ok: bool = ac.money < money_pre and (card_inv in ac.played) and board.awaiting == ""
		print("[%s] Invest da Country alleata: spesa money, carta in scarti" % ["OK" if inv_ok else "FAIL"])
		if not inv_ok: fails += 1

		# Build a Base: la UI fa SCEGLIERE quante Armate muovere (fino al valore del
		# Country), non 1 fissa (audit #19).
		var pbb: PlayerState = board._active()
		pbb.money = 100
		pbb.armies_available = 4
		var bb_country := {"id": "country_bb_ui", "display_name": "BaseTest", "region": "africa",
			"value": 3, "has_base_symbol": true, "base_allowed_powers": [pbb.power]}
		pbb.allied_countries.append(bb_country)
		pbb.exhausted["country_bb_ui"] = false
		var bb_region_pre: int = int((board.gs.regions["africa"]["armies"] as Dictionary).get(pbb.power, 0))
		var bb_money_pre: int = pbb.money
		var card_bb := {"display_name": "Test Build Base", "effect_ops": [{"op": "build_base"}]}
		pbb.hand.append(card_bb)
		board._plays_left = 9
		board._play_card(card_bb)
		board._on_allied_pressed(bb_country)
		var slot_bb: Button = _find_button(board.popup_layer, "Temporanea")
		if slot_bb: slot_bb.pressed.emit()
		var n2_btn: Button = _find_button(board.popup_layer, "2 Armata/e")   # scelgo 2 Armate
		if n2_btn: n2_btn.pressed.emit()
		var bb_region_post: int = int((board.gs.regions["africa"]["armies"] as Dictionary).get(pbb.power, 0))
		var bb_ok: bool = (card_bb in pbb.played) \
			and bb_region_post == bb_region_pre + 2 \
			and pbb.money == bb_money_pre - Actions.build_base_cost(2) \
			and pbb.armies_available == 2
		print("[%s] Build a Base UI: muove 2 Armate (fino al valore), costo %d" % ["OK" if bb_ok else "FAIL", Actions.build_base_cost(2)])
		if not bb_ok: fails += 1
		pbb.allied_countries.erase(bb_country)

		# Scelta slot Influenza (Engage): con permanente libero il giocatore sceglie (popup);
		# sennò temporaneo.
		var trk2: InfluenceTrack = board.gs.regions["americas"]["track"]
		for i in range(trk2.perm.size()): trk2.perm[i] = null     # libera i permanenti
		var got := {"v": ""}
		board._pick_slot("americas", func(s): got["v"] = s)
		var pbtn: Button = _find_button(board.popup_layer, "Permanente")
		if pbtn: pbtn.pressed.emit()
		var perm_ok: bool = got["v"] == "permanent"
		for i in range(trk2.perm.size()): trk2.perm[i] = "local"  # tutti permanenti pieni
		got["v"] = ""
		board._pick_slot("americas", func(s): got["v"] = s)        # nessun popup → temporaneo
		var temp_ok: bool = got["v"] == "temporary"
		print("[%s] Scelta slot Influenza (Engage): permanente se libero, altrimenti temporaneo" % ["OK" if perm_ok and temp_ok else "FAIL"])
		if not (perm_ok and temp_ok): fails += 1

		# add_influence sulla mappa: un click su una casella valida posa l'Influenza
		# (Regione + slot) e prosegue.
		var pinf: PlayerState = board._active()
		for i in range(board.gs.regions["africa"]["track"].temp.size()):
			board.gs.regions["africa"]["track"].temp[i] = null
		var afr_t0: int = 0
		for o in board.gs.regions["africa"]["track"].temp:
			if o == pinf.power: afr_t0 += 1
		var card_inf := {"display_name": "Inf", "effect_ops": [{"op": "add_influence"}]}
		pinf.hand.append(card_inf); board._plays_left = 9
		board._play_card(card_inf)
		var inf_mode: bool = board.awaiting == "influence_cell"
		board._on_influence_cell("africa", "temporary")
		var afr_t1: int = 0
		for o in board.gs.regions["africa"]["track"].temp:
			if o == pinf.power: afr_t1 += 1
		var inf_ok: bool = inf_mode and afr_t1 == afr_t0 + 1 and board.awaiting == "" and board.playing_card.is_empty()
		print("[%s] add_influence sulla mappa: click su casella → Influenza posata" % ["OK" if inf_ok else "FAIL"])
		if not inf_ok: fails += 1

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
		# Drag&drop: trascina un carro dalla Riserva su una Regione (drop = _region_do_drop).
		board._region_do_drop(Vector2.ZERO, {"move_src": "_reserve"}, "europe")   # destinazione 1
		board._region_do_drop(Vector2.ZERO, {"move_src": "_reserve"}, "africa")   # destinazione 2 → max 2
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

		# Move drag&drop: rientro in Riserva (gratis, non conta nel max).
		var pret: PlayerState = board._active()
		pret.money = 30
		board.gs.regions["europe"]["armies"][pret.power] = 2
		pret.armies_available = 0
		var card_ret := {"display_name": "Ret", "effect_ops": [{"op": "move", "max": 2}]}
		pret.hand.append(card_ret); board._plays_left = 9
		board._play_card(card_ret)
		board._reserve_do_drop(Vector2.ZERO, {"move_src": "europe"})   # un carro rientra in Riserva
		var ret_ok: bool = board.gs.regions["europe"]["armies"][pret.power] == 1 \
			and pret.armies_available == 1 and pret.money == 30 \
			and int(board._move_ctx.get("moved", 0)) == 0
		board._finish_move()
		print("[%s] Move drag&drop: rientro in Riserva (gratis, moved=0)" % ["OK" if ret_ok else "FAIL"])
		if not ret_ok: fails += 1

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
			and pt.resources["diplomacy"] == 0 \
			and pt.money == money_t0 + Actions.EXPORT_GAIN["energy"] * 2 - Actions.IMPORT_COST["food"]
		print("[%s] Trade UI: export 2 Energia, import 1 Cibo (banca → niente Diplomazia)" % ["OK" if trade_ok else "FAIL"])
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

		# Trade su TRACK (nuovo modello): tap su una casella verso 0 = vendi, verso 10 = compra.
		var ptt: PlayerState = board._active()
		var saved_allies: Array = ptt.allied_countries
		var saved_td: Dictionary = board.trade_deals
		ptt.allied_countries = [{"id": "tt", "region": "africa", "value": 1,
			"exports": ["energy", "energy"], "imports": ["food"]}]
		ptt.resources["energy"] = 4
		ptt.resources["food"] = 2
		board.trade_deals = {"cards": [{"power": ptt.power, "exports": 2, "imports": 2, "import_from": {}}]}
		board._open_trade_ui()
		board._trade_set_target("energy", 2)   # 4→2 = vendi 2 (cap export 2)
		board._trade_set_target("food", 3)     # 2→3 = compra 1 (cap import 1)
		var tt_ok: bool = int(board._trade_sel["export"].get("energy", 0)) == 2 \
			and int(board._trade_sel["import"].get("food", 0)) == 1
		board._trade_set_target("energy", 0)   # vorrebbe vendere 4 → limitato al cap 2
		var tt_cap_ok: bool = int(board._trade_sel["export"].get("energy", 0)) == 2
		print("[%s] Trade track: verso 0 vende, verso 10 compra, cap rispettato" % ["OK" if (tt_ok and tt_cap_ok) else "FAIL"])
		if not (tt_ok and tt_cap_ok): fails += 1
		board._trade_sel = {}
		board._close_popup()
		ptt.allied_countries = saved_allies
		board.trade_deals = saved_td

		# Trade #14: vendita Armate dalla riserva (20 money cad., occupa uno slot Export).
		var par: PlayerState = board._active()
		var sv_allies_a: Array = par.allied_countries
		var sv_td_a: Dictionary = board.trade_deals
		par.allied_countries = []
		board.trade_deals = {"cards": [{"power": par.power, "exports": 2, "imports": 2, "import_from": {}}]}
		par.armies_available = 4
		par.money = 0
		board._open_trade_ui()
		board._trade_armies_adjust(3)            # vendi 3 Armate → +60, 1 slot Export
		var arm_delta_ok: bool = board._trade_delta() == 60 and board._trade_export_used() == 1
		board._trade_armies_adjust(5)            # oltre la riserva → limitato a 4
		var arm_cap_ok: bool = board._trade_armies == 4
		board._trade_confirm()
		var arm_sell_ok: bool = par.armies_available == 0 and par.money == 80
		print("[%s] Trade #14: vendita Armate dalla riserva (20 cad., cap riserva)" % ["OK" if (arm_delta_ok and arm_cap_ok and arm_sell_ok) else "FAIL"])
		if not (arm_delta_ok and arm_cap_ok and arm_sell_ok): fails += 1
		par.allied_countries = sv_allies_a
		board.trade_deals = sv_td_a

		# Commerce per-carta (UNA carta per trade): Russia vende fino a 3 Energia O 3
		# Materie Prime per UNA carta; per trade se ne gira una sola (non si sommano).
		var sv_td_cc: Dictionary = board.trade_deals
		board.trade_deals = DataLoader.load_trade_deals()
		board._commerce_flipped = {}
		var ru_cap_e: int = board._commerce_faceup_for("russia", "energy")          # 1 carta = 3 (non 9)
		var ru_n1: int = board._commerce_consume("russia", "energy", 2)             # gira 1 carta
		var ru_raw1: int = board._commerce_faceup_for("russia", "raw_materials")    # carta migliore rimasta: 3
		var ru_n2: int = board._commerce_consume("russia", "energy", 4)             # gira 1 carta (cap = 3)
		var cc_ok: bool = ru_cap_e == 3 and ru_n1 == 1 and ru_raw1 == 3 and ru_n2 == 1
		# EU: 1 carta = 1 Servizi O 1 Beni; per trade una sola carta → cap 1.
		board._commerce_flipped = {}
		var eu_cg0: int = board._commerce_faceup_for("eu", "consumer_goods")        # 1 carta → 1
		board._commerce_consume("eu", "consumer_goods", 1)                          # gira 1 carta
		var eu_sv1: int = board._commerce_faceup_for("eu", "services")              # carta rimasta: 1
		var eu_ok: bool = eu_cg0 == 1 and eu_sv1 == 1
		print("[%s] Commerce per-carta: una carta per trade (Russia 3 max, EU 1 max)" % ["OK" if (cc_ok and eu_ok) else "FAIL"])
		if not (cc_ok and eu_ok): fails += 1
		board.trade_deals = sv_td_cc
		board._commerce_flipped = {}

		# Trade: scelta della SORGENTE d'import via bandierina (banca vs altro giocatore).
		var psrc: PlayerState = board._active()
		var seller2_pw := "russia" if psrc.power != "russia" else "china"
		var seller2: PlayerState = board.gs.player_by_power(seller2_pw)
		if seller2 != null:
			var sv_allies3: Array = psrc.allied_countries
			var sv_td3: Dictionary = board.trade_deals
			psrc.allied_countries = [{"id": "ss", "region": "africa", "value": 1,
				"exports": [], "imports": ["services", "services"]}]   # banca offre 2 services
			board.trade_deals = {"cards": [{"power": psrc.power, "exports": 2, "imports": 2,
				"import_from": {seller2_pw: ["services"]}}],
				"commerce_cards": {seller2_pw: [{"services": 1}]}}     # il venditore: 1 carta services
			psrc.resources["services"] = 0
			psrc.money = 100
			board._commerce_flipped = {}   # carte prodotto tutte scoperte all'inizio
			var s2_money0: int = seller2.money
			board._open_trade_ui()
			var def_src: String = board._trade_selected_src(psrc, "services")   # default = banca
			board._trade_pick_src("services", seller2_pw)                       # scelgo il venditore
			var picked_cap: int = board._trade_import_cap_sel(psrc, "services") # = 1 (offerta venditore)
			board._trade_set_target("services", 1)                             # compra 1 dal venditore
			board._trade_confirm()
			var src_ok: bool = def_src == "bank" and picked_cap == 1 and seller2.money == s2_money0 + 10
			print("[%s] Trade: scelta venditore via bandierina (compra dal giocatore scelto)" % ["OK" if src_ok else "FAIL"])
			if not src_ok: fails += 1
			psrc.allied_countries = sv_allies3
			board.trade_deals = sv_td3

		# Carte nazione impilate: più carte della STESSA nazione sommano i simboli
		# Export → più capacità di commercio (e il cap cresce di conseguenza).
		var stack_card := {"id": "irl", "exports": ["energy"], "imports": []}
		pt.allied_countries = [stack_card.duplicate(), stack_card.duplicate(), stack_card.duplicate()]
		pt.resources["energy"] = 10
		var stack_cap: int = board._trade_export_cap(pt, "energy")  # 3 carte × 1 simbolo = 3
		print("[%s] Carte impilate: 3 copie → export cap 3 (era 1)" % ["OK" if stack_cap == 3 else "FAIL"])
		if stack_cap != 3: fails += 1

		# Modificatore condizionale: count_energy_or_raw_twice raddoppia i simboli Export.
		var pmod: PlayerState = board._active()
		pmod.allied_countries = [{"id": "e", "exports": ["energy", "energy"], "imports": []}]
		pmod.resources["energy"] = 10
		board.active_mods = Modifiers.parse(["count_energy_or_raw_twice"])
		var dbl_cap: int = board._trade_export_cap(pmod, "energy")   # 2 simboli ×2 = 4
		board.active_mods = {}
		var base_cap: int = board._trade_export_cap(pmod, "energy")  # 2
		print("[%s] Modificatore «conta Energia ×2»: cap %d (base %d)" % ["OK" if dbl_cap == 4 and base_cap == 2 else "FAIL", dbl_cap, base_cap])
		if not (dbl_cap == 4 and base_cap == 2): fails += 1

		# Modificatore: Influenza solo se hai esportato Beni/Servizi nel Trade.
		board.active_mods = Modifiers.parse(["cond_influence_export_cg_services"])
		board._trade_exported = {"consumer_goods": 1}
		var cond_met: bool = board._has_cond_influence() and board._cond_influence_ok()
		board._trade_exported = {"energy": 1}
		var cond_unmet: bool = board._has_cond_influence() and not board._cond_influence_ok()
		board.active_mods = {}; board._trade_exported = {}
		print("[%s] Influenza condizionale all'Export: concessa se hai esportato Beni/Servizi" % ["OK" if cond_met and cond_unmet else "FAIL"])
		if not (cond_met and cond_unmet): fails += 1

		# Carta a faccia in giù → +10 money (la carta va negli scarti, usa l'azione).
		var pfd: PlayerState = board._active()
		pfd.money = 0
		var fd_card := {"display_name": "FD", "effect_ops": [{"op": "engage"}]}
		pfd.hand.append(fd_card)
		board._plays_left = 9
		board._play_facedown_money(fd_card)
		var fd_ok: bool = pfd.money == 10 and (fd_card in pfd.discard) and not (fd_card in pfd.hand)
		print("[%s] Faccia in giù: +10 money, carta negli scarti" % ["OK" if fd_ok else "FAIL"])
		if not fd_ok: fails += 1

		# Strategic Asset: attivato spendendo una carta di mano; usabile una volta.
		var psa: PlayerState = board._active()
		psa.money = 0
		psa.strategic_assets = [{"display_name": "SA", "effect_ops": [{"op": "gain_money", "amount": 5}]}]
		psa.used_strategic_assets = []
		var cost_card := {"display_name": "Cost", "effect_ops": [{"op": "engage"}]}
		psa.hand.append(cost_card)
		var sa: Dictionary = psa.strategic_assets[0]
		board._plays_left = 9
		board._play_strategic_asset(cost_card, sa)
		var sa_ok: bool = psa.money == 5 and (sa in psa.used_strategic_assets) \
			and not (sa in psa.strategic_assets) and (cost_card in psa.discard) and board.playing_card.is_empty()
		print("[%s] Strategic Asset: effetto risolto, carta-costo scartata, usato 1 volta" % ["OK" if sa_ok else "FAIL"])
		if not sa_ok: fails += 1

		# op ready_country: prepara N Country esaurite.
		var prc: PlayerState = board._active()
		prc.exhausted = {"a": true, "b": true, "c": true}
		var card_rc := {"display_name": "RC", "effect_ops": [{"op": "ready_country", "n": 2}]}
		prc.hand.append(card_rc); board._plays_left = 9
		board._play_card(card_rc)
		var rc_ok: bool = prc.exhausted.values().count(false) == 2 and board.playing_card.is_empty()
		print("[%s] op ready_country: 2 Country preparate" % ["OK" if rc_ok else "FAIL"])
		if not rc_ok: fails += 1

		# op increase_prosperity (con sconto): avanza la Prosperità.
		var prp: PlayerState = board._active()
		prp.prosperity_level = 0; prp.resources["consumer_goods"] = 20
		var card_pr := {"display_name": "PR", "effect_ops": [{"op": "increase_prosperity", "discount": 2}]}
		prp.hand.append(card_pr); board._plays_left = 9
		board._play_card(card_pr)
		var pr_ok: bool = prp.prosperity_level == 1 and board.playing_card.is_empty()
		print("[%s] op increase_prosperity: livello 0→1" % ["OK" if pr_ok else "FAIL"])
		if not pr_ok: fails += 1

		# op increase_production (popup scelta risorsa): +count alla traccia scelta.
		var pip: PlayerState = board._active()
		pip.production["energy"] = 1
		var card_ip := {"display_name": "IP", "effect_ops": [{"op": "increase_production", "count": 2}]}
		pip.hand.append(card_ip); board._plays_left = 9
		board._play_card(card_ip)
		var eb: Button = _find_button(board.popup_layer, board.RES_LABEL["energy"])
		if eb: eb.pressed.emit()
		var ip_ok: bool = pip.production["energy"] == 3 and board.playing_card.is_empty()
		print("[%s] op increase_production: Energia 1→3 (+2)" % ["OK" if ip_ok else "FAIL"])
		if not ip_ok: fails += 1

		# op trash (popup mano): la carta scelta è rimossa dal gioco (non negli scarti).
		var ptr: PlayerState = board._active()
		var victim := {"display_name": "Victim", "effect_ops": [{"op": "noop"}]}
		ptr.hand.append(victim)
		var card_tr := {"display_name": "TR", "effect_ops": [{"op": "trash", "source": "self"}]}
		ptr.hand.append(card_tr); board._plays_left = 9
		board._play_card(card_tr)
		var vb: Button = _find_button(board.popup_layer, "Victim")
		if vb: vb.pressed.emit()
		var tr_ok: bool = not (victim in ptr.hand) and not (victim in ptr.discard) and board.playing_card.is_empty()
		print("[%s] op trash: carta eliminata dal gioco" % ["OK" if tr_ok else "FAIL"])
		if not tr_ok: fails += 1

		# op discard (n + then): scarta 1 carta, poi esegue play_another.
		var pds: PlayerState = board._active()
		var d1 := {"display_name": "D1", "effect_ops": [{"op": "noop"}]}
		pds.hand.append(d1)
		var card_ds := {"display_name": "DS", "effect_ops": [{"op": "discard", "n": 1, "then": [{"op": "play_another"}]}]}
		pds.hand.append(card_ds); board._plays_left = 1
		board._play_card(card_ds)
		var d1b: Button = _find_button(board.popup_layer, "D1")
		if d1b: d1b.pressed.emit()
		var ds_ok: bool = (d1 in pds.discard) and board.playing_card.is_empty()
		print("[%s] op discard: 1 scartata + then play_another" % ["OK" if ds_ok else "FAIL"])
		if not ds_ok: fails += 1

		# op reset_influence (regione): protegge una Influenza temporanea.
		var prs: PlayerState = board._active()
		board.gs.regions["africa"]["track"].add(prs.power, "temporary")
		board.gs.regions["africa"]["track"].add(prs.power, "temporary")
		var card_rs := {"display_name": "RS", "effect_ops": [{"op": "reset_influence"}]}
		prs.hand.append(card_rs); board._plays_left = 9
		board._play_card(card_rs)
		var rs_await: bool = board.awaiting == "reset_influence"
		board._on_region_pressed("africa")
		var rs_ok: bool = rs_await and board.playing_card.is_empty()
		print("[%s] op reset_influence: scelta Regione e reset" % ["OK" if rs_ok else "FAIL"])
		if not rs_ok: fails += 1

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
			board._commerce_flipped = {}   # carte prodotto tutte scoperte all'inizio
			var serv_pre: int = seller.resources["services"]
			# Forziamo una Trade Deals con import_from dal venditore + 1 sua carta prodotto
			# (consumer_goods), così dopo l'acquisto resta a 0 carte scoperte.
			board.trade_deals = {"cards": [{"power": buyer.power, "exports": 2, "imports": 2,
				"import_from": {seller_power: ["consumer_goods"]}}],
				"commerce_cards": {seller_power: [{"consumer_goods": 1}]}}
			var src: Array = board._import_sources(buyer, "consumer_goods")
			board._open_trade_ui()
			board._trade_adjust("consumer_goods", "import", 1)
			var b_money_pre: int = buyer.money
			var dip_buyer_pre: int = buyer.resources["diplomacy"]
			board._trade_confirm()
			var cost: int = Actions.IMPORT_COST["consumer_goods"]
			var p2p_ok: bool = src.size() == 1 and String(src[0]["src"]) == seller_power \
				and seller.money == cost \
				and seller.resources["services"] == serv_pre + 1 \
				and buyer.money == b_money_pre - cost \
				and buyer.resources["diplomacy"] == dip_buyer_pre + 1 \
				and (board._commerce_flipped.get(seller_power, []) as Array).size() == 1 \
				and board._trade_import_cap(buyer, "consumer_goods") == 0  # unica carta girata
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
		board._focus_round = {}     # non ancora scelto il Focus questo round
		board._do_focus(WO.Focus.MILITARY)
		var readied: int = pf.exhausted.values().count(false)
		var focus_ok: bool = pf.focus == WO.Focus.MILITARY and readied == 3 and board._plays_left == 1 \
			and pf.armies_available == 2 and pf.resources["raw_materials"] == 3   # Focus gratis (Preparation)
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
		var slot_bc: Button = _find_button(board.popup_layer, "Temporanea")
		if slot_bc: slot_bc.pressed.emit()

		# Modifiers: carta Engage con sconto -1 Diplomacy per Armata schierata.
		var pmod2: PlayerState = board._active()
		pmod2.resources["diplomacy"] = 20
		var mreg := "central_asia"
		board.gs.regions[mreg]["armies"][pmod2.power] = 3
		# Prerequisito Engage (pag. 13): serve una Country alleata nella Regione. La
		# aggiungo solo per questo test e la rimuovo dopo (niente sconto: la salto).
		var pre_ally := {"id": "country_engage_pre", "region": mreg, "value": 1}
		pmod2.allied_countries.append(pre_ally)
		var raw_cost: int = int(board.gs.regions[mreg]["engage_cost"])
		var diplo := pmod2.focus == WO.Focus.DIPLOMATIC
		var expected_cost: int = Actions.engage_cost(raw_cost, [], diplo, 3)
		var dip_pre: int = pmod2.resources["diplomacy"]
		var card_mod := {"display_name": "Engage scontato", "effect_ops": [{"op": "engage"}],
			"effect_modifiers": ["engage_discount_per_army"]}
		pmod2.hand.append(card_mod)
		board._plays_left = 9
		board._play_card(card_mod)
		board._on_region_pressed(mreg)
		var skip_b: Button = _find_button(board.popup_layer, "Salta (nessuno sconto)")
		if skip_b: skip_b.pressed.emit()   # popup sconto: non esaurisco alleati
		var slot_bm: Button = _find_button(board.popup_layer, "Temporanea")  # scelta slot
		if slot_bm: slot_bm.pressed.emit()
		var spent: int = dip_pre - pmod2.resources["diplomacy"]
		var mod_ok: bool = spent == expected_cost and (card_mod in pmod2.played)
		print("[%s] effect_modifier: Engage costa %d (sconto -3 per Armata)" % ["OK" if mod_ok else "FAIL", spent])
		if not mod_ok: fails += 1
		pmod2.allied_countries.erase(pre_ally)   # ripristina lo stato per i test successivi

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

		# #11 — meccanica Market scarto/ricambio (su stato controllato, poi ripristino).
		var _save_disp: Array = board.market_display.duplicate()
		var _save_deck: Array = board.market_deck.duplicate()
		board.market_display = [{"id": "m0"}, {"id": "m1"}, {"id": "m2"}, {"id": "m3"}, {"id": "m4"}]
		board.market_deck = [{"id": "d0"}, {"id": "d1"}, {"id": "d2"}, {"id": "d3"}]
		board._market_take(board.market_display[2])   # compra m2 → nuova carta a sinistra
		var take_ok: bool = board.market_display.size() == 5 \
			and String(board.market_display[0]["id"]) == "d3" \
			and String(board.market_display[1]["id"]) == "m0" \
			and String(board.market_display[3]["id"]) == "m3"
		print("[%s] Market #11: la carta comprata è sostituita a sinistra" % ["OK" if take_ok else "FAIL"])
		if not take_ok: fails += 1
		board.market_display = [{"id": "a0"}, {"id": "a1"}, {"id": "a2"}, {"id": "a3"}, {"id": "a4"}]
		board.market_deck = [{"id": "e0"}, {"id": "e1"}, {"id": "e2"}]
		board._market_discard_rightmost(3)            # scarta le 3 a destra, rivela 3 a sinistra
		var mdisc_ok: bool = board.market_display.size() == 5 \
			and String(board.market_display[3]["id"]) == "a0" \
			and String(board.market_display[4]["id"]) == "a1"
		print("[%s] Market #11: scarta le 3 a destra, rivela 3 a sinistra" % ["OK" if mdisc_ok else "FAIL"])
		if not mdisc_ok: fails += 1
		var endn: int = board._market_end_discard_count()
		var expect_end: int = {2: 2, 3: 1}.get(board.gs.players.size(), 0)
		print("[%s] Market #11: scarto fine Research = %d (%d giocatori)" % ["OK" if endn == expect_end else "FAIL", endn, board.gs.players.size()])
		if endn != expect_end: fails += 1
		board.market_display = _save_disp
		board.market_deck = _save_deck

		# #12 — esaurendo una Country alleata ready, il Research aumenta del suo valore.
		var pres: PlayerState = board._active()
		board._research_points = 4
		var ally12 := {"id": "country_res12", "display_name": "ResTest", "region": "africa", "value": 2}
		pres.allied_countries.append(ally12)
		pres.exhausted["country_res12"] = false
		board._research_exhaust_ally(ally12)
		var res12_ok: bool = board._research_points == 6 and bool(pres.exhausted.get("country_res12", false))
		print("[%s] Research #12: esaurire una Country aggiunge il suo valore (+2)" % ["OK" if res12_ok else "FAIL"])
		if not res12_ok: fails += 1
		pres.allied_countries.erase(ally12)

		# Growth: acquisto della prossima Growth (azione "Get a Growth Card", non Research).
		var ag: Array = board._available_growth(ac)
		if ag.size() > 0:
			var gcard: Dictionary = ag[0]
			ac.money = 50
			for rt in ac.resources: ac.resources[rt] = 10
			var vp_pre: int = ac.victory_points
			var growth_pre: int = ac.growth_cards.size()
			board._buy_growth_action(gcard, board._next_growth_level(ac))
			var g_ok: bool = ac.growth_cards.size() == growth_pre + 1 \
				and ac.victory_points == vp_pre + int(gcard.get("victory_points", 0))
			print("[%s] acquisto Growth (azione): carta acquisita (+%d VP)" % ["OK" if g_ok else "FAIL", int(gcard.get("victory_points", 0))])
			if not g_ok: fails += 1

		# Return on Investments (1° passo Aftermath): +2 money per FDI × valore Paese.
		var prr: PlayerState = board._active()
		board.gs.round = 1                      # niente Scoring
		prr.fdi_values = [3, 2]
		prr.resources["consumer_goods"] = 0     # niente Prosperità (isola il money)
		prr.money = 0
		board._run_aftermath()
		var roi_ok: bool = prr.money == 10       # 2*(3+2)
		board._close_popup()
		print("[%s] Return on Investments: +10 money (FDI 3+2 ×2)" % ["OK" if roi_ok else "FAIL"])
		if not roi_ok: fails += 1

		# Reveal Country Cards (Preparation): ruota una carta disponibile della Regione.
		var rev_rid := ""
		for r0 in board.region_countries:
			if (board.region_countries[r0]["deck"] as Array).size() > 0 and (board.region_countries[r0]["available"] as Array).size() > 0:
				rev_rid = r0; break
		if rev_rid != "":
			var old_first: Dictionary = board.region_countries[rev_rid]["available"][0]
			board._reveal_country_cards()
			var new_first: Dictionary = board.region_countries[rev_rid]["available"][0]
			var rev_ok: bool = old_first != new_first
			print("[%s] Reveal Country Cards: carta ruotata in %s" % ["OK" if rev_ok else "FAIL", rev_rid])
			if not rev_ok: fails += 1

		# Focus in Preparation: gratis e una sola volta per round (il 2° clic non ri-prepara).
		var pf2: PlayerState = board._active()
		pf2.production = {}                      # niente produce per isolare il ready
		board.gs.round = 2
		board._focus_round = {}
		pf2.exhausted = {"x": true, "y": true, "z": true}
		board._do_focus(WO.Focus.DOMESTIC)       # Domestic prepara 1
		var r1: int = pf2.exhausted.values().count(false)
		pf2.exhausted = {"x": true, "y": true}   # ri-esaurisci
		board._do_focus(WO.Focus.MILITARY)       # già scelto stesso round → solo marker
		var r2: int = pf2.exhausted.values().count(false)
		var once_ok: bool = r1 == 1 and r2 == 0 and pf2.focus == WO.Focus.MILITARY
		print("[%s] Focus 1×/round (gratis): 2° clic non ri-prepara" % ["OK" if once_ok else "FAIL"])
		if not once_ok: fails += 1

		# Aftermath interattivo (#5/#6/#7): scelte invece di automatismi (ultimo uso di `board`).
		var pam: PlayerState = board.gs.players[0]
		board.gs.round = 1
		for pp in board.gs.players:
			pp.fdi_values = []
			pp.engage_tokens = []
		pam.money = 0
		pam.prosperity_level = 0
		pam.resources["consumer_goods"] = 5
		pam.engage_tokens = ["africa", "europe"]
		pam.allied_countries = [{"id": "aa", "region": "africa", "value": 1},
			{"id": "ab", "region": "africa", "value": 1}, {"id": "ae", "region": "europe", "value": 1}]
		board._run_aftermath()
		var prosp_auto_ok: bool = pam.prosperity_level == 0          # #7: NON è automatica
		board._aftermath_token_money(pam, "africa")                 # #6: 5 × 2 Country = 10
		var roi6_ok: bool = pam.money == 10 and not ("africa" in pam.engage_tokens)
		board._aftermath_token_defense(pam, "europe")               # #5: 2 × 1 = +2 Difesa
		var def5_ok: bool = int((board._threat_defense.get("europe", {}) as Dictionary).get(pam.power, 0)) == 2 \
			and not ("europe" in pam.engage_tokens)
		board._aftermath_prosperity(pam)                            # #7: scelta → avanza
		var prosp_ok: bool = pam.prosperity_level == 1
		var after_ok: bool = prosp_auto_ok and roi6_ok and def5_ok and prosp_ok
		print("[%s] Aftermath interattivo: Prosperità a scelta (#7) + Engage→money (#6) + Engage→Difesa (#5)" % ["OK" if after_ok else "FAIL"])
		if not after_ok: fails += 1
		board._close_popup()

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

	# #9/#10 Auto-Influence: 2 carte/round + money commercio condizionato (board 2 giocatori).
	var saved_ai_powers: Array = GameConfig.powers
	GameConfig.powers = ["usa", "china"]
	var bai: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(bai)
	await process_frame
	# #10 — gira le carte prodotto finché ce ne sono di scoperte (EU ne ha 2).
	bai._commerce_flipped = {}
	var f1: bool = bai._commerce_flip_any("eu")   # carta 1 → true
	var f2: bool = bai._commerce_flip_any("eu")   # carta 2 → true
	var f3: bool = bai._commerce_flip_any("eu")   # tutte girate → false
	var flip_ok: bool = f1 and f2 and not f3
	# #9 — applica 2 carte (deck di 2); #10 — China incassa 10 (1 trade_with, 1 Commerce).
	bai._commerce_flipped = {}
	bai._auto_inf_deck = [
		{"art": "y", "rows": {"russia": {"region": "africa", "army": false, "trade_with": null},
			"eu": {"region": "south_asia", "army": false, "trade_with": null}}},
		{"art": "x", "rows": {"russia": {"region": "central_asia", "army": false, "trade_with": "china"},
			"eu": {"region": "europe", "army": false, "trade_with": null}}}]
	var china_m0: int = bai.gs.player_by_power("china").money
	var ai_lines: Array = []
	bai._apply_auto_influence(ai_lines)
	var two_cards: bool = bai._auto_inf_deck.is_empty()
	var money10: bool = bai.gs.player_by_power("china").money == china_m0 + 10
	var ai_ok: bool = flip_ok and two_cards and money10
	print("[%s] Auto-Influence #9/#10: 2 carte applicate + commercio condizionato (China +10)" % ["OK" if ai_ok else "FAIL"])
	if not ai_ok: fails += 1
	bai.queue_free()
	GameConfig.powers = saved_ai_powers

	# Trade da potenza NEUTRALE (2 giocatori): la Cina compra energia dalla Russia (neutrale).
	var saved_np: Array = GameConfig.powers
	GameConfig.powers = ["china", "usa"]
	var bn: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(bn)
	await process_frame
	var chi: int = 0
	for ii in bn.gs.players.size():
		if bn.gs.players[ii].power == "china": chi = ii
	bn.active_seat = chi
	var chn: PlayerState = bn.gs.players[chi]
	chn.allied_countries = []          # nessuna sorgente "banca": solo la Russia
	chn.resources["energy"] = 0
	chn.resources["diplomacy"] = 0
	chn.money = 100
	bn._commerce_flipped = {}
	var nsrcs: Array = bn._import_sources(chn, "energy")
	var has_russia := false
	for s in nsrcs:
		if String(s["src"]) == "russia": has_russia = true
	bn._open_trade_ui()
	bn._trade_pick_src("energy", "russia")
	bn._trade_set_target("energy", 2)   # compra 2 energia dalla Russia (neutrale)
	bn._trade_confirm()
	var neutral_ok: bool = has_russia \
		and chn.resources["energy"] == 2 \
		and chn.resources["diplomacy"] == 0 \
		and chn.money == 100 - Actions.IMPORT_COST["energy"] * 2 \
		and (bn._commerce_flipped.get("russia", []) as Array).size() == 1
	print("[%s] Trade da potenza neutrale (Russia): compra senza +1 Diplomazia, Commerce girate" % ["OK" if neutral_ok else "FAIL"])
	if not neutral_ok: fails += 1
	bn.queue_free()
	GameConfig.powers = saved_np

	# Regressione Move: dopo "Fine spostamento" non devono restare barre su
	# popup_layer. I duplicati (rinominati da Godot quando il queue_free differito
	# lasciava la vecchia barra in scena) si accumulavano e bloccavano _end_turn
	# -> partita congelata. _hide_move_bar ora li rimuove via metadata.
	var bm: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(bm)
	await process_frame
	var seat0: int = bm.active_seat
	var mp: PlayerState = bm._active()
	mp.armies_available = 3
	var mcard := {"display_name": "MoveReg", "effect_ops": [{"op": "move", "count": 3}]}
	mp.hand.append(mcard); bm._plays_left = 1
	bm._play_card(mcard)
	bm._region_do_drop(Vector2.ZERO, {"move_src": "_reserve"}, "europe")
	bm._region_do_drop(Vector2.ZERO, {"move_src": "_reserve"}, "americas")
	bm._finish_move()
	await process_frame
	var stray_bars := 0
	for ch in bm.popup_layer.get_children():
		if ch.has_meta("move_bar"): stray_bars += 1
	bm._end_turn()
	var move_ok: bool = bm.awaiting == "" and stray_bars == 0 and bm.active_seat != seat0
	print("[%s] Move: nessuna barra residua e Fine turno avanza (no freeze)" % ["OK" if move_ok else "FAIL"])
	if not move_ok: fails += 1

	# Regressione clamp mappa: su un asse dove la mappa è più piccola della viewport
	# _clamp_map deve CENTRARE in modo stabile (prima rimbalzava -> sfarfallio nel pan).
	bm.map_viewport.size = Vector2(400, 800)
	bm.map_content.scale = Vector2(0.3, 0.3)      # board 660x589: X>vp, Y<vp
	bm.map_content.position = Vector2(-100, 9999)
	bm._clamp_map(); var cp1: Vector2 = bm.map_content.position
	bm._clamp_map(); var cp2: Vector2 = bm.map_content.position
	bm._pan(Vector2(-50, 0)); var cp3: Vector2 = bm.map_content.position
	var clamp_ok: bool = cp1.is_equal_approx(cp2) and not is_equal_approx(cp3.x, cp1.x) and is_equal_approx(cp3.y, cp1.y)
	print("[%s] Mappa zoomata: clamp stabile (no sfarfallio), pan sull'asse libero" % ["OK" if clamp_ok else "FAIL"])
	if not clamp_ok: fails += 1
	bm.queue_free()

	print("Verifica UI: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(fails)


## Prima Regione con almeno una Country disponibile.
func gs_first_region(board: Node) -> String:
	for rid in board.region_countries:
		if (board.region_countries[rid]["available"] as Array).size() > 0:
			return rid
	return ""


func _find_button(node: Node, text: String) -> Button:
	if node == null or node.is_queued_for_deletion():
		return null   # ignora i popup già chiusi (queue_free è differito)
	for c in node.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Button and text in (c as Button).text:
			return c
		var r := _find_button(c, text)
		if r:
			return r
	return null
