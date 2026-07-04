extends SceneTree
## Segnalazione: il tasto "Fine turno" (prima fisso in basso a destra) non si riusciva più a
## premere - probabilmente finiva sotto uno degli splitter trascinabili (board/mappa o mano)
## introdotti di recente, che hanno uno z_index più alto. Spostato nella TOP BAR (riga
## round/turno/money), più coerente ora che anche le linguette delle potenze sono nel pannello
## board - lì non c'è nulla con cui possa sovrapporsi.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_end_turn_top_bar.gd

func _rects_overlap(a_pos: Vector2, a_size: Vector2, b_pos: Vector2, b_size: Vector2) -> bool:
	var a := Rect2(a_pos, a_size)
	var b := Rect2(b_pos, b_size)
	return a.intersects(b)


func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	b.size = Vector2(1600, 900)
	b._layout_ui()
	await process_frame

	# 1) Il bottone e' DENTRO l'area della top bar (top_hud), non più in basso.
	var top_hud_rect := Rect2(b.top_hud.position, b.top_hud.size)
	var btn_rect := Rect2(b.end_turn_btn.position, b.end_turn_btn.size)
	var s1: bool = top_hud_rect.encloses(btn_rect)
	print("[%s] 'Fine turno' e' dentro la top bar (btn=%s, top_hud=%s)" % [
		"OK" if s1 else "FAIL", str(btn_rect), str(top_hud_rect)])
	if not s1: fails += 1

	# 2) Non si sovrappone più con lo splitter board/mappa (anche con la mano aperta e
	#    ridimensionata, lo scenario del bug segnalato).
	b.active_seat = 0
	b.awaiting = ""
	b._trade_mode = false
	b._produce_mode = false
	b._ui_phase = "Azione"
	b.hand_collapsed = false
	b._hand_h_frac = 0.5
	b._board_w_frac = 0.5
	b._refresh()
	await process_frame
	var s2: bool = not _rects_overlap(b.end_turn_btn.position, b.end_turn_btn.size, b.board_splitter.position, b.board_splitter.size)
	print("[%s] 'Fine turno' non si sovrappone allo splitter board/mappa (mano aperta e ridimensionata)" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# 3) Non si sovrappone nemmeno con lo splitter della mano, quando visibile.
	var s3: bool = not b.hand_splitter.visible or not _rects_overlap(
		b.end_turn_btn.position, b.end_turn_btn.size, b.hand_splitter.position, b.hand_splitter.size)
	print("[%s] 'Fine turno' non si sovrappone allo splitter della mano" % ["OK" if s3 else "FAIL"])
	if not s3: fails += 1

	# 4) Resta comunque cliccabile/funzionante: premerlo chiude il turno quando abilitato.
	b.gs.players[0].hand = []
	b._played_this_turn = true
	b._plays_left = 0
	b._refresh_hud(b.gs.players[0])
	var s4: bool = not b.end_turn_btn.disabled
	print("[%s] il bottone resta funzionante (abilitato quando il turno e' concluso)" % ["OK" if s4 else "FAIL"])
	if not s4: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica 'Fine turno' nella top bar: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
