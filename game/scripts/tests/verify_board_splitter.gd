extends SceneTree
## Richiesta: poter trascinare una barra divisoria fra la board (plancia) e la mappa, per
## ridimensionare le due colonne a piacere invece di una proporzione fissa automatica.
## _board_w() ora rispetta _board_w_frac (impostata trascinando board_splitter) quando
## presente; il contenuto (drawer/map_viewport/Registro) si riadatta ad ogni _layout_ui.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_board_splitter.gd

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

	# 1) Di default (nessun trascinamento) la larghezza e' quella AUTOMATICA calcolata da
	#    _board_w, e lo splitter e' posizionato esattamente sul confine.
	var auto_w: float = b._board_w()
	var s1: bool = b._board_w_frac < 0.0 and absf(b.board_splitter.position.x + b.board_splitter.size.x * 0.5 - auto_w) < 1.0
	print("[%s] di default la board usa la larghezza automatica, splitter sul confine (auto_w=%.0f)" % [
		"OK" if s1 else "FAIL", auto_w])
	if not s1: fails += 1

	# 2) Trascinando lo splitter (press + N motion con spostamento RELATIVO) la larghezza board
	#    CAMBIA seguendo il gesto, e mappa/Registro si riadattano subito.
	var mv_w_before: float = b.map_viewport.size.x
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	b._on_splitter_input(press)
	var s2: bool = b._splitter_dragging
	print("[%s] premendo sullo splitter inizia il trascinamento (_splitter_dragging=%s)" % ["OK" if s2 else "FAIL", str(s2)])
	if not s2: fails += 1

	# Sposto il mouse di +300px verso destra (board più larga), in 3 eventi da 100px come
	# farebbe un vero trascinamento (piu' realistico di un salto unico).
	for _i in 3:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(100, 0)
		b._on_splitter_input(motion)
	await process_frame

	var new_w: float = b._board_w()
	var s3: bool = new_w > auto_w + 250.0
	print("[%s] trascinando +300px, la larghezza board segue il gesto (nuova=%.0f, era %.0f)" % [
		"OK" if s3 else "FAIL", new_w, auto_w])
	if not s3: fails += 1

	var s4: bool = absf(b.drawer.size.x - new_w) < 1.0 and b.map_viewport.size.x < mv_w_before - 250.0
	print("[%s] il contenuto si riadatta DINAMICAMENTE (drawer=%.0f, mappa prima=%.0f ora=%.0f)" % [
		"OK" if s4 else "FAIL", b.drawer.size.x, mv_w_before, b.map_viewport.size.x])
	if not s4: fails += 1

	# 3) Rilascio: il trascinamento finisce (nuovi movimenti del mouse non cambiano più nulla).
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	b._on_splitter_input(release)
	var s5: bool = not b._splitter_dragging
	print("[%s] rilasciando il bottone il trascinamento finisce (_splitter_dragging=%s)" % ["OK" if s5 else "FAIL", str(b._splitter_dragging)])
	if not s5: fails += 1

	var motion2 := InputEventMouseMotion.new()
	motion2.relative = Vector2(-500, 0)
	b._on_splitter_input(motion2)
	var s6: bool = absf(b._board_w() - new_w) < 1.0
	print("[%s] dopo il rilascio, muovere il mouse NON cambia più la larghezza (%.0f invariata)" % ["OK" if s6 else "FAIL", b._board_w()])
	if not s6: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica splitter trascinabile board/mappa: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
