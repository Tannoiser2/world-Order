extends SceneTree
## Test di renderizzazione caratteri: mostra i simboli sospetti per vedere quali sono
## "box" (non supportati dal font). Uso: xvfb-run godot --path game --script res://scripts/tests/shot_glyphs.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/glyphs.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(4):
		await process_frame
	var lbl := Label.new()
	lbl.text = "dbl 2194:[↔]  bullet 2022:[•]  cycle 21bb:[↻]  delta 394:[Δ]  dot b7:[·]"
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.position = Vector2(20, 60)
	lbl.add_theme_color_override("font_color", Color(1,1,1))
	board.add_child(lbl)
	for _i in range(6):
		await process_frame
	await create_timer(0.2).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
