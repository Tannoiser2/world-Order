extends SceneTree
## Screenshot della mano ridisegnata: 6 carte + gettone 💰10 + carte Strategiche.
## Una carta è selezionata (evidenziata). Uso: xvfb-run godot --path game --script res://scripts/tests/shot_hand.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/hand.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board.active_seat = board.gs.turn_order[0]
	board.drawer_open = true
	board.drawer_power = board._active().power
	board._refresh()
	var p = board._active()
	if p.hand.size() > 0:
		board._on_hand_card_tap(p.hand[0])   # seleziona la prima carta (evidenziata)
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
