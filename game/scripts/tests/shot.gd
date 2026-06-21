extends SceneTree
## Cattura screenshot del tabellone per calibrazione UI.
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot.gd -- <out.png> [drawer]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/shot.png"
	var open_drawer: bool = args.size() > 1 and args[1] == "drawer"
	get_root().set_content_scale_size(Vector2i(1340, 700))
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	await process_frame
	await process_frame
	if open_drawer:
		board.drawer_open = true
		board.drawer_power = board._active().power
		board._refresh()
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
