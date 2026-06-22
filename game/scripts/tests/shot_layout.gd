extends SceneTree
## Prova del NUOVO LAYOUT: mappa a sinistra, pannello board a destra (sempre visibile),
## sezioni in colonna (plancia · commercio+prodotti · alleate · crescita), mano in basso.
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_layout.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/layout.png"
	GameConfig.powers = ["russia", "usa", "eu", "china"]
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board._begin_action_phase()
	var p = board._active()
	# Qualche nazione alleata e carta crescita, così si vedono tutte le sezioni.
	var allies := []
	for c in board.all_countries:
		if String(c.get("region", "")) == String(p.allied_region if "allied_region" in p else ""):
			pass
	var n := 0
	for c in board.all_countries:
		allies.append(c); n += 1
		if n >= 3: break
	p.allied_countries = allies
	for c in allies:
		p.exhausted[String(c.get("id", ""))] = false
	if board.growth_pool.size() > 0:
		p.growth_cards = [board.growth_pool[0].duplicate()]
		if board.growth_pool.size() > 1:
			p.growth_cards.append(board.growth_pool[1].duplicate())
	board._refresh()
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
