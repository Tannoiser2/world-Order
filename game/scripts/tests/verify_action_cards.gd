extends SceneTree
## Carte Azione aggiuntive (Diplomacy & Dominance) — effetti con interazione fra giocatori:
##   - Distensione Diplomatica (remove_enemy_army): sposta 1 Armata nemica dalla Regione.
##   - Dimostrazione di Forza (deploy_force): disloca 1 Armata; gli altri esauriscono 1 alleato lì.
##   - Nuovi Accordi Finanziari (invest_foreign): investi nella Nazione (con IDE) di un altro.
##   - Intelligence di Acquisizione (copy_opponent_card): copia l'effetto di una carta avversaria.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_action_cards.gd

var _fails := 0

func _init() -> void:
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "eu", "russia", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.active_seat = 0   # usa agisce

	await _test_remove_enemy_army(b)
	await _test_deploy_force(b)
	await _test_invest_foreign(b)
	await _test_copy_card(b)

	b.queue_free()
	await process_frame
	print("Verifica Carte Azione aggiuntive: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1


func _prime(b: Variant) -> void:
	b.active_seat = 0
	b.playing_card = {"display_name": "azione", "effect_ops": []}
	b.play_queue = []
	b.awaiting = ""
	b._plays_left = 1


func _idx(b: Variant, items_label: String) -> int:
	for i in b._popup_items.size():
		if items_label in String((b._popup_items[i] as Dictionary).get("label", "")):
			return i
	return -1


func _test_remove_enemy_army(b: Variant) -> void:
	var usa = b.gs.players[0]
	var china = b.gs.players[3]
	usa.resources["diplomacy"] = 2
	china.armies_available = 0
	b.gs.regions["europe"]["armies"]["china"] = 2
	b._action_region = "europe"
	_prime(b)
	b._op_remove_enemy_army({"cost_diplomacy": 1})
	await process_frame
	var idx := _idx(b, "CHINA")
	_check(b._popup_active() and idx >= 0, "Distensione: popup con l'Armata nemica da spostare")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx))
	await process_frame
	_check(int(b.gs.regions["europe"]["armies"].get("china", 0)) == 1 and china.armies_available == 1 and int(usa.resources["diplomacy"]) == 1,
		"Distensione: Armata china 2->%d, riserva +%d, -1 Diplomazia (=%d)" % [int(b.gs.regions["europe"]["armies"].get("china", 0)), china.armies_available, int(usa.resources["diplomacy"])])


func _test_deploy_force(b: Variant) -> void:
	var usa = b.gs.players[0]
	b.gs.regions["africa"]["armies"]["usa"] = 0
	for si in [1, 2, 3]:
		b.gs.players[si].allied_countries = [{"id": "a%d" % si, "region": "africa"}]
		b.gs.players[si].exhausted = {}
	b._action_region = "africa"
	_prime(b)
	b._op_deploy_force({})
	await process_frame
	_check(b._popup_active() and b._popup_items.size() == 2, "Forza: popup Sì/No per la dislocazione")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))   # Sì
	await process_frame
	var deployed: bool = int(b.gs.regions["africa"]["armies"].get("usa", 0)) == 1
	var all_exhausted := true
	for si in [1, 2, 3]:
		if not bool(b.gs.players[si].exhausted.get("a%d" % si, false)):
			all_exhausted = false
	_check(deployed and all_exhausted, "Forza: 1 Armata dislocata (=%s) e gli altri 3 hanno esaurito un alleato (=%s)" % [str(deployed), str(all_exhausted)])


func _test_invest_foreign(b: Variant) -> void:
	var usa = b.gs.players[0]
	var china = b.gs.players[3]
	usa.money = 100
	china.allied_countries = [{"id": "cn1", "display_name": "Paese Cinese", "invest_cost": 5, "region": "east_asia_pacific"}]
	china.fdi_countries = ["cn1"]
	china.exhausted = {}
	b.gs.supply["fdi"] = 5
	_prime(b)
	b._op_invest_foreign({"extra_cost": 5})
	await process_frame
	var idx := _idx(b, "Paese Cinese")
	_check(b._popup_active() and idx >= 0, "Nuovi Accordi Finanziari: popup con la Nazione cinese (con IDE)")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx))
	await process_frame
	_check(usa.money == 90 and bool(china.exhausted.get("cn1", false)),
		"Nuovi Accordi: pagati 5+5 (money 100->%d) e Nazione cinese esaurita (=%s)" % [usa.money, str(bool(china.exhausted.get("cn1", false)))])


func _test_copy_card(b: Variant) -> void:
	var usa = b.gs.players[0]
	usa.money = 0
	for si in [1, 2, 3]:
		b.gs.players[si].hand = []
		b.gs.players[si].played = []
	b.gs.players[3].hand = [{"id": "ch", "display_name": "Iniezione di Fondi", "effect_ops": [{"op": "gain_money", "amount": 20}]}]
	_prime(b)
	b._op_copy_opponent_card({})
	await process_frame
	var idx := _idx(b, "Iniezione di Fondi")
	_check(b._popup_active() and idx >= 0, "Intelligence: popup con la carta avversaria da copiare")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx))
	await process_frame
	_check(usa.money == 20, "Intelligence: copiato l'effetto (gain_money 20) -> money=%d" % usa.money)
