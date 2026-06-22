extends SceneTree
## Screenshot del popup Research/Market (verifica dimensioni carte).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_research.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/research.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	# Prepara lo stato Research: mercato pieno e qualche punto Research.
	board.active_seat = board.gs.turn_order[0]
	board._refill_market()
	board._research_points = 8
	board._show_research()
	for _i in range(10):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
