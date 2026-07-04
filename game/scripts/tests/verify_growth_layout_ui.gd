extends SceneTree
## Segnalazione (con screenshot): le Growth card erano impilate una per riga (VBoxContainer,
## tanto spazio verticale sprecato) e il bordo verde "usabile" abbracciava un rettangolo
## enorme quanto la riga intera, non la carta - perche' il bottone si allargava a tutta la
## larghezza del contenitore (SIZE_FILL di default in un VBox/HBox). Corretto: le carte stanno
## IN FILA (HFlowContainer, va a capo da solo) e il bottone-carta resta alla SUA dimensione
## nativa (SIZE_SHRINK_BEGIN), cosi' l'evidenziazione resta sulla carta.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_layout_ui.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	var once_card_a := {"display_name": "Reduced Bureaucracy", "art": "growth_aux/growth_aux_001.jpg",
		"effect_ops": [{"op": "ongoing", "tag": "once_per_round:draw_then_trash"}]}
	var once_card_b := {"display_name": "Reazione Rapida", "art": "growth_aux/growth_aux_002.jpg",
		"effect_ops": [{"op": "ongoing", "tag": "once_per_round:reaction_force"}]}

	var p = b.gs.players[0]
	p.growth_cards = [once_card_a, once_card_b]
	b._used_ongoing = {}
	b.playing_card = {}
	# Contenitore "largo" (come il pannello board reale): se il bottone si allargasse a tutta
	# la riga anziche' restare alla sua dimensione, lo scopriremmo qui.
	var host := Control.new()
	host.custom_minimum_size = Vector2(900, 400)
	get_root().add_child(host)
	b._build_growth_section(p, true, host)
	await process_frame

	var col: Node = host.get_child(0)
	var s1: bool = col is HFlowContainer
	print("[%s] le Growth card sono in un contenitore a RIGA (HFlowContainer), non impilate" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	var buttons := []
	for c in col.get_children():
		if c is Button:
			buttons.append(c)
	var s2: bool = buttons.size() == 2
	print("[%s] entrambe le Growth card renderizzate (bottoni=%d, attesi 2)" % ["OK" if s2 else "FAIL", buttons.size()])
	if not s2: fails += 1

	var expected_w: float = clampf(b._plancia_height() * 0.78, 120.0, 200.0)
	var shrink_ok := true
	var width_ok := true
	for btn in buttons:
		if int((btn as Button).size_flags_horizontal) != int(Control.SIZE_SHRINK_BEGIN):
			shrink_ok = false
		if absf((btn as Button).custom_minimum_size.x - expected_w) > 0.5:
			width_ok = false
	var s3: bool = shrink_ok and width_ok
	print("[%s] il bottone-carta NON si allarga a tutta la riga (SIZE_SHRINK_BEGIN, larghezza=%.0f attesa=%.0f)" % [
		"OK" if s3 else "FAIL", (buttons[0] as Button).custom_minimum_size.x if buttons.size() > 0 else -1.0, expected_w])
	if not s3: fails += 1

	host.queue_free()
	b.queue_free()
	await process_frame
	print("Verifica layout Growth (riga + evidenziazione sulla carta): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
