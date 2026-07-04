extends SceneTree
## Segnalazione: 1) le linguette (bandiere) delle potenze, prima in una barra a sé in fondo
## allo schermo, ora stanno DENTRO il pannello board (in cima), sempre visibili/ispezionabili
## qualunque sia la board mostrata. 2) La mano ha ora una barra divisoria trascinabile (come
## quella board/mappa) per scegliere quanto e' alta quando aperta - continua a nascondersi da
## sola quando non serve (Commercio/Produce/scelte sulla mappa/ecc).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_board_tabs_and_hand_resize.gd

func _is_descendant(node: Node, ancestor: Node) -> bool:
	var n := node.get_parent()
	while n != null:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false


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

	# 1) tab_bar e' ora DENTRO il pannello board (drawer), non più figlio diretto della radice
	#    in fondo allo schermo. Niente più tab_bg (rimosso, non serve più).
	var s1: bool = _is_descendant(b.tab_bar, b.drawer) and not ("tab_bg" in b)
	print("[%s] le linguette potenze sono dentro il pannello board (dentro drawer=%s, tab_bg rimosso=%s)" % [
		"OK" if s1 else "FAIL", str(_is_descendant(b.tab_bar, b.drawer)), str(not ("tab_bg" in b))])
	if not s1: fails += 1

	# 2) Restano FUNZIONANTI: toccare una linguetta cambia ancora la board mostrata.
	var china_btn: Button = b.tab_bar.get_child(1)
	china_btn.pressed.emit()
	await process_frame
	var s2: bool = b.drawer_power == "china"
	print("[%s] toccare una linguetta cambia ancora la board mostrata (drawer_power=%s)" % [
		"OK" if s2 else "FAIL", b.drawer_power])
	if not s2: fails += 1

	# 3) Mano APERTA (nessuna scelta in corso): lo splitter e' visibile.
	b.active_seat = 0
	b.awaiting = ""
	b._trade_mode = false
	b._produce_mode = false
	b._ui_phase = "Azione"
	b.hand_collapsed = false
	b._refresh()
	await process_frame
	var s3: bool = b.hand_splitter.visible
	print("[%s] con la mano aperta lo splitter e' visibile" % ["OK" if s3 else "FAIL"])
	if not s3: fails += 1

	# 4) Trascinandolo verso l'ALTO la mano diventa più ALTA (segue il gesto).
	var h_before: float = b.hand_panel.size.y
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	b._on_hand_splitter_input(press)
	for _i in 3:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, -50)   # verso l'alto
		b._on_hand_splitter_input(motion)
	await process_frame
	var h_after: float = b.hand_panel.size.y
	var s4: bool = h_after > h_before + 100.0
	print("[%s] trascinando verso l'alto la mano diventa più alta (prima=%.0f dopo=%.0f)" % [
		"OK" if s4 else "FAIL", h_before, h_after])
	if not s4: fails += 1
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	b._on_hand_splitter_input(release)

	# 5) Durante il Commercio (auto-hide) la mano si richiude e lo splitter sparisce da solo -
	#    niente da ridimensionare quando non serve.
	b._trade_mode = true
	b._refresh()
	await process_frame
	var s5: bool = b.hand_box == null and not b.hand_splitter.visible
	print("[%s] durante il Commercio la mano si auto-nasconde e lo splitter sparisce (hand_box=%s, splitter visibile=%s)" % [
		"OK" if s5 else "FAIL", str(b.hand_box), str(b.hand_splitter.visible)])
	if not s5: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica linguette nel pannello board + mano ridimensionabile: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
