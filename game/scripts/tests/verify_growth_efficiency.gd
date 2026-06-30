extends SceneTree
## Carta Crescita "Efficienza delle Risorse" (D&D, Liv.3):
##   - costo 3 Servizi + 5 risorse QUALSIASI (chiave di costo "any");
##   - 1x/round: pesca 1 carta, scartane 1 e ottieni risorse dal suo tipo.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_efficiency.gd

var _fails := 0

func _init() -> void:
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.active_seat = 0
	var p = b.gs.players[0]

	# 1) Costo "any": 3 Servizi + 5 risorse qualsiasi.
	p.resources = {"energy": 2, "raw_materials": 2, "food": 2, "consumer_goods": 0, "services": 5, "diplomacy": 0}
	var cost := {"services": 3, "any": 5}
	_check(p.has_resources(cost), "Costo 'any': abbordabile con 5 Servizi + 6 altre risorse")
	var before: int = _total_res(p)
	var ok_spend: bool = p.spend(cost)
	var after: int = _total_res(p)
	_check(ok_spend and (before - after) == 8, "Costo 'any': spese 8 risorse totali (3 Servizi + 5 qualsiasi) — prima %d, dopo %d" % [before, after])
	_check(int(p.resources["services"]) <= 2, "Costo 'any': i 3 Servizi specifici sono stati pagati (services=%d)" % int(p.resources["services"]))

	# 1b) Non abbordabile se le risorse totali non bastano.
	p.resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 3, "diplomacy": 0}
	_check(not p.has_resources({"services": 3, "any": 5}), "Costo 'any': NON abbordabile con soli 3 Servizi (servono 5 in più)")

	# 2) Abilità: scarta una carta Diplomatica -> +2 Diplomazia.
	p.growth_cards = [{"id": "growth_efficienza_risorse", "level": 3, "effect_ops": [{"op": "ongoing", "tag": "once_per_round:resource_efficiency"}]}]
	await _test_discard_type(b, p, "diplomatic", "diplomacy", 2)
	# Militare -> +1 Armata (in riserva).
	await _test_discard_type(b, p, "military", "armies", 1)

	b.queue_free()
	await process_frame
	print("Verifica Efficienza delle Risorse: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1


func _total_res(p) -> int:
	var t := 0
	for k in p.resources:
		t += int(p.resources[k])
	return t


func _test_discard_type(b: Variant, p, card_type: String, expect_key: String, expect_amt: int) -> void:
	b._used_ongoing = {}
	p.resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	p.armies_available = 0
	p.hand = [{"id": "h_target", "display_name": "Bersaglio", "type": card_type, "value": 1}]
	p.deck = [{"id": "h_draw", "display_name": "Pescata", "type": "economic", "value": 1}]
	b._use_ongoing("once_per_round:resource_efficiency")
	await process_frame
	var popup_ok: bool = b._popup_active() and b._popup_items.size() == 2
	_check(popup_ok, "Efficienza (%s): pescata 1, popup di scarto (mano=%d)" % [card_type, b._popup_items.size()])
	# Trova l'indice della carta-bersaglio (tipo da convertire).
	var idx := -1
	for i in b._popup_items.size():
		if String((b._popup_items[i] as Dictionary).get("value", {}).get("id", "")) == "h_target":
			idx = i
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx))
	await process_frame
	var got: int = int(p.armies_available) if expect_key == "armies" else int(p.resources.get(expect_key, 0))
	_check(got == expect_amt, "Efficienza (%s): scarto → +%d %s (ottenuto %d)" % [card_type, expect_amt, expect_key, got])