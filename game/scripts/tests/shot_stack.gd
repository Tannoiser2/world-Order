extends SceneTree
## Prova delle PILE di carte alleate uguali (xN): le copie si sfalsano verso il BASSO,
## cosi' si vede la PRODUZIONE della carta sotto (non solo il bordo superiore).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_stack.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/stack.png"
	GameConfig.powers = ["russia", "usa", "eu", "china"]
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board._begin_action_phase()
	var p = board._active()
	# Costruisco alleate con DUPLICATI: prima nazione x3, seconda x2, poi alcune singole.
	var base := []
	for c in board.all_countries:
		base.append(c)
		if base.size() >= 5: break
	var allies := []
	allies.append(base[0]); allies.append(base[0]); allies.append(base[0])  # x3
	allies.append(base[1]); allies.append(base[1])                          # x2
	allies.append(base[2]); allies.append(base[3]); allies.append(base[4])  # singole
	p.allied_countries = allies
	for c in allies:
		p.exhausted[String(c.get("id", ""))] = false
	board.hand_collapsed = true   # mano chiusa: si vedono le pile intere
	board._refresh()
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
