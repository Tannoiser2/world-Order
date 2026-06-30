extends SceneTree
## Orientamenti Strategici (Diplomacy & Dominance) — 4 nuove carte Strategiche fattibili:
##   - TEST NUCLEARI (Russia): spend + place_armies su 3 Regioni FISSE + add_influence
##     ristretto a quelle 3 Regioni.
##   - POLO PRODUTTIVO GLOBALE (Cina): Trade + Produce limitato a energia/materie/beni.
##   - INIZIATIVA GLOBAL GATEWAY (UE): Invest + scelta (niente / spendi 10 e Investi ancora).
##   - GIGANTE ECONOMICO (UE): choose_n (2 di 3: Commercia / Produci 2 tipi / Investi).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_strategic_orientamenti.gd

var _fails := 0

func _init() -> void:
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["russia", "china", "eu", "usa"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION

	var sa: Dictionary = _by_id("res://data/strategic_assets.json")
	await _test_test_nucleari(b, sa["sa_russia_test_nucleari"])
	await _test_polo_produttivo(b, sa["sa_china_polo_produttivo_globale"])
	await _test_global_gateway(b, sa["sa_eu_iniziativa_global_gateway"])
	await _test_gigante(b, sa["sa_eu_gigante_economico"])

	b.queue_free()
	await process_frame
	print("Verifica Orientamenti Strategici: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1


func _by_id(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var out := {}
	for c in d["cards"]:
		out[String(c["id"])] = c
	return out


## Avvia l'attivazione di un Asset Strategico sul seggio indicato.
func _play_sa(b: Variant, seat: int, asset: Dictionary) -> void:
	b.active_seat = seat
	b._plays_left = 1
	b._played_this_turn = false
	b.playing_card = {}
	b.play_queue = []
	b.awaiting = ""
	var p = b.gs.players[seat]
	var hc := {"display_name": "costo"}
	p.hand = [hc]
	p.strategic_assets = [asset]
	p.used_strategic_assets = []
	b._play_strategic_asset(hc, asset)


func _test_test_nucleari(b: Variant, asset: Dictionary) -> void:
	var p = b.gs.players[0]
	p.money = 30
	p.resources["services"] = 2
	for rid in ["europe", "central_asia", "east_asia_pacific"]:
		b.gs.regions[rid]["armies"]["russia"] = 0
	_play_sa(b, 0, asset)
	await process_frame
	# spend + 3 place_armies eseguiti automaticamente; ci si ferma sulla scelta Influenza.
	var armies_ok := true
	for rid in ["europe", "central_asia", "east_asia_pacific"]:
		if int(b.gs.regions[rid]["armies"].get("russia", 0)) != 1:
			armies_ok = false
	_check(armies_ok, "TEST NUCLEARI: 1 Armata in Europa/Asia centrale/Asia or.-Pacifico")
	_check(p.money == 5 and int(p.resources["services"]) == 1, "TEST NUCLEARI: speso 25 money + 1 Servizi (money=%d serv=%d)" % [p.money, int(p.resources["services"])])
	var regs: Array = b._influence_pick.get("regions", [])
	var restricted: bool = b.awaiting == "influence_cell" and regs.size() == 3 \
		and "europe" in regs and "central_asia" in regs and "east_asia_pacific" in regs
	_check(restricted, "TEST NUCLEARI: Influenza ristretta alle 3 Regioni (%s)" % str(regs))
	# Completa la scelta dell'Influenza su una delle 3 Regioni.
	b._on_influence_cell("europe", "temporary")
	await process_frame
	_check(b.playing_card.is_empty(), "TEST NUCLEARI: risolta (carta chiusa)")


func _test_polo_produttivo(b: Variant, asset: Dictionary) -> void:
	var p = b.gs.players[1]
	p.production = {"energy": 2, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0, "armies": 0}
	p.resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	_play_sa(b, 1, asset)
	await process_frame
	_check(b._trade_mode, "POLO PRODUTTIVO: prima azione = Commercia (trade UI aperta)")
	# Commercio vuoto -> avanza alla Produzione.
	b._trade_sel = {"export": {}, "import": {}}
	b._trade_import_src = {}
	b._trade_armies = 0
	b._apply_trade()
	await process_frame
	var allowed: Array = b._produce_allowed
	var only3: bool = b._produce_mode and allowed.size() == 3 \
		and "energy" in allowed and "raw_materials" in allowed and "consumer_goods" in allowed
	_check(only3, "POLO PRODUTTIVO: Produzione limitata a energia/materie/beni (%s)" % str(allowed))
	_check(b._produce_type_allowed("energy") and not b._produce_type_allowed("food"),
		"POLO PRODUTTIVO: energia ammessa, cibo no")
	# Produci 2 Energia.
	b._produce_sel = {"energy": 2}
	b._apply_produce()
	await process_frame
	_check(int(p.resources.get("energy", 0)) == 2 and b.playing_card.is_empty(),
		"POLO PRODUTTIVO: prodotte 2 Energia e carta chiusa (energia=%d)" % int(p.resources.get("energy", 0)))


func _test_global_gateway(b: Variant, asset: Dictionary) -> void:
	var p = b.gs.players[2]
	p.money = 60
	p.allied_countries = [
		{"id": "gg_a", "display_name": "Alfa", "value": 1, "invest_cost": 5, "region": "europe"},
		{"id": "gg_b", "display_name": "Beta", "value": 1, "invest_cost": 5, "region": "africa"},
	]
	p.exhausted = {}
	p.fdi_countries = []
	b.gs.supply["fdi"] = 8
	_play_sa(b, 2, asset)
	await process_frame
	_check(b.awaiting == "allied_country", "GLOBAL GATEWAY: prima azione = Invest (scelta Nazione alleata)")
	# Investi sulla prima Nazione (gestendo l'eventuale scelta di slot Influenza).
	b._on_allied_pressed(p.allied_countries[0])
	await process_frame
	if b.awaiting == "influence_cell":
		b._on_influence_cell("europe", "temporary")
		await process_frame
	var choice_ok: bool = b._popup_active() and b._popup_items.size() == 2
	_check(choice_ok, "GLOBAL GATEWAY: scelta 'investire ancora' con 2 opzioni")
	if choice_ok:
		var lbls := []
		for it in b._popup_items: lbls.append(String((it as Dictionary).get("label", "")))
		_check("Niente" in lbls and ("Spendi + Investi" in lbls or "Spendi" in str(lbls)),
			"GLOBAL GATEWAY: etichette leggibili (%s)" % str(lbls))
	# Scegli "Niente" (opzione 0): la carta si chiude.
	b.apply_command(GameCommands.popup_choice(2, b._next_seq(), 0))
	await process_frame
	_check(b.playing_card.is_empty() and "gg_a" in p.fdi_countries,
		"GLOBAL GATEWAY: risolta, prima Nazione investita")


func _test_gigante(b: Variant, asset: Dictionary) -> void:
	var p = b.gs.players[2]
	p.production = {"energy": 2, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0, "armies": 0}
	p.resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	_play_sa(b, 2, asset)
	await process_frame
	var first_ok: bool = b._popup_active() and b._popup_items.size() == 3
	_check(first_ok, "GIGANTE: choose_n -> prima scelta (3 opzioni)")
	if first_ok:
		var lbls := []
		for it in b._popup_items: lbls.append(String((it as Dictionary).get("label", "")))
		_check("Commercia" in lbls and "Produci" in lbls and "Investi" in lbls,
			"GIGANTE: etichette Commercia/Produci/Investi (%s)" % str(lbls))
	# Scegli "Commercia" (indice 0).
	b.apply_command(GameCommands.popup_choice(2, b._next_seq(), 0))
	await process_frame
	_check(b._popup_active() and b._popup_items.size() == 2, "GIGANTE: seconda scelta (2 opzioni rimaste)")
	# Scegli "Produci" (ora indice 0 tra [Produci, Investi]).
	b.apply_command(GameCommands.popup_choice(2, b._next_seq(), 0))
	await process_frame
	_check(b._trade_mode, "GIGANTE: scelte 2 azioni -> risolve Commercia per prima (trade UI)")
	# Commercio vuoto -> Produzione (2 tipi).
	b._trade_sel = {"export": {}, "import": {}}
	b._trade_import_src = {}
	b._trade_armies = 0
	b._apply_trade()
	await process_frame
	_check(b._produce_mode and b._produce_max_types == 2, "GIGANTE: poi Produci 2 tipi (limite=%d)" % b._produce_max_types)
	b._produce_sel = {"energy": 2}
	b._apply_produce()
	await process_frame
	_check(b.playing_card.is_empty(), "GIGANTE: risolta (carta chiusa)")
