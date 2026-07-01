extends SceneTree
## Bug: comprando la Growth "Industrial Development" ("Aumenta di 1 due delle tue Produzioni")
## non veniva mai offerta la scelta delle 2 Produzioni: _buy_growth_action non accodava mai
## l'effect_ops della Growth card (solo "Vantaggio Operativo" era gestito, con un caso apposito).
## In piu' l'op "increase_production" interpretava `count` come AMMONTARE su UNA risorsa,
## invece che "N risorse DISTINTE, ognuna +1" (bug visibile solo con count>1).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_industrial_dev.gd

func _init() -> void:
	var fails := 0
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
	p.money = 500
	p.resources = {"energy": 10, "raw_materials": 10, "food": 10, "consumer_goods": 10, "services": 10, "diplomacy": 10, "armies": 10}
	var e0 := int(p.production.get("energy", 0))
	var d0 := int(p.production.get("diplomacy", 0))
	var card := {"id": "probe", "display_name": "Growth Strategy Probe",
		"effect_ops": [{"op": "choice", "options": [[{"op": "get_growth"}], [{"op": "produce", "count": 3}]]}]}
	p.hand = [card]
	b._plays_left = 1
	b._play_card(card)
	await process_frame
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))   # "Carta Crescita"
	await process_frame

	var s1: bool = not b._growth_pick.is_empty()
	print("[%s] Get a Growth Card: selettore aperto" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	var target := {}
	for c in b._available_growth(p):
		if String(c.get("id", "")) == "growth_industrial_development":
			target = c
	var s2: bool = not target.is_empty()
	print("[%s] Industrial Development disponibile e abbordabile" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	b.apply_command(GameCommands.buy_growth(0, b._next_seq(), String(target.get("id", ""))))
	await process_frame

	# Ora deve aprirsi la scelta "quale Produzione aumentare (1 di 2)".
	var s3: bool = b._popup_active()
	print("[%s] Dopo l'acquisto: si apre la scelta della 1a Produzione da aumentare" % ["OK" if s3 else "FAIL"])
	if not s3: fails += 1

	var idx_e := -1
	for i in b._popup_items.size():
		if String((b._popup_items[i] as Dictionary).get("value", "")) == "energy":
			idx_e = i
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx_e))
	await process_frame

	var s4: bool = int(p.production.get("energy", 0)) == e0 + 1 and b._popup_active()
	print("[%s] Energia +1 (%d->%d) e si apre la scelta della 2a Produzione (DIVERSA)" % [
		"OK" if s4 else "FAIL", e0, int(p.production.get("energy", 0))])
	if not s4: fails += 1

	var has_energy_again := false
	for i in b._popup_items.size():
		if String((b._popup_items[i] as Dictionary).get("value", "")) == "energy":
			has_energy_again = true
	print("[%s] Energia NON riproponibile come 2a scelta (regolamento: 2 risorse diverse)" % ["OK" if not has_energy_again else "FAIL"])
	if has_energy_again: fails += 1

	var idx_d := -1
	for i in b._popup_items.size():
		if String((b._popup_items[i] as Dictionary).get("value", "")) == "diplomacy":
			idx_d = i
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx_d))
	await process_frame

	var s5: bool = int(p.production.get("diplomacy", 0)) == d0 + 1
	print("[%s] Diplomazia +1 (%d->%d)" % ["OK" if s5 else "FAIL", d0, int(p.production.get("diplomacy", 0))])
	if not s5: fails += 1

	var s6: bool = b.playing_card.is_empty() and b._plays_left == 0 and p.growth_cards.size() == 1
	print("[%s] Carta risolta e conclusa (playing_card vuota, plays_left=%d, growth_cards=%d)" % [
		"OK" if s6 else "FAIL", b._plays_left, p.growth_cards.size()])
	if not s6: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica fix Growth Industrial Development: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
