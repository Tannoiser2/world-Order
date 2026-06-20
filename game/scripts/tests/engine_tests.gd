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

	# --- 6. Ordine di turno (meno VP per primo) ---
	var gt := GameSetup.new_game(["usa", "china", "russia"])
	gt.players[0].victory_points = 10
	gt.players[1].victory_points = 5
	gt.players[2].victory_points = 20
	GamePhases.determine_turn_order(gt)
	check.call("turn order: chi ha meno VP per primo", gt.turn_order[0] == 1)

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
	check.call("execute Improve Relations", Actions.execute_improve_relations(ga, "usa", au, [2]))
	check.call("Improve Relations: Country alleato aggiunto", usa.allied_countries.size() == 1)
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
