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

	return {"passed": c["passed"], "failed": c["failed"], "log": log}
