extends SceneTree
## Choose Focus - aumento Produzione: la CINA in Focus DOMESTIC puo' aumentare DUE Produzioni
## (distinte) per 15 money totali (6 la prima, 9 la seconda); le altre potenze una sola.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_china_focus_increase.gd

func _seat_of(b: Variant, power: String) -> int:
	for i in b.gs.players.size():
		if b.gs.players[i].power == power:
			return i
	return -1

func _setup_prep(b: Variant, seat: int) -> void:
	b._ui_phase = "Preparazione"
	b.gs.phase = WO.Phase.PREPARATION
	b._prep_idx = 0
	b.gs.turn_order.assign([seat, 1 - seat])
	b.active_seat = seat
	b.gs.players[seat].focus = WO.Focus.DOMESTIC
	b._prep_awaiting_increase = true
	b._prep_increases_done = 0
	b._prep_increased_types = []

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["china", "usa"]
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	var cs := _seat_of(b, "china")

	# 1) Max aumenti: Cina Domestic = 2, USA Domestic = 1.
	var s1: bool = b._max_focus_increases("china", WO.Focus.DOMESTIC) == 2 \
		and b._max_focus_increases("usa", WO.Focus.DOMESTIC) == 1 \
		and b._max_focus_increases("china", WO.Focus.MILITARY) == 1
	print("[%s] max aumenti: Cina-Dom=%d USA-Dom=%d Cina-Mil=%d" % ["OK" if s1 else "FAIL",
		b._max_focus_increases("china", WO.Focus.DOMESTIC), b._max_focus_increases("usa", WO.Focus.DOMESTIC),
		b._max_focus_increases("china", WO.Focus.MILITARY)])
	if not s1: fails += 1

	# 2) Costo del 1° (6) e del 2° (9) aumento Cina Domestic.
	var s2: bool = b._focus_increase_cost_n("china", WO.Focus.DOMESTIC, 0) == 6 \
		and b._focus_increase_cost_n("china", WO.Focus.DOMESTIC, 1) == 9
	print("[%s] costo aumenti Cina Domestic: 1°=%d 2°=%d" % ["OK" if s2 else "FAIL",
		b._focus_increase_cost_n("china", WO.Focus.DOMESTIC, 0), b._focus_increase_cost_n("china", WO.Focus.DOMESTIC, 1)])
	if not s2: fails += 1

	# 3) Flusso: la Cina aumenta 2 Produzioni distinte (energia poi cibo): -15 money totali.
	_setup_prep(b, cs)
	var p = b.gs.players[cs]
	p.money = 20
	p.production = {"energy": 1, "raw_materials": 1, "food": 1, "consumer_goods": 1, "services": 1, "diplomacy": 1, "armies": 1}
	# Primo aumento: energia (costo 6).
	b.apply_command(GameCommands.increase_production(cs, 1, "energy"))
	await process_frame
	var after1_ok: bool = int(p.production.get("energy", 0)) == 2 and p.money == 14 \
		and b._prep_increases_done == 1 and b._prep_awaiting_increase \
		and ("energy" in b._prep_increased_types)
	# La 2ª offerta esclude l'energia e costa 9.
	var opts2: Array = b._increase_prod_options(p)
	var excl_ok := true
	for o in opts2:
		if String(o["type"]) == "energy": excl_ok = false
		if int(o["cost"]) != 9: excl_ok = false
	var s3: bool = after1_ok and excl_ok
	print("[%s] dopo 1° aumento: energia=2, money=14, ri-offerta (esclusa energia, costo 9)=%s" % [
		"OK" if s3 else "FAIL", str(excl_ok)])
	if not s3: fails += 1

	# 4) Secondo aumento: cibo (costo 9). Totale -15; poi passa al giocatore successivo.
	b.apply_command(GameCommands.increase_production(cs, 2, "food"))
	await process_frame
	# Dopo il 2° aumento la Cina ha finito: nessuna 3ª offerta (avanzato al prossimo).
	var s4: bool = int(p.production.get("food", 0)) == 2 and p.money == 5 \
		and not b._prep_awaiting_increase
	print("[%s] dopo 2° aumento: cibo=%d, money=%d (-15 tot atteso 5), niente 3ª offerta (await=%s)" % [
		"OK" if s4 else "FAIL", int(p.production.get("food", 0)), p.money, str(b._prep_awaiting_increase)])
	if not s4: fails += 1

	# 5) USA: un solo aumento, poi avanza subito (niente 2ª offerta).
	var us := _seat_of(b, "usa")
	_setup_prep(b, us)
	var pu = b.gs.players[us]
	pu.money = 30
	pu.production = {"energy": 1, "raw_materials": 1, "food": 1, "consumer_goods": 1, "services": 1, "diplomacy": 1, "armies": 1}
	b.apply_command(GameCommands.increase_production(us, 1, "energy"))
	await process_frame
	# USA: costo 8, un solo aumento, nessuna 2ª offerta -> avanzato.
	var s5: bool = int(pu.production.get("energy", 0)) == 2 and pu.money == 22 \
		and not b._prep_awaiting_increase
	print("[%s] USA: un solo aumento (energia=%d, money=%d, await=%s) — atteso energia=2 money=22 await=false" % [
		"OK" if s5 else "FAIL", int(pu.production.get("energy", 0)), pu.money, str(b._prep_awaiting_increase)])
	if not s5: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica aumento Produzione Cina (2 per 15): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
