extends SceneTree
## Obiettivi Superpotenze (D&D): motore di valutazione delle condizioni e del punteggio
## (1/2/3 condizioni soddisfatte -> reward[0/1/2] VP), con soglie distinte round 3 | round 6.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_objectives.gd

var _fails := 0

func _init() -> void:
	var gs: GameState = GameSetup.new_game(["usa", "eu", "russia", "china"])
	var usa := gs.player_by_power("usa")

	# --- Soglie per round (ri=0 round3, ri=1 round6) ---
	usa.money = 50
	_chk(Objectives.condition_met(gs, "usa", {"t": "money", "min": [40, 80]}, 0), "money 50 >= 40 (round3)")
	_chk(not Objectives.condition_met(gs, "usa", {"t": "money", "min": [40, 80]}, 1), "money 50 < 80 (round6)")

	# --- Risorse / economia ---
	usa.resources["food"] = 2
	_chk(Objectives.condition_met(gs, "usa", {"t": "resource", "res": "food", "min": [2, 2]}, 0), "resource food >= 2")
	usa.growth_cards = [{}, {}, {}]
	_chk(Objectives.condition_met(gs, "usa", {"t": "growth_cards", "min": [3, 4]}, 0), "growth_cards 3 >= 3")
	usa.prosperity_level = 4
	_chk(Objectives.condition_met(gs, "usa", {"t": "prosperity_times", "min": [2, 4]}, 1), "prosperity_times 4 >= 4")
	usa.engage_tokens = ["europe"]
	_chk(Objectives.condition_met(gs, "usa", {"t": "engage_markers", "min": [1, 1]}, 0), "engage_markers 1 >= 1")
	usa.money = 200
	_chk(Objectives.condition_met(gs, "usa", {"t": "money_most"}, 0), "money_most (usa 200 > altri)")

	# --- Produzione (delta dal baseline iniziale) ---
	usa.initial_production = {"armies": 1, "consumer_goods": 0, "services": 1, "energy": 2}
	usa.production = {"armies": 3, "consumer_goods": 2, "services": 1, "energy": 2}
	_chk(Objectives.condition_met(gs, "usa", {"t": "production_increase", "res": "armies", "min": [1, 2]}, 1), "production_increase armies +2 >= 2")
	_chk(Objectives.condition_met(gs, "usa", {"t": "production_increases_count", "min": [2, 4]}, 0), "production_increases_count 2 (armies+cg) >= 2")
	_chk(Objectives.condition_met(gs, "usa", {"t": "production_increase_any", "res": ["consumer_goods", "services"], "min": [1, 1]}, 0), "production_increase_any cg/services")

	# --- Influenza ---
	gs.regions["europe"]["track"].add("usa", "permanent")
	gs.regions["europe"]["track"].add("usa", "permanent")
	gs.regions["europe"]["track"].add("usa", "permanent")
	gs.regions["europe"]["track"].add("russia", "permanent")
	_chk(Objectives.condition_met(gs, "usa", {"t": "influence_region", "region": "europe", "min": [3, 4]}, 0), "influence_region europe 3 >= 3")
	_chk(Objectives.condition_met(gs, "usa", {"t": "influence_highest", "region": "europe"}, 0), "influence_highest europe (usa 3 vs russia 1)")
	_chk(Objectives.condition_met(gs, "usa", {"t": "influence_more_than", "power": "russia", "region": "europe"}, 0), "influence_more_than russia in europe")
	_chk(Objectives.condition_met(gs, "usa", {"t": "influence_highest", "region": "europe", "strict": true}, 0), "influence_highest strict europe")
	# pareggio in testa: strict fallisce, non-strict regge
	gs.regions["africa"]["track"].add("usa", "permanent")
	gs.regions["africa"]["track"].add("china", "permanent")
	_chk(Objectives.condition_met(gs, "usa", {"t": "influence_highest", "region": "africa"}, 0), "influence_highest africa (pareggio 1-1, non strict)")
	_chk(not Objectives.condition_met(gs, "usa", {"t": "influence_highest", "region": "africa", "strict": true}, 0), "NON influence_highest strict africa (pareggio)")
	_chk(Objectives.condition_met(gs, "usa", {"t": "regions_with_influence", "per": 1, "min": [2, 2]}, 0), "regions_with_influence per1 in 2 regioni (europe, africa)")

	# --- Armate ---
	gs.regions["europe"]["armies"]["usa"] = 3
	gs.regions["middle_east_north_africa"]["armies"]["usa"] = 2
	_chk(Objectives.condition_met(gs, "usa", {"t": "armies_region", "region": "europe", "min": [2, 4]}, 0), "armies_region europe 3 >= 2")
	_chk(Objectives.condition_met(gs, "usa", {"t": "armies_total", "regions": ["europe", "middle_east_north_africa"], "min": [3, 6]}, 0), "armies_total 5 >= 3")
	_chk(Objectives.condition_met(gs, "usa", {"t": "armies_most"}, 0), "armies_most (usa sul tabellone)")

	# --- Nazioni Alleate + Export/Import + FDI ---
	usa.allied_countries = [
		{"id": "c1", "region": "europe", "exports": ["energy", "consumer_goods"], "imports": ["food"]},
		{"id": "c2", "region": "europe", "exports": ["services"], "imports": ["energy", "raw_materials"]},
		{"id": "c3", "region": "africa", "exports": ["energy"], "imports": []},
	]
	usa.fdi_countries = ["c1"]
	for o in ["eu", "russia", "china"]:
		gs.player_by_power(o).allied_countries = []   # azzera gli alleati iniziali del setup
	_chk(Objectives.condition_met(gs, "usa", {"t": "allied_total", "min": [3, 4]}, 0), "allied_total 3 >= 3")
	_chk(Objectives.condition_met(gs, "usa", {"t": "allied_region", "region": "europe", "min": [2, 2]}, 0), "allied_region europe 2 >= 2")
	_chk(Objectives.condition_met(gs, "usa", {"t": "allied_most"}, 0), "allied_most (usa 3 vs altri 0)")
	_chk(Objectives.condition_met(gs, "usa", {"t": "fdi_in_region", "region": "europe", "min": [1, 1]}, 0), "fdi_in_region europe 1 >= 1")
	_chk(Objectives.condition_met(gs, "usa", {"t": "export_symbols_total", "min": [4, 5]}, 0), "export_symbols_total 4 >= 4")
	_chk(Objectives.condition_met(gs, "usa", {"t": "export_symbols_distinct", "min": [3, 4]}, 0), "export_symbols_distinct 3 (energy/cg/services)")
	_chk(Objectives.condition_met(gs, "usa", {"t": "allied_export_to", "res": ["energy"], "min": [2, 2]}, 0), "allied_export_to energy: 2 (c1,c3)")
	_chk(Objectives.condition_met(gs, "usa", {"t": "allied_import_from", "res": ["energy", "raw_materials"], "min": [1, 1]}, 0), "allied_import_from energy/raw: 1 (c2)")
	_chk(Objectives.condition_met(gs, "usa", {"t": "fdi_export_to", "res": ["energy"], "min": [1, 1]}, 0), "fdi_export_to energy: c1")

	# --- Punteggio Obiettivo (tiering) ---
	var obj := {"reward": [2, 4, 7], "conditions": [
		{"t": "money", "min": [10, 10]},
		{"t": "growth_cards", "min": [1, 1]},
		{"t": "resource", "res": "food", "min": [2, 2]},
	]}
	# usa: money 200, growth 3, food 2 -> 3/3 condizioni -> 7 VP
	_chk(Objectives.objective_score(gs, "usa", obj, 0) == 7, "objective_score 3 cond -> 7")
	usa.resources["food"] = 0   # ora 2/3 -> 4
	_chk(Objectives.objective_score(gs, "usa", obj, 0) == 4, "objective_score 2 cond -> 4")
	usa.growth_cards = []        # ora 1/3 -> 2
	_chk(Objectives.objective_score(gs, "usa", obj, 0) == 2, "objective_score 1 cond -> 2")
	usa.money = 0               # ora 0/3 -> 0
	_chk(Objectives.objective_score(gs, "usa", obj, 0) == 0, "objective_score 0 cond -> 0")

	print("Verifica Obiettivi (motore di valutazione): %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _chk(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1
