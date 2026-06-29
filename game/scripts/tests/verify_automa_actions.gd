extends SceneTree
## Stadio 4b: l'Automa esegue un turno d'Azione VERO sul GameState condiviso (Automa.take_action).
## Verifica per ogni azione (Engage, Invest, Improve, Build, Move, Trade, Domestic) che money,
## Influenza nelle Regioni, Armate sulla mappa, FDI/Basi e cubi azione cambino come previsto.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_automa_actions.gd

func _region_with_ally(p) -> String:
	for c in p.allied_countries:
		return String((c as Dictionary).get("region", ""))
	return ""

func _influence_count(track, owner: String) -> int:
	var n := 0
	for o in track.perm:
		if o != null and String(o) == owner: n += 1
	for o in track.temp:
		if o != null and String(o) == owner: n += 1
	return n

func _init() -> void:
	var fails := 0
	var pool: Array = DataLoader.load_countries()

	# 1) ENGAGE: tipo diplomatic con cubo a sinistra -> Engage nella Regione di un alleato;
	#    money speso, +1 Influenza, cubo engage->improve_relations.
	var gs = GameSetup.new_game(["usa", "china"])
	var p = gs.player_by_power("usa")
	p.money = 200
	var a := Automa.from_setup("usa")
	a.action_cubes = {"engage": 1, "improve_relations": 0}
	var r := _region_with_ally(p)
	var inf0 := _influence_count(gs.regions[r]["track"], "usa")
	var res := a.take_action(gs, "diplomatic", [r], pool)
	var inf1 := _influence_count(gs.regions[r]["track"], "usa")
	var s1: bool = res["action"] == "engage" and res["region"] == r and p.money < 200 \
		and inf1 == inf0 + 1 and int(a.action_cubes.get("improve_relations", 0)) == 1 \
		and int(a.action_cubes.get("engage", 0)) == 0
	print("[%s] Engage in %s: money 200->%d, Influenza %d->%d, cubo spostato" % [
		"OK" if s1 else "FAIL", r, p.money, inf0, inf1])
	if not s1: fails += 1

	# 2) INVEST: economic con cubo a sinistra -> Invest; -15 money, +1 FDI nella Regione, +Influenza.
	var gs2 = GameSetup.new_game(["usa", "china"])
	var p2 = gs2.player_by_power("usa")
	p2.money = 200
	var a2 := Automa.from_setup("usa")
	a2.action_cubes = {"invest": 1, "trade": 0}
	var r2 := _region_with_ally(p2)
	var inf2_0 := _influence_count(gs2.regions[r2]["track"], "usa")
	var res2 := a2.take_action(gs2, "economic", [r2], pool)
	var s2: bool = res2["action"] == "invest" and res2["region"] == r2 and p2.money == 185 \
		and int(a2.fdi.get(r2, 0)) == 1 \
		and _influence_count(gs2.regions[r2]["track"], "usa") == inf2_0 + 1
	print("[%s] Invest in %s: money=%d, FDI=%d, Influenza +1" % [
		"OK" if s2 else "FAIL", r2, p2.money, int(a2.fdi.get(r2, 0))])
	if not s2: fails += 1

	# 3) IMPROVE RELATIONS: diplomatic con cubo a destra -> allea una nuova Country (money speso).
	var gs3 = GameSetup.new_game(["usa", "china"])
	var p3 = gs3.player_by_power("usa")
	p3.money = 200
	var allied_before: int = p3.allied_countries.size()
	var a3 := Automa.from_setup("usa")
	a3.action_cubes = {"engage": 0, "improve_relations": 1}
	var res3 := a3.take_action(gs3, "diplomatic", [], pool)
	var s3: bool = res3["action"] == "improve_relations" and p3.allied_countries.size() == allied_before + 1 \
		and p3.money < 200 and int(a3.action_cubes.get("engage", 0)) == 1
	print("[%s] Improve Relations: alleati %d->%d, money 200->%d (%s)" % [
		"OK" if s3 else "FAIL", allied_before, p3.allied_countries.size(), p3.money, str(res3.get("note", ""))])
	if not s3: fails += 1

	# 4) BUILD A BASE: military con cubo a sinistra -> Base in Regione con base-ally; -10 money,
	#    +1 Armata sulla mappa, +1 Base, +Influenza.
	var gs4 = GameSetup.new_game(["usa", "china"])
	var p4 = gs4.player_by_power("usa")
	p4.money = 200
	# Garantisci una Country alleata con simbolo Base per gli USA in una Regione nota.
	var rb := "americas"
	p4.allied_countries.append({"id": "test_base_country", "region": rb, "value": 2,
		"has_base_symbol": true, "base_allowed_powers": ["usa"], "exports": []})
	var a4 := Automa.from_setup("usa")
	a4.action_cubes = {"build_base": 1, "move": 0}
	var res4 := a4.take_action(gs4, "military", [], pool)
	var rb4: String = String(res4.get("region", ""))   # la Regione effettivamente scelta
	var s4: bool = res4["action"] == "build_base" and rb4 != "" and p4.money == 190 \
		and int(a4.bases.get(rb4, 0)) == 1 and int(gs4.regions[rb4]["armies"].get("usa", 0)) >= 1
	print("[%s] Build a Base in %s: money=%d, Basi=%d, Armate(usa)=%d" % [
		"OK" if s4 else "FAIL", rb4, p4.money, int(a4.bases.get(rb4, 0)), int(gs4.regions[rb4]["armies"].get("usa", 0))])
	if not s4: fails += 1

	# 5) MOVE: military con cubo a destra -> Armata in una Regione valida (zona di interesse);
	#    -5 money, +1 Armata.
	var gs5 = GameSetup.new_game(["usa", "china"])
	var p5 = gs5.player_by_power("usa")
	p5.money = 200
	# Assicura una zona di interesse USA.
	var rm: String = gs5.regions.keys()[0]
	if "usa" not in gs5.regions[rm].get("zone", []):
		gs5.regions[rm]["zone"] = (gs5.regions[rm].get("zone", []) as Array).duplicate()
		gs5.regions[rm]["zone"].append("usa")
	var a5 := Automa.from_setup("usa")
	a5.action_cubes = {"build_base": 0, "move": 1}
	var movearmy0 := int(gs5.regions[rm]["armies"].get("usa", 0))
	var res5 := a5.take_action(gs5, "military", [rm], pool)
	var s5: bool = res5["action"] == "move" and p5.money == 195 \
		and int(gs5.regions[res5["region"]]["armies"].get("usa", 0)) >= 1
	print("[%s] Move: money 200->%d, Armata in %s" % ["OK" if s5 else "FAIL", p5.money, str(res5.get("region", ""))])
	if not s5: fails += 1

	# 6) TRADE: economic con cubo a destra -> Trade (5 money per Export degli alleati).
	var gs6 = GameSetup.new_game(["usa", "china"])
	var p6 = gs6.player_by_power("usa")
	p6.money = 50
	var a6 := Automa.from_setup("usa")
	a6.action_cubes = {"invest": 0, "trade": 1}
	var exsym := 0
	for c in p6.allied_countries:
		exsym += ((c as Dictionary).get("exports", []) as Array).size()
	var res6 := a6.take_action(gs6, "economic", [], pool)
	var s6: bool = res6["action"] == "trade" and p6.money == 50 + exsym * 5
	print("[%s] Trade: %d export -> money 50->%d" % ["OK" if s6 else "FAIL", exsym, p6.money])
	if not s6: fails += 1

	# 7) DOMESTIC: +30 money.
	var gs7 = GameSetup.new_game(["usa", "china"])
	var p7 = gs7.player_by_power("usa")
	p7.money = 10
	var a7 := Automa.from_setup("usa")
	var res7 := a7.take_action(gs7, "domestic", [], pool)
	var s7: bool = res7["action"] == "domestic" and p7.money == 40
	print("[%s] Domestic: money 10->%d (+30)" % ["OK" if s7 else "FAIL", p7.money])
	if not s7: fails += 1

	# 8) FALLBACK: economic/Invest senza money -> Trade (ripiego), cubi trade->invest.
	var gs8 = GameSetup.new_game(["usa", "china"])
	var p8 = gs8.player_by_power("usa")
	p8.money = 3   # < 15: non puo' investire
	var a8 := Automa.from_setup("usa")
	a8.action_cubes = {"invest": 1, "trade": 2}
	var res8 := a8.take_action(gs8, "economic", [_region_with_ally(p8)], pool)
	var s8: bool = res8["action"] == "trade" and int(a8.action_cubes.get("invest", 0)) == 3 \
		and int(a8.action_cubes.get("trade", 0)) == 0
	print("[%s] Fallback Invest->Trade: azione=%s, cubi invest=%d trade=%d" % [
		"OK" if s8 else "FAIL", str(res8["action"]), int(a8.action_cubes.get("invest", 0)), int(a8.action_cubes.get("trade", 0))])
	if not s8: fails += 1

	print("Verifica azioni reali dell'Automa (stadio 4b): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
