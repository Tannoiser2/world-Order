class_name EngineTests
extends RefCounted
## Test del motore che riproducono gli esempi numerici del regolamento.
## Eseguibili headless: vedi run_tests.gd. Logica gia' validata in Python
## (tools: cfr. commit), qui verificata nel porting GDScript.

static func run_all() -> Dictionary:
	var log: Array[String] = []
	var c := {"passed": 0, "failed": 0}  # Dictionary = riferimento, aggiornabile dal lambda

	var check := func(name: String, cond: bool) -> void:
		if cond:
			c["passed"] += 1
			log.append("  [OK] " + name)
		else:
			c["failed"] += 1
			log.append("  [FAIL] " + name)

	# --- 1. Influence track: FIFO temporaneo (Europe 5-4-3-2) ---
	var t := InfluenceTrack.new([1, 1, 1, 1], [5, 4, 3, 2])
	check.call("temp slot 1 = 5 VP", t.add("a", "temporary") == 5)
	check.call("temp slot 2 = 4 VP", t.add("b", "temporary") == 4)
	check.call("temp slot 3 = 3 VP", t.add("c", "temporary") == 3)
	check.call("temp slot 4 = 2 VP", t.add("d", "temporary") == 2)
	check.call("temp pieno: push = 0 VP", t.add("e", "temporary") == 0)
	check.call("FIFO: 'a' spinto fuori", t.temp == ["b", "c", "d", "e"])

	# --- 1b. Reset e Convert dell'Influenza temporanea ---
	var rt := InfluenceTrack.new([1, 1], [4, 3, 2, 1])
	rt.temp = ["x", "a", "b", "c"]  # 'a' (idx 1) con cubi a destra
	check.call("Reset: sposta il cubo protetto a destra", rt.reset_temporary("a"))
	check.call("Reset: 'a' ora all'ultima posizione", rt.temp == ["x", "b", "c", "a"])
	check.call("Reset senza cubi a destra: nessun effetto", not rt.reset_temporary("a"))
	var ct := InfluenceTrack.new([1, 1], [4, 3, 2, 1])
	ct.temp = ["a", "b", "c", null]
	check.call("Convert temp->perm riuscita", ct.convert_temp_to_permanent("a"))
	check.call("Convert: 'a' in permanente", ct.perm[0] == "a")
	check.call("Convert: temporanei scorrono a sinistra", ct.temp == ["b", "c", null, null])

	# --- 2. Scoring Regione: esempio MENA (regolamento pag. 20) ---
	# Alex(usa) 4, Anna(eu) 3, Jim(russia) 3, Kate(china) 1; armate Jim 4, Anna 1;
	# 1 cubo locale (nero) pari con Kate. Stato costruito direttamente (lo scoring
	# conta i cubi presenti, a prescindere da come ci sono arrivati).
	var mt := InfluenceTrack.new([1, 1], [4, 3, 2, 1])
	mt.perm = ["usa", "local"]
	mt.temp = ["usa", "usa", "usa", "eu", "eu", "eu", "russia", "russia", "russia", "china"]
	var armies := {"russia": 4, "eu": 1}
	var players := ["usa", "eu", "russia", "china"]
	var res := Scoring.score_region(mt, [10, 7, 4, 2], armies, players)
	check.call("USA 1°: 4 cubi + 10 = 14", res.get("usa", 0) == 14)
	check.call("Russia 2° (piu' armate): 3 + 7 = 10", res.get("russia", 0) == 10)
	check.call("EU 3°: 3 + 4 = 7", res.get("eu", 0) == 7)
	check.call("China pari col locale (ultima): 1 + 0 = 1", res.get("china", 0) == 1)

	# Regione senza permanenti pieni non segna.
	var ut := InfluenceTrack.new([1, 1], [4, 3, 2, 1])
	ut.add("usa", "permanent")  # 1 permanente vuoto rimane
	check.call("Regione con permanenti non pieni non segna", Scoring.score_region(ut, [10, 7, 4, 2], {}, players).is_empty())

	# --- THREAT: Esempio 1 (Central Asia, regolamento pag. 19) ---
	# zone russia+china; armate china 2, russia 1, eu 1. Russia perde 2 (China > Difesa 1).
	var l1 := Threat.resolve_region(["russia", "china"], {"china": 2, "russia": 1, "eu": 1}, {}, {})
	check.call("THREAT ex1: Russia perde 2", int(l1.get("russia", 0)) == 2)
	check.call("THREAT ex1: China non perde", int(l1.get("china", 0)) == 0)
	check.call("THREAT ex1: EU (fuori zona) non controlla", not l1.has("eu"))
	# Variante: se EU avesse 2 Armate, Russia perderebbe 4.
	var l1b := Threat.resolve_region(["russia", "china"], {"china": 2, "russia": 1, "eu": 2}, {}, {})
	check.call("THREAT ex1 variante: Russia perde 4", int(l1b.get("russia", 0)) == 4)

	# --- THREAT: Esempio 2 (Europe) ---
	# armate usa 3, russia 2, eu 1; Russia ha Military Focus (+1 THREAT/Difesa);
	# EU scarta Engage (+6 Difesa); USA/EU = NATO. Nessuno perde VP.
	var l2 := Threat.resolve_region(
		["usa", "eu", "russia"],
		{"usa": 3, "russia": 2, "eu": 1},
		{"russia": true},
		{"eu": 6},
		[["usa", "eu"]])
	check.call("THREAT ex2: nessuna perdita (NATO + Difesa)", l2.is_empty())

	# --- 3. Setup partita (smoke) ---
	var gs := GameSetup.new_game(["usa", "china"])
	check.call("setup: 2 giocatori", gs.players.size() == 2)
	check.call("setup: 7 Regioni", gs.regions.size() == 7)
	check.call("setup: cubo USA iniziale in Americas",
		gs.regions["americas"]["track"].count("usa") == 1)
	check.call("setup: Engage MENA = 6", gs.regions["middle_east_north_africa"]["engage_cost"] == 6)
	check.call("setup: mazzo iniziale USA non vuoto", gs.players[0].deck.size() > 0)
	check.call("setup: denaro iniziale USA 30 / Cina 20",
		gs.player_by_power("usa").money == 30 and gs.player_by_power("china").money == 20)
	check.call("setup: Armate iniziali = Produzione Armate (USA)",
		gs.player_by_power("usa").armies_available == int(gs.player_by_power("usa").production.get("armies", 0)))

	# --- 4. Produzione e cap risorse ---
	var ps := PlayerState.new()
	ps.production = {"energy": 3}
	GamePhases.produce_primary_resources_for(ps)
	check.call("produzione Energia = 3", ps.resources["energy"] == 3)
	# Cap a 10: oltre il 10 si converte in money (import cost 3 per primaria).
	ps.resources["energy"] = 10
	var of := ps.gain_resource("energy", 2, GamePhases.IMPORT_COST_PRIMARY)
	check.call("cap a 10: Energia resta 10", ps.resources["energy"] == 10)
	check.call("cap: eccedenza in money (2 x 3 = 6)", of == 6 and ps.money == 6)

	# --- 5. Prosperity ---
	var pp := PlayerState.new()
	pp.resources["consumer_goods"] = 5
	var steps := [{"cost_consumer_goods": 2, "vp": 2, "money": 10}]
	check.call("prosperity avanza", GamePhases.increase_prosperity(pp, steps))
	check.call("prosperity: -2 CG, +2 VP, +10 money",
		pp.resources["consumer_goods"] == 3 and pp.victory_points == 2 and pp.money == 10)
	check.call("prosperity: max 1 step/round", not GamePhases.increase_prosperity(pp, steps))

	# --- 6. Ordine di turno (PIÙ VP per primo, regolamento pag. 9) ---
	var gt := GameSetup.new_game(["usa", "china", "russia"])
	gt.players[0].victory_points = 10
	gt.players[1].victory_points = 5
	gt.players[2].victory_points = 20
	GamePhases.determine_turn_order(gt)
	check.call("turn order: chi ha più VP per primo", gt.turn_order[0] == 2)

	# --- 7. Azioni: calcoli di costo (aritmetica degli esempi del regolamento) ---
	# Improve Relations: Australia(3), exhaust Singapore(2) -> 1.
	check.call("Improve Relations costo 3-2=1", Actions.improve_relations_cost(3, [2]) == 1)
	# Engage: MENA(6), exhaust Jordan(1)+Qatar(2) -> 3; con Diplomatic Focus -> 1.
	check.call("Engage costo 6-(1+2)=3", Actions.engage_cost(6, [1, 2], false) == 3)
	check.call("Engage Diplomatic Focus -2: 6-3-2=1", Actions.engage_cost(6, [1, 2], true) == 1)
	# Trade: Jim esporta 4 Energia + 2 Materie Prime = 30.
	check.call("Export 4 Energia + 2 Materie Prime = 30",
		Actions.export_gain([{"type": "energy", "qty": 4}, {"type": "raw_materials", "qty": 2}]) == 30)
	# Import 2 Services = 20.
	check.call("Import 2 Services = 20", Actions.import_cost([{"type": "services", "qty": 2}]) == 20)
	# Trade op: le risorse si MUOVONO davvero (export toglie, import aggiunge) oltre al money.
	var gtr := GameSetup.new_game(["usa", "china"])
	var ptr := gtr.player_by_power("usa")
	ptr.resources = {"energy": 4, "raw_materials": 2}
	ptr.money = 0
	EffectExecutor.run(gtr, "usa", [{"op": "trade",
		"exports": [{"type": "energy", "qty": 4}],
		"imports": [{"type": "raw_materials", "qty": 2}]}])
	check.call("Trade: export 4 Energia toglie l'Energia", int(ptr.resources.get("energy", -1)) == 0)
	check.call("Trade: import 2 Materie aggiunge risorsa", int(ptr.resources.get("raw_materials", 0)) == 4)
	check.call("Trade: money = +20 (4*5) - 6 (2*3) = 14", ptr.money == 14)
	# Produzione secondaria CONSUMA le primarie: beni di consumo = energia + materie prime.
	var gpc := GameSetup.new_game(["usa", "china"])
	var ppc := gpc.player_by_power("usa")
	ppc.production = {"consumer_goods": 2}
	ppc.resources = {"energy": 3, "raw_materials": 3, "consumer_goods": 0}
	var made := Actions.execute_produce(ppc, "consumer_goods")
	check.call("Produce 2 Beni di consumo consuma 2 Energia + 2 Materie", made == 2 and int(ppc.resources["energy"]) == 1 and int(ppc.resources["raw_materials"]) == 1)
	# Build a Base: 5 + 5*2 = 15 (esempio Turkey, 2 Armate).
	check.call("Build Base 5 + 5*2 = 15", Actions.build_base_cost(2) == 15)
	# Move: 2 Armate = 10.
	check.call("Move 2 Armate = 10", Actions.move_cost(2) == 10)

	# --- 8. Azioni: esecuzione su GameState ---
	var ga := GameSetup.new_game(["usa", "china"])
	var usa := ga.player_by_power("usa")
	# Improve Relations con 1 Diplomacy disponibile.
	usa.resources["diplomacy"] = 5
	var au := {"id": "country_australia", "value": 3, "region": "east_asia_pacific"}
	var usa_allies0: int = usa.allied_countries.size()   # parte con 2 alleati iniziali
	check.call("execute Improve Relations", Actions.execute_improve_relations(ga, "usa", au, [2]))
	check.call("Improve Relations: Country alleato aggiunto", usa.allied_countries.size() == usa_allies0 + 1)
	check.call("Improve Relations: speso 1 Diplomacy", usa.resources["diplomacy"] == 4)
	# Engage in East Asia-Pacific (Engage cost 5): paga 5 Diplomacy, +1 Influenza.
	usa.resources["diplomacy"] = 10
	var inf_before: int = ga.regions["east_asia_pacific"]["track"].count("usa")
	var vp := Actions.execute_engage(ga, "usa", "east_asia_pacific", [], false, "temporary")
	check.call("execute Engage: VP >= 0", vp >= 0)
	check.call("Engage: speso 5 Diplomacy", usa.resources["diplomacy"] == 5)
	check.call("Engage: +1 Influenza in regione",
		ga.regions["east_asia_pacific"]["track"].count("usa") == inf_before + 1)
	# Invest: Country ready, costo 15, FDI + Influenza in regione.
	usa.money = 100
	var pk := {"id": "country_x", "value": 3, "invest_cost": 15, "region": "south_asia"}
	usa.exhausted["country_x"] = false
	var fdi_before: int = ga.supply["fdi"]
	Actions.execute_invest(ga, "usa", pk, "temporary")
	check.call("Invest: speso 15 money", usa.money == 85)
	check.call("Invest: Country exhausted", usa.exhausted["country_x"] == true)
	check.call("Invest: FDI dalla riserva", ga.supply["fdi"] == fdi_before - 1)
	# Build a Base: Country con base + flag usa, muove 2 Armate (costo 15).
	usa.money = 100
	usa.armies_available = 3
	var bc := {"id": "country_b", "value": 4, "region": "middle_east_north_africa",
		"has_base_symbol": true, "base_allowed_powers": ["usa"]}
	usa.exhausted["country_b"] = false
	Actions.execute_build_base(ga, "usa", bc, 2, "temporary")
	check.call("Build Base: speso 15 money", usa.money == 85)
	check.call("Build Base: 2 Armate in regione",
		int(ga.regions["middle_east_north_africa"]["armies"].get("usa", 0)) == 2)
	check.call("Build Base: Armate scalate dalla riserva giocatore", usa.armies_available == 1)
	# Get a Growth Card: Tactical Flexibility (Lv3, costo 3 Services + 15 money, +6 VP).
	var cn := ga.player_by_power("china")
	cn.resources["services"] = 3
	cn.money = 20
	cn.victory_points = 0
	var tf := {"display_name": "Tactical Flexibility", "level": 3, "cost": {"services": 3, "money": 15}, "victory_points": 6}
	check.call("Get Growth (livello giusto)", Actions.execute_get_growth(cn, tf, 3))
	check.call("Get Growth: +6 VP", cn.victory_points == 6)
	check.call("Get Growth: livello sbagliato fallisce", not Actions.execute_get_growth(cn, tf, 1))
	# Produce: primaria (Energia prod 3) e secondaria (Consumer Goods: 1 Energia + 1 Materie Prime).
	var pr := PlayerState.new()
	pr.production = {"energy": 3, "consumer_goods": 2}
	check.call("Produce primaria Energia = 3", Actions.execute_produce(pr, "energy") == 3)
	pr.resources["raw_materials"] = 2
	check.call("Produce secondaria Consumer Goods = 2", Actions.execute_produce(pr, "consumer_goods") == 2)
	check.call("Produce CG: speso 2 Energia + 2 Materie Prime",
		pr.resources["energy"] == 1 and pr.resources["raw_materials"] == 0 and pr.resources["consumer_goods"] == 2)

	# --- 9. Aftermath: token Maggioranza (esempio regolamento pag. 21) ---
	# Most Money [5,3,1]: Kate 121, Anna 78, Alex 54, Jim 49.
	var money_maj := Aftermath.score_majority(
		{"kate": 121, "anna": 78, "alex": 54, "jim": 49}, [5, 3, 1])
	check.call("Maggioranza money: Kate 5, Anna 3, Alex 1, Jim 0",
		money_maj["kate"] == 5 and money_maj["anna"] == 3 and money_maj["alex"] == 1 and int(money_maj.get("jim", 0)) == 0)
	# Most Armies [6,3,1]: Alex 8, Jim 5, Kate 5 -> Jim/Kate pari 2°, prendono il 3° (1).
	var army_maj := Aftermath.score_majority({"alex": 8, "jim": 5, "kate": 5, "anna": 0}, [6, 3, 1])
	check.call("Maggioranza armate: Alex 6; Jim/Kate pari -> 1 ciascuno",
		army_maj["alex"] == 6 and army_maj["jim"] == 1 and army_maj["kate"] == 1)
	# Most Countries [7,4,2]: Anna 10, Alex 9, Jim 8, Kate 8 -> Jim/Kate pari 3° -> posizione piu' bassa (4°) = 0.
	var ctry_maj := Aftermath.score_majority({"anna": 10, "alex": 9, "jim": 8, "kate": 8}, [7, 4, 2])
	check.call("Maggioranza paesi: Anna 7, Alex 4, Jim/Kate 0",
		ctry_maj["anna"] == 7 and ctry_maj["alex"] == 4 and ctry_maj["jim"] == 0 and ctry_maj["kate"] == 0)
	# 2 giocatori: solo il 1° assoluto segna; pareggio = nessuno.
	check.call("2p: solo il vincitore segna",
		Aftermath.score_majority({"a": 5, "b": 3}, [5, 3, 1], true) == {"a": 5})
	check.call("2p: pareggio -> nessuno",
		Aftermath.score_majority({"a": 5, "b": 5}, [5, 3, 1], true).is_empty())

	# --- 10. Return on Investments (esempio pag. 19) ---
	# Anna: FDI su Paesi di valore 1,1,3 -> 2+2+6=10; scarta Engage in Africa con 2 alleati -> 10. Totale 20.
	var pa := PlayerState.new()
	var roi := Aftermath.return_on_investments(pa, [1, 1, 3], [2])
	check.call("Return on Investments: 10 (FDI) + 10 (Engage) = 20", roi == 20 and pa.money == 20)

	# --- 11. Abilita' speciali di fine partita ---
	var bd := DataLoader.load_board()
	var ssp: Dictionary = bd["global"]["power_special_scoring"]
	check.call("USA Global Superpower Status: 2 Regioni -> -5",
		Aftermath.global_superpower_status_penalty(2, ssp["global_superpower_status_penalty"]) == -5)
	check.call("USA: 4+ Regioni -> nessuna penalita'",
		Aftermath.global_superpower_status_penalty(4, ssp["global_superpower_status_penalty"]) == 0)
	check.call("Russia Secured Sphere: 3 Regioni -> 6 VP",
		Aftermath.secured_sphere_vp(3, int(ssp["secured_sphere_vp_per_region"])) == 6)
	check.call("China Global FDI Network: 5 Regioni -> 4 VP",
		Aftermath.global_fdi_network_vp(5, ssp["global_fdi_network"]) == 4)
	check.call("China Global FDI Network: 7 Regioni -> 8 VP",
		Aftermath.global_fdi_network_vp(7, ssp["global_fdi_network"]) == 8)

	# --- 11b. Effetti delle carte come micro-DSL (EffectExecutor) ---
	var ge := GameSetup.new_game(["usa", "china"])
	var u2 := ge.player_by_power("usa")
	u2.resources["diplomacy"] = 5
	var u2_allies0: int = u2.allied_countries.size()   # parte con 2 alleati iniziali
	# "New Allies": improve_relations (Country e sconti risolti dalla UI/bot).
	EffectExecutor.run(ge, "usa", [
		{"op": "improve_relations", "country": {"id": "c1", "value": 2, "region": "europe"}, "exhaust_values": [2]}])
	check.call("DSL New Allies: Country alleato aggiunto", u2.allied_countries.size() == u2_allies0 + 1)
	# "Military Reinforcements": gain 1 Army, poi Move fino a 2.
	u2.money = 100
	EffectExecutor.run(ge, "usa", [
		{"op": "gain_armies", "amount": 1},
		{"op": "move", "moves": [{"region": "americas"}]}])
	check.call("DSL Military Reinforcements: Armata sul board",
		int(ge.regions["americas"]["armies"].get("usa", 0)) == 1)
	# "Military Pact" (USA unica): Build a Base, poi gain 1 Diplomacy.
	u2.money = 100
	u2.armies_available = 2
	u2.resources["diplomacy"] = 0
	EffectExecutor.run(ge, "usa", [
		{"op": "build_base", "country": {"id": "cb", "value": 2, "region": "middle_east_north_africa",
			"has_base_symbol": true, "base_allowed_powers": ["usa"]}, "armies": 1},
		{"op": "gain_resource", "type": "diplomacy", "amount": 1}])
	check.call("DSL Military Pact: +1 Diplomacy dopo Build a Base", u2.resources["diplomacy"] == 1)
	# "Growth Strategy": choice -> Produce (il giocatore ha scelto Produce).
	var cprod := ge.player_by_power("china")
	cprod.production = {"energy": 2}
	cprod.resources["energy"] = 0   # azzera le risorse iniziali (= produzione) per testare il delta
	EffectExecutor.run(ge, "china", [
		{"op": "choice", "chosen": [{"op": "produce", "types": ["energy"]}]}])
	check.call("DSL Growth Strategy (choice=Produce): +2 Energia", cprod.resources["energy"] == 2)

	# --- 11c. Copertura: effect_ops di tutte le carte ---
	var all_cards := []
	for pw in ["usa", "eu", "russia", "china"]:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/abilities/%s_starting.json" % pw))
		if d: all_cards.append_array(d.get("cards", []))
	for f in ["market_cards.json", "growth_cards.json", "strategic_assets.json"]:
		var d2: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + f))
		if d2: all_cards.append_array(d2.get("cards", []))
	var with_ops := 0
	var unknown_ops := {}
	var collect := func(ops: Array, acc: Dictionary, self_ref: Callable) -> void:
		for o in ops:
			if o is Dictionary and o.has("op"):
				var nm := String(o["op"])
				if nm not in EffectExecutor.KNOWN:
					acc[nm] = true
				for key in ["options", "body", "then", "chosen"]:
					if o.get(key) is Array:
						for item in o[key]:
							if item is Array:
								self_ref.call(item, acc, self_ref)
							elif item is Dictionary and item.has("op"):
								self_ref.call([item], acc, self_ref)
				if o.get("gain") is Dictionary and o["gain"].has("op"):
					self_ref.call([o["gain"]], acc, self_ref)
	var gx := GameSetup.new_game(["usa", "china"])
	for card in all_cards:
		if card.has("effect_ops"):
			with_ops += 1
			collect.call(card["effect_ops"], unknown_ops, collect)
			# esegue senza crash (op contestuali = deferred, non errori)
			EffectExecutor.run(gx, "usa", card["effect_ops"])
	check.call("carte con effect_ops codificati (>=95)", with_ops >= 95)
	check.call("nessuna op sconosciuta nel dataset", unknown_ops.is_empty())
	log.append("  (info) carte con effect_ops: %d" % with_ops)

	# --- 11d. Research/Market e Add Auto-Influence ---
	var rp := PlayerState.new()
	# 2 carte rivelate: research 1+1; top bonus 3 money + 1 diplomacy; +2 Domestic Focus.
	var revealed := [
		{"research_bonus": 1, "top_bonus": {"amount": 3, "kind": "money"}},
		{"research_bonus": 1, "top_bonus": {"amount": 1, "kind": "diplomacy"}}]
	var avail := GamePhases.research_step(rp, revealed, true)
	check.call("Research: 1+1 +2 (Domestic) = 4", avail == 4)
	check.call("Research: top bonus 3 money", rp.money == 3)
	check.call("Research: top bonus 1 Diplomacy", rp.resources["diplomacy"] == 1)
	var spent := GamePhases.buy_market_card(rp, {"market_cost": 4, "id": "mk_x"}, avail)
	check.call("Market: compra carta da 4 Research", spent == 4 and rp.deck.size() == 1)
	check.call("Market: Research insufficiente -> -1",
		GamePhases.buy_market_card(rp, {"market_cost": 7, "id": "y"}, 4) == -1)
	# Add Auto-Influence: partita 2 giocatori (usa, china); applica una carta per
	# Russia/EU (non controllati): aggiunge Influenza/Armata e paga il trade.
	var gai := GameSetup.new_game(["usa", "china"])
	var ai_card := {"rows": {
		"usa": {"region": "americas", "army": false, "trade_with": null},
		"china": {"region": "east_asia_pacific", "army": false, "trade_with": null},
		"russia": {"region": "central_asia", "army": true, "trade_with": "china"},
		"eu": {"region": "europe", "army": false, "trade_with": null}}}
	var ru_before: int = gai.regions["central_asia"]["track"].count("russia")
	var tps := GamePhases.add_auto_influence(gai, ai_card, ["usa", "china"])
	check.call("Auto-Influence: +1 Influenza Russia in Central Asia",
		gai.regions["central_asia"]["track"].count("russia") == ru_before + 1)
	check.call("Auto-Influence: +1 Armata Russia in Central Asia",
		int(gai.regions["central_asia"]["armies"].get("russia", 0)) == 1)
	# Il money del commercio è ora a carico del chiamante: l'engine ritorna i
	# giocatori 'trade_with' (qui China, indicata dalla riga di Russia).
	check.call("Auto-Influence: trade_with ritorna China", "china" in tps)

	# --- 11b. Modifiers: sconti condizionali (effect_modifiers) ---
	var mods := Modifiers.parse(["improve_discount:1", "engage_discount_per_army",
		"engage_discount_per_allied", "engage_discount_1_in:europe,africa", "pay_money_for_services:10"])
	check.call("parse modifier chiave:valore", int(mods.get("improve_discount", 0)) == 1)
	check.call("parse modifier flag", mods.get("engage_discount_per_army", false) == true)
	check.call("improve_discount = 1", Modifiers.improve_discount(mods) == 1)
	check.call("money_for_services = 10", Modifiers.money_for_services(mods) == 10)
	var gmod := GameSetup.new_game(["usa", "china"])
	gmod.regions["europe"]["armies"]["usa"] = 2
	var pu := gmod.player_by_power("usa")
	pu.allied_countries.clear()   # ignora gli alleati iniziali per isolare il test
	pu.allied_countries.append({"region": "europe", "value": 3})
	# Engage in Europe: 2 (per armata) + 1 (per alleato) + 1 (sconto fisso Europe) = 4
	check.call("engage_discount Europe (army+allied+region) = 4",
		Modifiers.engage_discount(mods, gmod, "usa", "europe") == 4)
	# Africa: nessuna armata/alleato la', solo lo sconto fisso = 1
	check.call("engage_discount Africa (solo fisso) = 1",
		Modifiers.engage_discount(mods, gmod, "usa", "africa") == 1)
	check.call("engage_discount senza modifier = 0",
		Modifiers.engage_discount({}, gmod, "usa", "europe") == 0)

	# --- 13. Audit regole↔meccanica (fix 2026-06-22) ---
	# Item 14 — Trade: il bene da 20 è ARMATE; la Diplomazia non è commerciabile.
	check.call("Trade: Export Armate = 20 cad. (2 = 40)",
		Actions.export_gain([{"type": "armies", "qty": 2}]) == 40)
	check.call("Trade: Diplomazia non esportabile (0)",
		Actions.export_gain([{"type": "diplomacy", "qty": 3}]) == 0)
	# Item 15 — Improve Relations: potenza vietata non può allearsi.
	var gfix := GameSetup.new_game(["usa", "china"])
	var ufix := gfix.player_by_power("usa")
	ufix.resources["diplomacy"] = 10
	var iran := {"id": "country_iran", "value": 2, "region": "middle_east_north_africa", "no_relations_powers": ["usa"]}
	var allies_before: int = ufix.allied_countries.size()
	check.call("Improve Relations: potenza vietata fallisce",
		not Actions.execute_improve_relations(gfix, "usa", iran, []))
	check.call("Improve Relations: nessun alleato aggiunto se vietato",
		ufix.allied_countries.size() == allies_before)
	# Item 16 — Engage: serve almeno 1 Country alleata nella Regione.
	ufix.resources["diplomacy"] = 20
	# USA non ha alleati in Africa (alleati iniziali: europe/east_asia/mena/americas).
	check.call("Engage senza alleato nella Regione fallisce",
		Actions.execute_engage(gfix, "usa", "africa", [], false, "temporary") == -1)
	check.call("Engage con alleato (east_asia_pacific: Japan) riesce",
		Actions.execute_engage(gfix, "usa", "east_asia_pacific", [], false, "temporary") >= 0)
	# Item 17 — Invest una sola volta per Country.
	ufix.money = 100
	var inv_c := {"id": "country_inv", "value": 2, "invest_cost": 15, "region": "south_asia"}
	ufix.exhausted["country_inv"] = false
	Actions.execute_invest(gfix, "usa", inv_c, "temporary")
	ufix.exhausted["country_inv"] = false   # torna ready, ma ha già un FDI
	check.call("Invest: seconda volta sullo stesso Country fallisce",
		Actions.execute_invest(gfix, "usa", inv_c, "temporary") == -1)
	# Item 17 — Build a Base una sola volta per Country.
	ufix.money = 100
	ufix.armies_available = 4
	var base_c := {"id": "country_base", "value": 2, "region": "middle_east_north_africa",
		"has_base_symbol": true, "base_allowed_powers": ["usa"]}
	ufix.exhausted["country_base"] = false
	Actions.execute_build_base(gfix, "usa", base_c, 1, "temporary")
	ufix.exhausted["country_base"] = false
	check.call("Build a Base: seconda volta sullo stesso Country fallisce",
		Actions.execute_build_base(gfix, "usa", base_c, 1, "temporary") == -1)
	# Item 18 — Move: destinazione valida solo in zona di interesse o con Base.
	var gmov := GameSetup.new_game(["russia", "usa"])
	var rmov := gmov.player_by_power("russia")
	check.call("Move: Europe (zona Russia) valida",
		Actions.move_dest_valid(gmov, rmov, "europe"))
	check.call("Move: Americas (fuori zona, no Base) NON valida",
		not Actions.move_dest_valid(gmov, rmov, "americas"))
	rmov.armies_available = 1
	check.call("Move fuori zona fallisce", not Actions.execute_move(gmov, "russia", [{"region": "americas"}]))
	# Item 20 — Produce/Diplomazia: l'eccesso oltre 10 va PERSO, non in money.
	var pdip := PlayerState.new()
	pdip.resources["diplomacy"] = 10
	var of_dip := pdip.gain_resource("diplomacy", 3, 10)
	check.call("Diplomazia oltre 10: eccesso perso (0 money)",
		of_dip == 0 and pdip.money == 0 and pdip.resources["diplomacy"] == 10)
	# Item 8 — NATO solo se entrambe le potenze sono in gioco.
	check.call("NATO: assente senza EU", Threat.nato_pairs(["usa", "china"]) == [])
	check.call("NATO: presente con USA+EU", Threat.nato_pairs(["usa", "eu", "russia"]) == [["usa", "eu"]])

	# --- 13b. Abilità speciali nello scoring reale + bonus fine partita ---
	# Item 1 — USA Global Superpower Status applicata: 2 Regioni di maggioranza → −5.
	var gusa := GameSetup.new_game(["usa", "china"])
	for rid in gusa.regions:
		gusa.regions[rid]["track"] = InfluenceTrack.new([1], [4, 3, 2, 1])
		gusa.regions[rid]["armies"] = {}
	gusa.regions["americas"]["track"].add("usa", "permanent")
	gusa.regions["europe"]["track"].add("usa", "permanent")
	check.call("USA: Regioni con maggioranza Influenza = 2",
		GameRunner.count_majority_influence_regions(gusa, "usa") == 2)
	var usa_vp0: int = gusa.player_by_power("usa").victory_points
	var sp_usa := GameRunner.apply_power_special_scoring(gusa)
	check.call("USA: penalità −5 applicata allo scoring", int(sp_usa.get("usa", 0)) == -5
		and gusa.player_by_power("usa").victory_points == usa_vp0 - 5)
	# Item 1 — Russia Secured Sphere: 2 Regioni di zona con più Armate → +4.
	var grus := GameSetup.new_game(["russia", "usa"])
	for rid in grus.regions:
		grus.regions[rid]["armies"] = {}
	grus.regions["central_asia"]["armies"] = {"russia": 2, "usa": 1}
	grus.regions["europe"]["armies"] = {"russia": 2}
	check.call("Russia: Regioni di zona con più Armate = 2",
		GameRunner.count_zone_most_armies_regions(grus, "russia") == 2)
	check.call("Russia: Secured Sphere +4 applicata",
		int(GameRunner.apply_power_special_scoring(grus).get("russia", 0)) == 4)
	# Item 1/3/2 — China FDI Network + Strategic Asset (+2) + Executive Order (+3) a fine partita.
	var gchn := GameSetup.new_game(["china", "usa"])
	var chn := gchn.player_by_power("china")
	chn.fdi_countries = []
	for ac in chn.allied_countries:
		chn.fdi_countries.append(String(ac.get("id", "")))   # 4 Paesi in 4 Regioni distinte
	check.call("China: Regioni con FDI = 4", GameRunner.count_fdi_regions(gchn, "china") == 4)
	var eb := GameRunner.apply_game_end_bonuses(gchn)
	# china: FDI(4→3) + 2 Strategic Asset non usati (×2=4) + Executive Order (3) = 10.
	check.call("China: fine partita = 3 (FDI) + 4 (SA) + 3 (Exec) = 10", int(eb.get("china", 0)) == 10)
	# Item 2 — Executive Order usata e 0 Strategic Asset → nessun bonus.
	var gex := GameSetup.new_game(["eu", "usa"])
	var euex := gex.player_by_power("eu")
	euex.executive_order_used = true
	euex.strategic_assets.clear()
	check.call("Executive Order usata + 0 SA → 0 bonus",
		int(GameRunner.apply_game_end_bonuses(gex).get("eu", 0)) == 0)
	# Item 4 — Spareggio vincitore: più Regioni col 1° bonus Maggioranza nel scoring finale.
	var gwin := GameSetup.new_game(["usa", "china"])
	for p in gwin.players:
		p.victory_points = 50
	for rid in gwin.regions:
		gwin.regions[rid]["track"] = InfluenceTrack.new([1], [4, 3, 2, 1])
		gwin.regions[rid]["armies"] = {}
	gwin.regions["americas"]["track"].add("usa", "permanent")   # USA leader unico → 1° bonus
	gwin.regions["europe"]["track"].add("usa", "permanent")
	gwin.regions["south_asia"]["track"].add("china", "permanent")
	var fm := GameRunner.first_majority_region_counts(gwin)
	check.call("Spareggio: USA 2 / China 1 Regioni col 1° bonus",
		int(fm.get("usa", 0)) == 2 and int(fm.get("china", 0)) == 1)
	check.call("Spareggio vincitore (VP pari) = USA", GameRunner.winner(gwin) == "usa")

	# --- 12. Simulazione end-to-end (integrazione) ---
	var fin := GameRunner.run_game(["usa", "china", "russia", "eu"], 42)
	check.call("partita completata: 6 round", fin.round == 6)
	check.call("partita: 4 giocatori con stato", fin.players.size() == 4)
	var win := GameRunner.winner(fin)
	check.call("partita: vincitore determinato", win != "")
	var any_vp := false
	for p in fin.players:
		if p.victory_points != 0:
			any_vp = true
	check.call("partita: VP assegnati", any_vp)
	log.append("  (info) Vincitore simulazione: %s con %d VP" % [win, fin.player_by_power(win).victory_points])

	return {"passed": c["passed"], "failed": c["failed"], "log": log}
