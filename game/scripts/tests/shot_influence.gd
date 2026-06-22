extends SceneTree
## Screenshot della scelta Influenza sulla MAPPA (add_influence): cassetto chiuso,
## caselle valide evidenziate (verde = permanente, viola = temporanea).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_influence.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/influence.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board.active_seat = board.gs.turn_order[0]
	var p = board._active()
	var card := {"display_name": "Inf", "effect_ops": [{"op": "add_influence"}]}
	p.hand.append(card)
	board._plays_left = 9
	board._play_card(card)   # entra in influence_cell ed evidenzia le caselle
	for _i in range(10):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
