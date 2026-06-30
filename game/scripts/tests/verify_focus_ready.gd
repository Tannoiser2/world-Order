extends SceneTree
## Choose Focus: la riattivazione delle Nazioni esaurite (ready) non e' piu' automatica quando
## ci sono PIU' Nazioni esaurite di quante se ne possono riattivare: il giocatore sceglie QUALI.
## Se sono <= del numero del Focus, si riattivano tutte da sole.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_focus_ready.gd

func _seat_of(b: Variant, power: String) -> int:
	for i in b.gs.players.size():
		if b.gs.players[i].power == power:
			return i
	return -1

func _setup_prep(b: Variant, seat: int) -> void:
	b._ui_phase = "Preparazione"; b.gs.phase = WO.Phase.PREPARATION
	b.gs.round = 2
	b._prep_idx = 0
	b.gs.turn_order.assign([seat, 1 - seat])
	b.active_seat = seat
	b._prep_awaiting_increase = false
	b._prep_ready_remaining = 0
	b._produce_mode = false
	b._focus_round = {}

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	var us := _seat_of(b, "usa")
	var p = b.gs.players[us]
	var ids := []
	for c in p.allied_countries:
		ids.append(String(c.get("id", "")))
	# Serve che gli USA abbiano almeno 3 Nazioni alleate (Starting Allies).
	var have := ids.size()
	print("[%s] setup: USA ha %d Nazioni alleate" % ["OK" if have >= 3 else "FAIL", have])
	if have < 3: fails += 1

	# 1) PIU' esaurite del consentito (USA Domestic ready = 1; esaurite = 3) -> scelta interattiva.
	_setup_prep(b, us)
	p.money = 50
	p.production = {"energy": 3, "raw_materials": 3, "food": 3, "consumer_goods": 2, "services": 1, "diplomacy": 1, "armies": 1}
	p.resources = {"energy": 5, "raw_materials": 5, "food": 5, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	p.exhausted = {}
	for i in 3:
		p.exhausted[ids[i]] = true
	b._do_focus(WO.Focus.DOMESTIC)
	await process_frame
	var s1: bool = b._prep_ready_remaining == 1 and not b._produce_mode \
		and bool(p.exhausted.get(ids[0], false))   # non ancora riattivata
	print("[%s] 3 esaurite, ready 1 -> scelta interattiva (remaining=%d, produce=%s)" % [
		"OK" if s1 else "FAIL", b._prep_ready_remaining, str(b._produce_mode)])
	if not s1: fails += 1

	# 2) Il giocatore tocca una Nazione esaurita -> riattivata; finito il ready si apre la Produce.
	b._prep_ready_pick(ids[0])
	await process_frame
	var s2: bool = not bool(p.exhausted.get(ids[0], false)) and b._prep_ready_remaining == 0 \
		and b._produce_mode and bool(p.exhausted.get(ids[1], false))   # le altre restano esaurite
	print("[%s] riattivata la scelta -> Produce aperta (id0 ready=%s, remaining=%d)" % [
		"OK" if s2 else "FAIL", str(not bool(p.exhausted.get(ids[0], false))), b._prep_ready_remaining])
	if not s2: fails += 1

	# 3) Esaurite <= consentito (1 esaurita, ready 1) -> riattivazione AUTOMATICA, niente scelta.
	_setup_prep(b, us)
	p.money = 50
	p.production = {"energy": 3, "raw_materials": 3, "food": 3, "consumer_goods": 2, "services": 1, "diplomacy": 1, "armies": 1}
	p.resources = {"energy": 5, "raw_materials": 5, "food": 5, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	p.exhausted = {}
	p.exhausted[ids[0]] = true
	b._do_focus(WO.Focus.DOMESTIC)
	await process_frame
	var s3: bool = b._prep_ready_remaining == 0 and b._produce_mode \
		and not bool(p.exhausted.get(ids[0], false))   # riattivata da sola
	print("[%s] 1 esaurita, ready 1 -> auto-riattivata, Produce diretta (remaining=%d)" % [
		"OK" if s3 else "FAIL", b._prep_ready_remaining])
	if not s3: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica ready interattivo del Focus: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
