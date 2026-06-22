extends SceneTree
## Screenshot della SCELTA REGIONE per un Engage: le Regioni valide si evidenziano (blu).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_engage.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/engage.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board._begin_action_phase()
	board.active_seat = board.gs.turn_order[0]
	var p = board._active()
	p.resources["diplomacy"] = 20
	# Prerequisito Engage: un alleato in una Regione (esaurito, niente popup sconto).
	p.allied_countries.append({"id": "ca_pre", "region": "central_asia", "value": 1})
	p.exhausted["ca_pre"] = true
	var card := {"display_name": "Eng", "effect_ops": [{"op": "engage"}]}
	p.hand.append(card); board._plays_left = 9
	board._play_card(card)   # awaiting = "region": le Regioni si evidenziano
	for _i in range(10):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size(), " awaiting=", board.awaiting)
	quit()
