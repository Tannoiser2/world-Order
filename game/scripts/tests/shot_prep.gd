extends SceneTree
## Screenshot della PREPARAZIONE guidata: scelta del Focus nella barra in alto + plancia.
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_prep.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/prep.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)            # _ready entra nella PREPARAZIONE del round 1
	for _i in range(10):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size(), " phase=", board._ui_phase)
	quit()
