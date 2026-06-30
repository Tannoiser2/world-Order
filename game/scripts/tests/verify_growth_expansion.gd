extends SceneTree
## Carte Crescita aggiuntive (D&D), 1° gruppo: effetti ongoing a basso rischio.
##   - "Cambio di Leadership" (1x/round): scarta la mano e pesca altrettante carte.
##   - "Tenore di Vita Elevato" (passivo): ogni aumento Prosperità costa 1 Beni di consumo in
##     meno e da' 1 VP in piu'.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_expansion.gd

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

	# 0) Le 2 nuove Growth card esistono nei dati, con i VP giusti.
	var pool: Array = DataLoader.load_growth()
	var by_id := {}
	for c in pool:
		by_id[String(c.get("id", ""))] = c
	var s0: bool = by_id.has("growth_cambio_leadership") and by_id.has("growth_tenore_vita_elevato") \
		and int(by_id["growth_cambio_leadership"].get("victory_points", 0)) == 4
	print("[%s] carte nei dati: Cambio Leadership + Tenore di Vita" % ["OK" if s0 else "FAIL"])
	if not s0: fails += 1

	# 1) "Cambio di Leadership": scarta la mano (3) e pesca 3 nuove dal mazzo.
	p.deck = [{"id": "d1"}, {"id": "d2"}, {"id": "d3"}, {"id": "d4"}, {"id": "d5"}]
	p.hand = [{"id": "h1"}, {"id": "h2"}, {"id": "h3"}]
	p.discard = []
	b._used_ongoing = {}
	b._use_ongoing("once_per_round:redraw_hand")
	var s1: bool = p.hand.size() == 3 and p.discard.size() == 3 and p.deck.size() == 2 \
		and b._ongoing_used("usa", "once_per_round:redraw_hand")
	print("[%s] Cambio Leadership: mano %d, scarti %d, mazzo %d" % [
		"OK" if s1 else "FAIL", p.hand.size(), p.discard.size(), p.deck.size()])
	if not s1: fails += 1

	# 2) Riuso nello stesso round bloccato (1x/round).
	p.hand = [{"id": "x1"}]
	b._use_ongoing("once_per_round:redraw_hand")
	var s2: bool = p.hand.size() == 1   # non ha ri-pescato
	print("[%s] Cambio Leadership: non riusabile nello stesso round" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# 3) "Tenore di Vita Elevato": l'aumento Prosperità costa 1 CG in meno e da' 1 VP in piu'.
	var steps: Array = DataLoader.load_player_boards().get("prosperity_track", {}).get("steps_partial", [])
	var step0: Dictionary = steps[0]
	var cost0 := int(step0.get("cost_consumer_goods", 0))
	var vpgain := int(step0.get("vp", 0))
	p.growth_cards = [{"effect_ops": [{"op": "ongoing", "tag": "prosperity_boost"}]}]
	p.prosperity_level = 0
	p.resources["consumer_goods"] = cost0 + 5
	var vp_before: int = p.victory_points
	var cg_before := int(p.resources.get("consumer_goods", 0))
	b._aftermath_lines.clear()
	b._aftermath_prosperity(p)
	await process_frame
	var s3: bool = p.prosperity_level == 1 \
		and p.victory_points == vp_before + vpgain + 1 \
		and int(p.resources.get("consumer_goods", 0)) == cg_before - maxi(0, cost0 - 1)
	print("[%s] Tenore di Vita: liv=%d, VP +%d (atteso +%d), CG speso=%d (atteso %d)" % [
		"OK" if s3 else "FAIL", p.prosperity_level, p.victory_points - vp_before, vpgain + 1,
		cg_before - int(p.resources.get("consumer_goods", 0)), maxi(0, cost0 - 1)])
	if not s3: fails += 1

	# 4) Senza la Growth, l'aumento Prosperità e' normale (nessuno sconto/bonus).
	var p2 = b.gs.players[1]
	b.active_seat = 1
	p2.growth_cards = []
	p2.prosperity_level = 0
	p2.resources["consumer_goods"] = cost0 + 5
	var vp2_before: int = p2.victory_points
	var cg2_before := int(p2.resources.get("consumer_goods", 0))
	b._aftermath_lines.clear()
	b._aftermath_prosperity(p2)
	await process_frame
	var s4: bool = p2.victory_points == vp2_before + vpgain \
		and int(p2.resources.get("consumer_goods", 0)) == cg2_before - cost0
	print("[%s] senza Growth: aumento Prosperità normale (VP +%d, CG -%d)" % [
		"OK" if s4 else "FAIL", p2.victory_points - vp2_before, cg2_before - int(p2.resources.get("consumer_goods", 0))])
	if not s4: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Growth espansione (1° gruppo): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
