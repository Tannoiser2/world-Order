extends SceneTree
## Screenshot del menu con la LOBBY LAN aperta (modalità Online).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_lobby.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/lobby.png"
	get_root().set_content_scale_size(Vector2i(1280, 800))
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	get_root().add_child(menu)
	for _i in range(4):
		await process_frame
	# Seleziona la modalità Online -> mostra la lobby, poi simula "Ospita".
	menu._on_mode("online")
	menu._on_host()
	for _i in range(8):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
