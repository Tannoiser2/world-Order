extends SceneTree
## Carta Crescita "Affermazione di Predominio" (D&D, Liv.4):
##   - All'acquisto: +2 VP per ogni round GIA' completato (dinamico).
##   - Alla fine di ogni turno in cui hai aggiunto Influenza a una Regione: +1 VP.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_predominio.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	var p = b.gs.players[0]
	b.active_seat = 0

	var card := {
		"id": "growth_affermazione_predominio", "display_name": "Affermazione di Predominio",
		"level": 4, "victory_points": 0, "vp_per_completed_round": 2,
		"cost": {"services": 4, "diplomacy": 2},
		"effect_ops": [{"op": "ongoing", "tag": "vp_on_influence_added"}],
	}

	# 1) Acquisto al Round 4 -> +2 VP per ognuno dei 3 round completati = +6 VP.
	b.gs.round = 4
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	p.growth_cards = []
	p.resources["services"] = 4
	p.resources["diplomacy"] = 2
	var vp0: int = p.victory_points
	b._buy_growth_action(card, 4)
	await process_frame
	var s1: bool = p.victory_points == vp0 + 6 and p.growth_cards.size() == 1
	print("[%s] acquisto al Round 4: VP +%d (atteso +6)" % ["OK" if s1 else "FAIL", p.victory_points - vp0])
	if not s1: fails += 1

	# 2) Fine turno CON Influenza aggiunta -> +1 VP.
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.gs.turn_order.assign([0, 1]); b.round_turn_count = 0; b.active_seat = 0
	# la carta e' gia' tra le growth_cards di p (ongoing attivo).
	var rid: String = b.gs.regions.keys()[0]
	b._turn_start_influence = b._player_total_influence("usa")
	b.gs.regions[rid]["track"].add("usa", "permanent")   # aggiunge Influenza nel turno
	b._played_this_turn = true
	p.hand = []
	var vp1: int = p.victory_points
	b._end_turn()
	await process_frame
	var s2: bool = p.victory_points == vp1 + 1
	print("[%s] fine turno con Influenza: VP +%d (atteso +1)" % ["OK" if s2 else "FAIL", p.victory_points - vp1])
	if not s2: fails += 1

	# 3) Fine turno SENZA Influenza aggiunta -> nessun VP extra.
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.gs.turn_order.assign([0, 1]); b.round_turn_count = 0; b.active_seat = 0
	b._turn_start_influence = b._player_total_influence("usa")   # nessuna aggiunta dopo
	b._played_this_turn = true
	p.hand = []
	var vp2: int = p.victory_points
	b._end_turn()
	await process_frame
	var s3: bool = p.victory_points == vp2
	print("[%s] fine turno senza Influenza: VP +%d (atteso 0)" % ["OK" if s3 else "FAIL", p.victory_points - vp2])
	if not s3: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Growth Affermazione di Predominio: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
