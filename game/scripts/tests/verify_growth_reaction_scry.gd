extends SceneTree
## Carte Crescita (Diplomacy & Dominance) once-per-round:
##   - Forza di Reazione Rapida (Liv.1): in base al Focus, dispiega 1 Armata gratis (Militare)
##     o spendi 5 money per +1 Armata (Nazionale/Diplomatico).
##   - Collaborazione con gli Alleati (Liv.2): esaurisci 1 alleato pronto, guarda in cima al
##     mazzo carte pari al suo valore, pescane 1, lascia le altre in cima.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_reaction_scry.gd

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
	p.growth_cards = [
		{"id": "growth_forza_reazione_rapida", "level": 1, "effect_ops": [{"op": "ongoing", "tag": "once_per_round:reaction_force"}]},
		{"id": "growth_collaborazione_alleati", "level": 2, "effect_ops": [{"op": "ongoing", "tag": "once_per_round:scry_ally"}]},
	]

	await _test_reaction_military(b, p)
	await _test_reaction_domestic(b, p)
	await _test_scry(b, p)

	b.queue_free()
	await process_frame
	print("Verifica Forza di Reazione Rapida + Collaborazione con gli Alleati: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1


func _test_reaction_military(b: Variant, p) -> void:
	b._used_ongoing = {}
	p.focus = WO.Focus.MILITARY
	for rid in b.gs.regions:
		b.gs.regions[rid]["armies"]["usa"] = 0
	b._use_ongoing("once_per_round:reaction_force")
	await process_frame
	var popup_ok: bool = b._popup_active() and b._popup_items.size() == b.gs.regions.size()
	_check(popup_ok, "Forza (Militare): popup di scelta Regione (%d Regioni)" % b._popup_items.size())
	var target := String((b._popup_items[0] as Dictionary).get("value", ""))
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))
	await process_frame
	var placed: bool = int(b.gs.regions[target]["armies"].get("usa", 0)) == 1
	_check(placed, "Forza (Militare): 1 Armata dispiegata gratis in %s" % target)
	_check(b._ongoing_used("usa", "once_per_round:reaction_force"), "Forza: segnata usata nel round")


func _test_reaction_domestic(b: Variant, p) -> void:
	b._used_ongoing = {}
	p.focus = WO.Focus.DOMESTIC
	p.money = 10
	p.armies_available = 0
	b._use_ongoing("once_per_round:reaction_force")
	await process_frame
	var popup_ok: bool = b._popup_active() and b._popup_items.size() == 2
	_check(popup_ok, "Forza (Nazionale): popup spendi-5-money (2 opzioni)")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))   # "Sì"
	await process_frame
	_check(p.money == 5 and p.armies_available == 1, "Forza (Nazionale): -5 money (=%d), +1 Armata (=%d)" % [p.money, p.armies_available])


func _test_scry(b: Variant, p) -> void:
	b._used_ongoing = {}
	p.allied_countries = [{"id": "ally_x", "display_name": "Paese X", "value": 2, "region": "europe"}]
	p.exhausted = {}
	p.deck = [
		{"id": "c1", "display_name": "Carta 1", "value": 3},
		{"id": "c2", "display_name": "Carta 2", "value": 1},
		{"id": "c3", "display_name": "Carta 3", "value": 2},
	]
	p.hand = []
	b._use_ongoing("once_per_round:scry_ally")
	await process_frame
	var ally_popup: bool = b._popup_active() and b._popup_items.size() == 1
	_check(ally_popup, "Collaborazione: popup scelta Nazione Alleata pronta")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))   # esaurisci l'unico alleato
	await process_frame
	var scry_popup: bool = b._popup_active() and b._popup_items.size() == 2
	_check(scry_popup, "Collaborazione: guarda le prime 2 carte (valore alleato = 2)")
	_check(bool(p.exhausted.get("ally_x", false)), "Collaborazione: Nazione Alleata esaurita")
	var picked := String((b._popup_items[0] as Dictionary).get("value", {}).get("id", ""))
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))   # pesca la 1ª delle 2
	await process_frame
	var drawn_ok: bool = p.hand.size() == 1 and String(p.hand[0].get("id", "")) == picked
	var deck_ok: bool = p.deck.size() == 2
	_check(drawn_ok, "Collaborazione: pescata la carta scelta (%s)" % picked)
	_check(deck_ok, "Collaborazione: le altre restano nel mazzo (deck=%d)" % p.deck.size())
