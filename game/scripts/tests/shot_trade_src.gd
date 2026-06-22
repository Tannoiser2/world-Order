extends SceneTree
## Screenshot del Commercio con SORGENTI multiple (bandierine "compra da:") nella barra
## in alto: verifica che le bandiere siano alte quanto il testo (non più giganti).
## Uso: xvfb-run godot --path game --script res://scripts/tests/shot_trade_src.gd -- <out.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/trade_src.png"
	GameConfig.powers = ["russia", "usa", "eu", "china"]
	var board: Node = load("res://scenes/board.tscn").instantiate()
	get_root().add_child(board)
	for _i in range(6):
		await process_frame
	board._begin_action_phase()
	# Trova la Russia e rendila attiva.
	for i in board.gs.players.size():
		if board.gs.players[i].power == "russia":
			board.active_seat = i
	var p = board._active()
	p.money = 100
	# Alleata con 2 simboli Import CG → base 2; i giocatori venditori AGGIUNGONO la loro vendita.
	p.allied_countries.append({"id": "imp_cg", "region": "africa", "value": 1,
		"exports": [], "imports": ["consumer_goods", "consumer_goods"]})
	board._commerce_flipped = {}     # tutte le Commerce card scoperte (più sorgenti)
	# Sceglie un prodotto che la Russia importa da altre potenze (sorgenti = bandierine).
	board._open_trade_ui()
	var R := "consumer_goods"
	for cand in ["consumer_goods", "services", "food", "raw_materials", "energy"]:
		if board._import_sources(p, cand).size() >= 1:
			R = cand
			break
	board._trade_select_res(R)
	for _i in range(10):
		await process_frame
	await create_timer(0.3).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size(), " res=", R, " srcs=", board._import_sources(p, R))
	quit()
