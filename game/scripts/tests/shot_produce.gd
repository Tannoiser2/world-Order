extends SceneTree
## Screenshot del Produce sulla PLANCIA (caselle sulla resource track + barra).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_produce.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/produce.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board.active_seat = board.gs.turn_order[0]
	var p = board._active()
	p.production = {"energy": 3, "consumer_goods": 2, "armies": 1}
	p.resources["energy"] = 2
	p.resources["raw_materials"] = 6
	p.resources["consumer_goods"] = 1
	var card := {"display_name": "Prod", "effect_ops": [{"op": "produce"}]}
	p.hand.append(card); board._plays_left = 9
	board._play_card(card)              # entra in Produce sulla plancia
	board._produce_set("energy", 2)     # stage +2 Energia
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
