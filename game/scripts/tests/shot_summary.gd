extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/summary.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board._show_summary(["— FINE ROUND 1 —", "Auto-Influence: Russia +Influenza in Africa", "USA: 12 VP", "China: 9 VP", "EU: 15 VP", "Russia: 7 VP"], func(): pass)
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
