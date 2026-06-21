extends SceneTree
## Cattura screenshot del tabellone per calibrazione UI.
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot.gd -- <out.png> [drawer]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/shot.png"
	var open_drawer: bool = args.size() > 1 and args[1] == "drawer"
	var demo: bool = args.size() > 1 and args[1] == "demo"
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(4):
		await process_frame
	if open_drawer:
		board.drawer_open = true
		board.drawer_power = board._active().power
		board._refresh()
	if demo:
		# Stato DIMOSTRATIVO (solo per screenshot): inietto Armate + Influenza in
		# varie Regioni DOPO l'init, poi ri-renderizzo solo gli overlay (niente fase
		# di gioco), così si vedono le posizioni di carri e cubi.
		var R: Dictionary = board.gs.regions
		R["europe"]["armies"] = {"usa": 2, "china": 1}
		R["americas"]["armies"] = {"usa": 3}
		R["central_asia"]["armies"] = {"russia": 2}
		R["east_asia_pacific"]["armies"] = {"china": 2, "usa": 1}
		R["africa"]["armies"] = {"eu": 1}
		R["middle_east_north_africa"]["armies"] = {"russia": 1, "eu": 1}
		R["south_asia"]["armies"] = {"china": 1}
		R["americas"]["track"].add("usa", "temporary")
		R["americas"]["track"].add("china", "temporary")
		R["central_asia"]["track"].add("russia", "permanent")
		R["central_asia"]["track"].add("eu", "temporary")
		R["east_asia_pacific"]["track"].add("china", "permanent")
		R["east_asia_pacific"]["track"].add("usa", "temporary")
		R["africa"]["track"].add("eu", "temporary")
		R["africa"]["track"].add("russia", "temporary")
		board._layout_overlays()
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
