extends SceneTree
## Growth "Ottimizzazione delle Entrate" (Liv.1, tag "research_top_bonus_twice"): verifica che
## l'abilita' funzioni DAVVERO end-to-end - acquisto REALE (_buy_growth_action, non impostare
## p.growth_cards a mano) seguito dalla vera Research (_research_next), non solo la funzione
## interna _apply_top_bonus_best isolata (che da sola non prova che la carta sia collegata).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_ottimizzazione_entrate.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	var card := {}
	for c in DataLoader.load_growth():
		if String(c.get("id", "")) == "growth_ottimizzazione_entrate":
			card = c
	var s0: bool = not card.is_empty() and card.get("level", 0) == 1 \
		and _has_ongoing(card, "research_top_bonus_twice")
	print("[%s] carta nei dati con il tag 'research_top_bonus_twice'" % ["OK" if s0 else "FAIL"])
	if not s0: fails += 1

	# 1) Acquisto REALE (stesso codice di un giocatore che compra la Growth): l'effetto ongoing
	#    resta collegato alla carta in p.growth_cards (niente strip/perdita dell'effetto).
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.active_seat = 0
	var p = b.gs.players[0]
	p.money = 50
	p.resources["services"] = 5
	p.growth_cards = []
	b._buy_growth_action(card, 1)
	await process_frame
	var s1: bool = p.growth_cards.size() == 1 \
		and _has_ongoing(p.growth_cards[0], "research_top_bonus_twice")
	print("[%s] acquisto reale: la carta finisce in growth_cards con l'ongoing intatto" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) SENZA la Growth (altro giocatore): la Research applica il top_bonus di ogni carta UNA
	#    sola volta.
	var ch := 1
	var pc = b.gs.players[ch]
	pc.growth_cards = []
	pc.money = 0
	pc.resources["diplomacy"] = 0
	pc.hand = [
		{"top_bonus": {"kind": "money", "amount": 2}},
		{"top_bonus": {"kind": "money", "amount": 5}},
		{"top_bonus": {"kind": "diplomacy", "amount": 3}},
	]
	b._ui_phase = "Research"
	b._research_idx = 0
	b.gs.turn_order.assign([ch, 0])
	b._research_next()
	await process_frame
	var s2: bool = pc.money == 7 and int(pc.resources.get("diplomacy", 0)) == 3
	print("[%s] senza Ottimizzazione Entrate: bonus applicato 1 sola volta (money=%d dip=%d, attesi 7/3)" % [
		"OK" if s2 else "FAIL", pc.money, int(pc.resources.get("diplomacy", 0))])
	if not s2: fails += 1

	# 3) CON la Growth (il giocatore che l'ha comprata al passo 1): la Research applica il
	#    top_bonus normale UNA volta, poi RI-applica quello delle 2 carte migliori (Ottimizzazione
	#    delle Entrate) - stesso mazzo, stesso ordine di reveal.
	p.money = 0
	p.resources["diplomacy"] = 0
	p.hand = [
		{"top_bonus": {"kind": "money", "amount": 2}},
		{"top_bonus": {"kind": "money", "amount": 5}},
		{"top_bonus": {"kind": "diplomacy", "amount": 3}},
	]
	b._research_idx = 1   # p (seggio 0) e' il 2° nel turn_order [ch, 0]
	b._research_next()
	await process_frame
	# Normale: +2+5 money, +3 diplomazia. Ottimizzazione: ri-applica le 2 migliori (5 money, 3
	# diplomazia) -> totale money = 7+5 = 12, diplomazia = 3+3 = 6.
	var s3: bool = p.money == 12 and int(p.resources.get("diplomacy", 0)) == 6
	print("[%s] CON Ottimizzazione Entrate: bonus delle 2 migliori RI-applicato (money=%d dip=%d, attesi 12/6)" % [
		"OK" if s3 else "FAIL", p.money, int(p.resources.get("diplomacy", 0))])
	if not s3: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Growth 'Ottimizzazione delle Entrate' (end-to-end): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)


func _has_ongoing(card: Dictionary, tag: String) -> bool:
	for op in (card.get("effect_ops", []) as Array):
		if String((op as Dictionary).get("op", "")) == "ongoing" and String((op as Dictionary).get("tag", "")) == tag:
			return true
	return false
