extends SceneTree
## Screenshot della scelta SCONTO (esaurisci alleati cliccando le carte) + barra in alto.
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_exhaust.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/exhaust.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board.active_seat = board.gs.turn_order[0]
	var p = board._active()
	var ally := {"id": "demo_ally", "display_name": "Demo Ally", "region": "europe", "value": 3, "exports": [], "imports": []}
	p.allied_countries.append(ally)
	p.exhausted["demo_ally"] = false
	board._pick_exhaust_discount("europe", "Engage in Europe (costo 5 Dip)", func(_c): pass)
	board._on_exhaust_toggle(ally)   # attiva l'alleato per lo sconto (evidenziato)
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
