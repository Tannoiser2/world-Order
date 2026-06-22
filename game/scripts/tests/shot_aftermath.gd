extends SceneTree
## Screenshot dell'Aftermath sulla MAPPA/PLANCIA: token Engage cliccabili sulla mappa,
## corona Prosperità cliccabile sulla plancia, scelte nella barra in alto.
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_aftermath.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/aftermath.png"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board.gs.round = 1
	var p = board.gs.players[0]
	p.prosperity_level = 0
	p.resources["consumer_goods"] = 5
	p.engage_tokens = ["africa", "europe"]
	p.allied_countries = [{"id": "aa", "region": "africa", "value": 1},
		{"id": "ab", "region": "africa", "value": 1}, {"id": "ae", "region": "europe", "value": 1}]
	board._run_aftermath()       # entra nella fase scelte del 1° giocatore (sulla mappa)
	for _i in range(10):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
