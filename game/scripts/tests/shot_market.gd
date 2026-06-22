extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/market.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6): await process_frame
	board._begin_action_phase()
	var p = board._active()
	p.allied_countries = []
	for c in board.all_countries:
		p.allied_countries.append(c)
		if p.allied_countries.size() >= 2: break
	for c in p.allied_countries: p.exhausted[String(c.get("id",""))] = false
	board._begin_research()
	for _i in range(10): await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out); print("saved ", out, " phase=", board._ui_phase); quit()
