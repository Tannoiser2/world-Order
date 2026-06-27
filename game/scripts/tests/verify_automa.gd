extends SceneTree
## Verifica della parte DETERMINISTICA del motore Automa (bot, solo mode).
## Vedi docs/automa-rules.md e game/scripts/engine/automa.gd.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_automa.gd

func _init() -> void:
	var fails := 0

	# 1) Setup dalla Player card: USA parte con 50 money e 10 VP.
	var a := Automa.from_setup("usa")
	var s1: bool = a.power == "usa" and a.money == 50 and a.vp == 10
	print("[%s] from_setup USA: money=%d vp=%d" % ["OK" if s1 else "FAIL", a.money, a.vp])
	if not s1: fails += 1

	# 2) Money per Focus = round * moltiplicatore (Dom x10, Dip x5, Mil x3).
	var fm_ok: bool = Automa.focus_money(WO.Focus.DIPLOMATIC, 4) == 20 \
		and Automa.focus_money(WO.Focus.DOMESTIC, 3) == 30 \
		and Automa.focus_money(WO.Focus.MILITARY, 6) == 18
	print("[%s] focus_money: Dip@4=%d, Dom@3=%d, Mil@6=%d" % ["OK" if fm_ok else "FAIL",
		Automa.focus_money(WO.Focus.DIPLOMATIC, 4), Automa.focus_money(WO.Focus.DOMESTIC, 3),
		Automa.focus_money(WO.Focus.MILITARY, 6)])
	if not fm_ok: fails += 1

	# 3) Azione dal tipo carta via Automa board: cubo nello spazio SINISTRO -> quell'azione,
	#    sposta 1 cubo a destra.
	a.action_cubes = {"engage": 1, "improve_relations": 0}
	var d := a.board_action_for_type("diplomatic")
	var s3: bool = d["action"] == "engage" and d["cube_from"] == "engage" \
		and d["cube_to"] == "improve_relations" and int(d["cube_count"]) == 1
	print("[%s] diplomatic con cubo a sinistra -> Engage (%s)" % ["OK" if s3 else "FAIL", str(d)])
	if not s3: fails += 1

	# 4) Nessun cubo a sinistra -> azione DESTRA, sposta TUTTI i cubi a sinistra.
	a.action_cubes = {"engage": 0, "improve_relations": 2}
	var d2 := a.board_action_for_type("diplomatic")
	var s4: bool = d2["action"] == "improve_relations" and d2["cube_from"] == "improve_relations" \
		and d2["cube_to"] == "engage" and int(d2["cube_count"]) == 2
	print("[%s] diplomatic senza cubo a sinistra -> Improve Relations, sposta 2 (%s)" % [
		"OK" if s4 else "FAIL", str(d2)])
	if not s4: fails += 1

	# 5) apply_cube_move aggiorna i conteggi.
	a.action_cubes = {"invest": 1, "trade": 0}
	var de := a.board_action_for_type("economic")   # cubo in invest (sinistra) -> Invest, 1 a destra
	a.apply_cube_move(de)
	var s5: bool = de["action"] == "invest" and int(a.action_cubes.get("invest", 0)) == 0 \
		and int(a.action_cubes.get("trade", 0)) == 1
	print("[%s] economic: Invest e cubo spostato (invest=%d trade=%d)" % ["OK" if s5 else "FAIL",
		int(a.action_cubes.get("invest", 0)), int(a.action_cubes.get("trade", 0))])
	if not s5: fails += 1

	# 6) Carta domestic -> Get a Growth Card o money (nessun cubo).
	var dd := a.board_action_for_type("domestic")
	var s6: bool = dd["action"] == "get_growth_or_money" and int(dd["cube_count"]) == 0
	print("[%s] domestic -> get_growth_or_money (%s)" % ["OK" if s6 else "FAIL", str(dd["action"])])
	if not s6: fails += 1

	# 7) Trade: 5 money per simbolo Export.
	var s7: bool = Automa.trade_gain(3) == 15 and Automa.trade_gain(0) == 0
	print("[%s] trade_gain(3)=%d, trade_gain(0)=%d" % ["OK" if s7 else "FAIL",
		Automa.trade_gain(3), Automa.trade_gain(0)])
	if not s7: fails += 1

	# 8) Get a Growth Card: VP = VP carta + Livello (es. 6 + 3 = 9).
	var s8: bool = Automa.growth_vp(6, 3) == 9
	print("[%s] growth_vp(6,3)=%d" % ["OK" if s8 else "FAIL", Automa.growth_vp(6, 3)])
	if not s8: fails += 1

	# 9) Aftermath - Return on Investments: +5 money per FDI.
	var b := Automa.from_setup("usa")
	b.fdi = {"europe": 2, "africa": 1}
	var roi := b.return_on_investments()
	var s9: bool = roi == 15 and b.money == 50 + 15
	print("[%s] return_on_investments: +%d money (tot %d)" % ["OK" if s9 else "FAIL", roi, b.money])
	if not s9: fails += 1

	# 10) Aftermath - Increase Prosperity: con 20 money avanza il 1° spazio (costo 10 -> +2 VP).
	var c := Automa.from_setup("usa")
	c.money = 20
	var pv := c.increase_prosperity()
	var s10: bool = pv == 2 and c.prosperity_level == 1 and c.money == 10 and c.vp == 12
	print("[%s] increase_prosperity: +%d VP (livello=%d, money=%d, vp=%d)" % [
		"OK" if s10 else "FAIL", pv, c.prosperity_level, c.money, c.vp])
	if not s10: fails += 1

	# ---- Stadio 2: scelte delle azioni ----

	# 11) Auto-Influence: Regione e Armata per questo Automa (la sua riga).
	var card := {"rows": {"usa": {"region": "americas", "army": true}, "china": {"region": "europe", "army": false}}}
	var t := Automa.from_setup("usa")
	var s11: bool = t.auto_influence_region(card) == "americas" and t.auto_influence_army(card) == true
	print("[%s] auto_influence_region/army: %s / %s" % ["OK" if s11 else "FAIL",
		t.auto_influence_region(card), str(t.auto_influence_army(card))])
	if not s11: fails += 1

	# 12) Conteggio alleati per Regione (totali e quelli che consentono una Base).
	t.allied_countries = [
		{"id": "e1", "region": "europe", "has_base_symbol": true, "base_allowed_powers": ["usa"], "exports": ["food"]},
		{"id": "e2", "region": "europe", "has_base_symbol": false, "base_allowed_powers": [], "exports": ["energy", "food"]},
		{"id": "a1", "region": "africa", "has_base_symbol": true, "base_allowed_powers": ["eu"], "exports": []},
	]
	var s12: bool = t.allies_in_region("europe") == 2 and t.base_allies_in_region("europe") == 1 \
		and t.base_allies_in_region("africa") == 0   # base_allowed eu, non usa
	print("[%s] allies europe=%d base-allies europe=%d africa=%d" % ["OK" if s12 else "FAIL",
		t.allies_in_region("europe"), t.base_allies_in_region("europe"), t.base_allies_in_region("africa")])
	if not s12: fails += 1

	# 13) Invest: max FDI = 1 + alleati; can_invest finché sotto il massimo, e con alleati.
	var s13a: bool = t.invest_fdi_max("europe") == 3 and t.can_invest("europe")  # 0 < 3
	t.fdi = {"europe": 3}
	var s13b: bool = not t.can_invest("europe")          # 3 < 3 falso
	var s13c: bool = not t.can_invest("south_asia")      # 0 alleati
	var s13: bool = s13a and s13b and s13c
	print("[%s] invest: max=3, pieno e senza-alleati bloccano (a=%s b=%s c=%s)" % [
		"OK" if s13 else "FAIL", str(s13a), str(s13b), str(s13c)])
	if not s13: fails += 1

	# 14) Build a Base: max = 1 + alleati-con-Base; serve almeno un alleato con Base.
	var s14a: bool = t.base_max("europe") == 2 and t.can_build_base("europe")  # 1 base-ally
	t.bases = {"europe": 2}
	var s14b: bool = not t.can_build_base("europe")   # 2 < 2 falso
	var s14c: bool = not t.can_build_base("africa")   # 0 base-ally (eu, non usa)
	var s14: bool = s14a and s14b and s14c
	print("[%s] build base: max=2, pieno e senza-base-ally bloccano (a=%s b=%s c=%s)" % [
		"OK" if s14 else "FAIL", str(s14a), str(s14b), str(s14c)])
	if not s14: fails += 1

	# 15) Engage cost: 5/diplomazia, -5 per alleato in Regione, -5 se Diplomatic Focus, min 0.
	t.focus = WO.Focus.DOMESTIC
	var c_dom: int = t.engage_cost("europe", 4)     # 20 - 2*5 = 10
	t.focus = WO.Focus.DIPLOMATIC
	var c_dip: int = t.engage_cost("europe", 4)     # 20 - 10 - 5 = 5
	var c_min: int = t.engage_cost("europe", 1)     # 5 - 10 - 5 -> 0
	var s15: bool = c_dom == 10 and c_dip == 5 and c_min == 0
	print("[%s] engage_cost: domestic=%d diplomatic=%d min=%d" % ["OK" if s15 else "FAIL", c_dom, c_dip, c_min])
	if not s15: fails += 1

	# 16) Improve Relations - scelta della Country (criteri + accessibilità).
	var u := Automa.from_setup("usa")   # 50 money
	var avail := [
		{"id": "a", "value": 1, "has_base_symbol": false, "base_allowed_powers": []},
		{"id": "b", "value": 3, "has_base_symbol": true, "base_allowed_powers": ["usa"]},
		{"id": "c", "value": 2, "has_base_symbol": true, "base_allowed_powers": ["usa"]},
	]
	# Starting Country "c" -> criterio 1 vince.
	var pick1: Dictionary = u.improve_relations_pick(avail, ["c"])
	# Nessuna starting: criterio 2 (Base) restringe a b,c; criterio 3 (valore) -> b (value 3).
	var pick2: Dictionary = u.improve_relations_pick(avail, [])
	# Accessibilità: con 10 money, b (costo 15) escluso; tra a(5) e c(10), c ha Base -> c.
	u.money = 10
	var pick3: Dictionary = u.improve_relations_pick(avail, [])
	# Nessuna accessibile: con 4 money, ritorna {} (-> il chiamante fa Trade).
	u.money = 4
	var pick4: Dictionary = u.improve_relations_pick(avail, [])
	var s16: bool = pick1.get("id", "") == "c" and pick2.get("id", "") == "b" \
		and pick3.get("id", "") == "c" and pick4.is_empty()
	print("[%s] improve_relations_pick: start=%s base/val=%s afford=%s none=%s" % [
		"OK" if s16 else "FAIL", pick1.get("id", "-"), pick2.get("id", "-"), pick3.get("id", "-"), str(pick4.is_empty())])
	if not s16: fails += 1

	# 17) Trade dalle Country alleate: 5 per simbolo Export (qui 1 + 2 + 0 = 3 -> 15).
	var s17: bool = t.trade_gain_from_allies() == 15
	print("[%s] trade_gain_from_allies=%d" % ["OK" if s17 else "FAIL", t.trade_gain_from_allies()])
	if not s17: fails += 1

	# 18) Opzione attivabile: GameConfig.is_automa riflette automa_powers (vuoto = nessun bot).
	var saved: Array = GameConfig.automa_powers
	GameConfig.automa_powers = []
	var off_ok: bool = not GameConfig.is_automa("china")
	GameConfig.automa_powers = ["china", "russia"]
	var on_ok: bool = GameConfig.is_automa("china") and not GameConfig.is_automa("usa")
	GameConfig.automa_powers = saved
	var s18: bool = off_ok and on_ok
	print("[%s] solo mode opzionale: off=%s on=%s" % ["OK" if s18 else "FAIL", str(off_ok), str(on_ok)])
	if not s18: fails += 1

	# ---- Stadio 3: Research/Market e Aftermath (Adding Influence) ----

	# 19) Punti Research: bonus + 1 ogni 3 alleati + 2 se Domestic Focus.
	var s19: bool = Automa.research_points(8, 7, true) == 12 and Automa.research_points(5, 2, false) == 5
	print("[%s] research_points: (8,7,dom)=%d (5,2,-)=%d" % ["OK" if s19 else "FAIL",
		Automa.research_points(8, 7, true), Automa.research_points(5, 2, false)])
	if not s19: fails += 1

	# 20) Scelta carta dal Market: piu' costosa accessibile; tie -> market_priority; tie -> recente.
	var prio := ["military", "economic", "diplomatic", "domestic"]
	var market := [
		{"id": "m_recent_eco", "cost": 8, "type": "economic"},   # index 0 = piu' recente
		{"id": "m_mil", "cost": 8, "type": "military"},          # stesso costo, tipo prioritario
		{"id": "m_cheap", "cost": 3, "type": "domestic"},
		{"id": "m_expensive", "cost": 20, "type": "diplomatic"}, # non accessibile con 10
	]
	# Con 10 money: accessibili 8/8/3; max 8; tie eco vs mil -> military (priorita' piu' alta).
	var mk1: Dictionary = Automa.pick_market_card(market, 10, prio)
	# Con 5 money: solo la domestic da 3.
	var mk2: Dictionary = Automa.pick_market_card(market, 5, prio)
	# Con 2 money: nessuna -> {}.
	var mk3: Dictionary = Automa.pick_market_card(market, 2, prio)
	var s20: bool = mk1.get("id", "") == "m_mil" and mk2.get("id", "") == "m_cheap" and mk3.is_empty()
	print("[%s] pick_market_card: prio=%s low=%s none=%s" % ["OK" if s20 else "FAIL",
		mk1.get("id", "-"), mk2.get("id", "-"), str(mk3.is_empty())])
	if not s20: fails += 1

	# 21) Scelta dello slot Influenza: un solo tipo -> quello; entrambi -> Decision card.
	var s21: bool = Automa.influence_slot_choice(true, false, true) == "permanent" \
		and Automa.influence_slot_choice(false, true, true) == "temporary" \
		and Automa.influence_slot_choice(true, true, true) == "permanent" \
		and Automa.influence_slot_choice(true, true, false) == "temporary" \
		and Automa.influence_slot_choice(false, false, true) == ""
	print("[%s] influence_slot_choice (perm/temp/decision)" % ["OK" if s21 else "FAIL"])
	if not s21: fails += 1

	# 22) "Non spingere fuori una propria temporanea": riconosce il caso (fila piena, FIFO = sua).
	var trk := InfluenceTrack.new([1, 1], [4, 3, 2, 1])
	trk.temp = ["usa", "china", "china", "china"]   # piena, il primo a uscire e' usa
	var au := Automa.from_setup("usa")
	var push_yes: bool = au.temp_pushes_own(trk)
	var trk2 := InfluenceTrack.new([1, 1], [4, 3, 2, 1])
	trk2.temp = ["china", "usa", null, null]         # c'e' spazio -> nessuno spinto fuori
	var push_no: bool = au.temp_pushes_own(trk2)
	var s22: bool = push_yes and not push_no
	print("[%s] temp_pushes_own: piena-FIFO-sua=%s con-spazio=%s" % ["OK" if s22 else "FAIL",
		str(push_yes), str(push_no)])
	if not s22: fails += 1

	# 23) Adding Influence: Normal ridisegna se spinge la propria temp; Hard forza permanente.
	au.difficulty_hard = false
	var n_choice: String = au.add_influence_decision(false, true, false, true)   # solo temp, spinge -> redraw
	au.difficulty_hard = true
	var h_choice: String = au.add_influence_decision(false, true, false, true)   # solo temp, spinge -> permanent_forced
	var both_ok: String = au.add_influence_decision(true, true, true, false)     # entrambi, decision perm -> permanent
	var s23: bool = n_choice == "redraw" and h_choice == "permanent_forced" and both_ok == "permanent"
	print("[%s] add_influence_decision: normal=%s hard=%s both=%s" % ["OK" if s23 else "FAIL",
		n_choice, h_choice, both_ok])
	if not s23: fails += 1

	print("Verifica motore Automa (core deterministico): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
