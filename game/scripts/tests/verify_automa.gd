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

	print("Verifica motore Automa (core deterministico): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
