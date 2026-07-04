extends SceneTree
## Le Growth Card con abilità "once per round" (es. Reduced Bureaucracy) e le carte Commerce
## mostrano ora lo stesso "giro" grigio delle Nazioni esaurite quando già usate nel round,
## e tornano normali al round successivo (quando _used_ongoing si azzera).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_flip.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	# 1) _growth_once_per_round_tag: riconosce il tag giusto, "" per le altre.
	var once_card := {"display_name": "Reduced Bureaucracy",
		"effect_ops": [{"op": "ongoing", "tag": "once_per_round:draw_then_trash"}]}
	var passive_card := {"display_name": "Tactical Flexibility",
		"effect_ops": [{"op": "ongoing", "tag": "extra_draw_per_round"}]}
	var immediate_card := {"display_name": "Industrial Development",
		"effect_ops": [{"op": "increase_production", "count": 2}]}
	var empty_card := {"display_name": "Space Program", "effect_ops": []}

	var s1: bool = b._growth_once_per_round_tag(once_card) == "once_per_round:draw_then_trash"
	print("[%s] once_per_round riconosciuto (%s)" % ["OK" if s1 else "FAIL", b._growth_once_per_round_tag(once_card)])
	if not s1: fails += 1

	var s2: bool = b._growth_once_per_round_tag(passive_card) == ""
	print("[%s] ongoing sempre-attiva -> nessun tag (non si gira mai)" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	var s3: bool = b._growth_once_per_round_tag(immediate_card) == "" and b._growth_once_per_round_tag(empty_card) == ""
	print("[%s] effetto immediato / nessun effetto -> nessun tag" % ["OK" if s3 else "FAIL"])
	if not s3: fails += 1

	# 2) Render reale della sezione Growth: la carta si gira (grigio marcato) quando la sua
	#    abilità once-per-round e' gia' stata usata in questo round.
	var p = b.gs.players[0]
	p.growth_cards = [once_card]
	b._used_ongoing = {}
	var col := VBoxContainer.new()
	get_root().add_child(col)
	b._build_growth_section(p, true, col)
	await process_frame
	var card1: Control = _first_button(col)
	var s4: bool = card1 != null and card1.modulate.is_equal_approx(Color(1, 1, 1))
	print("[%s] Non ancora usata in questo round: aspetto normale" % ["OK" if s4 else "FAIL"])
	if not s4: fails += 1
	for c in col.get_children(): c.queue_free()
	await process_frame

	# Segna l'abilità come usata questo round, ricostruisce la sezione: deve girarsi (grigia).
	b._used_ongoing[p.power] = ["once_per_round:draw_then_trash"]
	var col2 := VBoxContainer.new()
	get_root().add_child(col2)
	b._build_growth_section(p, true, col2)
	await create_timer(0.4).timeout
	var card2: Control = _first_button(col2)
	var s5: bool = card2 != null and card2.modulate.r < 0.45
	print("[%s] Usata in questo round: la carta si gira (grigio marcato)" % ["OK" if s5 else "FAIL"])
	if not s5: fails += 1

	# Nuovo round (_used_ongoing si azzera): torna normale.
	b._used_ongoing = {}
	for c in col2.get_children(): c.queue_free()
	var col3 := VBoxContainer.new()
	get_root().add_child(col3)
	b._build_growth_section(p, true, col3)
	await create_timer(0.4).timeout
	var card3: Control = _first_button(col3)
	var s6: bool = card3 != null and card3.modulate.is_equal_approx(Color(1, 1, 1))
	print("[%s] Nuovo round: torna disponibile (aspetto normale)" % ["OK" if s6 else "FAIL"])
	if not s6: fails += 1

	col.queue_free(); col2.queue_free(); col3.queue_free()
	b.queue_free()
	await process_frame
	print("Verifica giro Growth once-per-round / Commerce: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)


func _first_button(node: Node) -> Control:
	if node is Button:
		return node
	for c in node.get_children():
		var f := _first_button(c)
		if f != null:
			return f
	return null
