extends SceneTree
## Screenshot del Commercio (banner con vendita Armate dalla riserva, #14).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_trade.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/trade.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board._begin_action_phase()
	board.active_seat = board.gs.turn_order[0]
	var p = board._active()
	p.armies_available = maxi(p.armies_available, 6)
	p.resources["services"] = 3
	p.resources["food"] = 3        # Serv e Food sulla STESSA casella → anello con ↻ (ciclo)
	board._open_trade_ui()   # stato iniziale: selezione del prodotto sulla casella
	for _i in range(10):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
