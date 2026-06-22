extends SceneTree
## Screenshot della barra SCELTE in alto (niente popup sopra la board).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_choice.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/choice.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board._show_popup("Quante Armate sposti in Africa?", [
		{"label": "1 Armata (costo 5)", "value": 1},
		{"label": "2 Armate (costo 15)", "value": 2},
		{"label": "3 Armate (costo 30)", "value": 3},
	], func(_v): pass)
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
