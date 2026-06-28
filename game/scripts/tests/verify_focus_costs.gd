extends SceneTree
## Choose Focus: ogni superpotenza ha valori PROPRI (dalle player board) per il numero di
## carte Nazione preparate (ready) e per il COSTO di aumento Produzione. Prima erano fissi
## (ready 1/4/2, costo 8) per tutti; ora sono per-potenza: USA 8, UE 7 (e ready 2/5/3),
## Russia/Cina 6.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_focus_costs.gd

func _seat_of(board: Variant, power: String) -> int:
	for i in board.gs.players.size():
		if board.gs.players[i].power == power:
			return i
	return -1

func _init() -> void:
	var fails := 0
	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china", "russia", "eu"]
	var b: Variant = board_packed.instantiate()
	get_root().add_child(b)
	await process_frame
	b._begin_action_phase()

	# 1) Costo aumento Produzione per-potenza (USA 8, UE 7, Russia 6, Cina 6).
	var cost_ok: bool = b._focus_increase_cost("usa") == 8 and b._focus_increase_cost("eu") == 7 \
		and b._focus_increase_cost("russia") == 6 and b._focus_increase_cost("china") == 6
	print("[%s] costo aumento: USA=%d UE=%d Russia=%d Cina=%d" % ["OK" if cost_ok else "FAIL",
		b._focus_increase_cost("usa"), b._focus_increase_cost("eu"),
		b._focus_increase_cost("russia"), b._focus_increase_cost("china")])
	if not cost_ok: fails += 1

	# 2) Carte preparate (ready) per Focus: UE 2/5/3, le altre 1/4/2.
	var ready_ok: bool = \
		b._focus_ready_count("usa", "domestic") == 1 and b._focus_ready_count("usa", "diplomatic") == 4 and b._focus_ready_count("usa", "military") == 2 \
		and b._focus_ready_count("eu", "domestic") == 2 and b._focus_ready_count("eu", "diplomatic") == 5 and b._focus_ready_count("eu", "military") == 3 \
		and b._focus_ready_count("russia", "diplomatic") == 4 and b._focus_ready_count("china", "military") == 2
	print("[%s] ready: UE=%d/%d/%d USA-dip=%d" % ["OK" if ready_ok else "FAIL",
		b._focus_ready_count("eu", "domestic"), b._focus_ready_count("eu", "diplomatic"),
		b._focus_ready_count("eu", "military"), b._focus_ready_count("usa", "diplomatic")])
	if not ready_ok: fails += 1

	# 3) Integrazione _increase_prod_options: per l'UE (Diplomatic) il costo dell'opzione è 7.
	var eu_seat := _seat_of(b, "eu")
	b.active_seat = eu_seat
	b.gs.players[eu_seat].focus = WO.Focus.DIPLOMATIC
	var opts: Array = b._increase_prod_options(b.gs.players[eu_seat])
	var s3: bool = opts.size() == 1 and String(opts[0]["type"]) == "diplomacy" and int(opts[0]["cost"]) == 7
	print("[%s] _increase_prod_options UE Diplomatic: %s" % ["OK" if s3 else "FAIL", str(opts)])
	if not s3: fails += 1

	# 4) Integrazione _apply_focus: l'UE con Diplomatic prepara 5 carte Nazione esaurite.
	var p = b.gs.players[eu_seat]
	p.exhausted = {"c1": true, "c2": true, "c3": true, "c4": true, "c5": true, "c6": true}
	b._focus_round.erase("eu")            # forza la riapplicazione del Focus
	b._apply_focus(p, WO.Focus.DIPLOMATIC)
	var still_exhausted := 0
	for cid in p.exhausted:
		if bool(p.exhausted[cid]):
			still_exhausted += 1
	var readied := 6 - still_exhausted
	var s4: bool = readied == 5
	print("[%s] _apply_focus UE Diplomatic prepara 5 carte (preparate=%d)" % ["OK" if s4 else "FAIL", readied])
	if not s4: fails += 1

	# 5) E gli USA con Diplomatic ne preparano 4 (per confronto).
	var usa_seat := _seat_of(b, "usa")
	var pu = b.gs.players[usa_seat]
	pu.exhausted = {"u1": true, "u2": true, "u3": true, "u4": true, "u5": true, "u6": true}
	b._focus_round.erase("usa")
	b._apply_focus(pu, WO.Focus.DIPLOMATIC)
	var su := 0
	for cid in pu.exhausted:
		if bool(pu.exhausted[cid]):
			su += 1
	var s5: bool = (6 - su) == 4
	print("[%s] _apply_focus USA Diplomatic prepara 4 carte (preparate=%d)" % ["OK" if s5 else "FAIL", 6 - su])
	if not s5: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica costi/ready Focus per-potenza: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
