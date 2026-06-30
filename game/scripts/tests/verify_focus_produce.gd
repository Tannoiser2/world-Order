extends SceneTree
## Choose Focus: la produzione del Focus NON e' piu' automatica. Scegliendo il Focus si apre la
## STESSA Produce UI delle carte, limitata ai tipi del Focus (Domestic: Beni/Servizi). Il
## giocatore sceglie quanto produrre; alla conferma si prosegue con l'aumento Produzione.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_focus_produce.gd

func _seat_of(b: Variant, power: String) -> int:
	for i in b.gs.players.size():
		if b.gs.players[i].power == power:
			return i
	return -1

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
	# Preparazione round 2, turno degli USA.
	b._ui_phase = "Preparazione"; b.gs.phase = WO.Phase.PREPARATION
	b.gs.round = 2
	b._prep_idx = 0
	b.gs.turn_order.assign([us, 1 - us])
	b.active_seat = us
	b._prep_awaiting_increase = false
	b._produce_mode = false
	b._focus_round = {}
	var p = b.gs.players[us]
	p.money = 50
	p.production = {"energy": 3, "raw_materials": 3, "food": 3, "consumer_goods": 2, "services": 1, "diplomacy": 1, "armies": 1}
	p.resources = {"energy": 5, "raw_materials": 5, "food": 5, "consumer_goods": 0, "services": 0, "diplomacy": 0}

	# 1) Scelta del Focus Domestic -> si apre la Produce UI limitata a Beni di consumo + Servizi.
	b._do_focus(WO.Focus.DOMESTIC)
	await process_frame
	var allowed: Array = b._produce_allowed
	var s1: bool = b._produce_mode and b._produce_after == "prep" and p.focus == WO.Focus.DOMESTIC \
		and allowed.size() == 2 and "consumer_goods" in allowed and "services" in allowed
	print("[%s] Focus Domestic: Produce UI aperta, tipi=%s after=%s" % [
		"OK" if s1 else "FAIL", str(allowed), b._produce_after])
	if not s1: fails += 1

	# 2) La produzione NON e' avvenuta da sola (niente Beni/Servizi finche' non confermi).
	var s2: bool = int(p.resources.get("consumer_goods", 0)) == 0 and int(p.resources.get("services", 0)) == 0
	print("[%s] niente produzione automatica prima della conferma" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# 3) Il giocatore sceglie di produrre 2 Beni di consumo (costa 2 Energia + 2 Materie) e conferma.
	b._produce_sel = {"consumer_goods": 2}
	b._apply_produce()
	await process_frame
	var s3: bool = int(p.resources.get("consumer_goods", 0)) == 2 \
		and int(p.resources.get("energy", 0)) == 3 and int(p.resources.get("raw_materials", 0)) == 3 \
		and not b._produce_mode
	print("[%s] prodotti 2 Beni (-2 En, -2 RM): CG=%d En=%d RM=%d" % [
		"OK" if s3 else "FAIL", int(p.resources.get("consumer_goods", 0)),
		int(p.resources.get("energy", 0)), int(p.resources.get("raw_materials", 0))])
	if not s3: fails += 1

	# 4) Dopo la produzione del Focus si prosegue con l'aumento Produzione (money sufficiente).
	var s4: bool = b._prep_awaiting_increase
	print("[%s] dopo la produzione -> passo Aumento Produzione (await=%s)" % [
		"OK" if s4 else "FAIL", str(b._prep_awaiting_increase)])
	if not s4: fails += 1

	# 5) Military -> la Produce e' limitata alle Armate (gestite con ± nella barra).
	var ch := _seat_of(b, "china")
	b._prep_idx = 0
	b.gs.turn_order.assign([ch, 1 - ch])
	b.active_seat = ch
	b._prep_awaiting_increase = false
	b._produce_mode = false
	b._focus_round = {}
	var pc = b.gs.players[ch]
	pc.production = {"energy": 1, "raw_materials": 3, "food": 1, "consumer_goods": 1, "services": 1, "diplomacy": 1, "armies": 2}
	pc.resources = {"energy": 1, "raw_materials": 3, "food": 1, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	b._do_focus(WO.Focus.MILITARY)
	await process_frame
	var s5: bool = b._produce_mode and b._produce_allowed == ["armies"]
	print("[%s] Focus Military: Produce limitata alle Armate (%s)" % ["OK" if s5 else "FAIL", str(b._produce_allowed)])
	if not s5: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica produzione Focus interattiva: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
