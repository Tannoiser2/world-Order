extends SceneTree
## Diagnostica bilanciamento: scompone i VP per fonte su N partite tutte-Bot.
## Mostra, per ogni potenza, la media di VP da: regioni, obiettivi, token maggioranza,
## abilità speciali, prosperità, THREAT (perdite) e carte/altro (residuo).
## Uso: godot --headless --path game --script res://scripts/tests/_sim_vp_breakdown.gd -- <N>

func _initialize() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	var N: int = int(args[0]) if args.size() > 0 else 50
	var powers := ["usa", "eu", "russia", "china"]
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = powers
	GameConfig.automa_powers = powers.duplicate()
	GameConfig.automa_difficulty = "normal"
	GameConfig.fast_sim = true

	# Fonti note (in _vp_dbg) + "carte" come residuo (total - somma note).
	var sources := ["regioni", "obiettivi", "token", "speciali", "prosperita", "threat", "carte"]
	var acc := {}        # potenza -> fonte -> somma VP
	var total := {}      # potenza -> somma VP totali
	for p in powers:
		acc[p] = {}
		for s in sources: acc[p][s] = 0.0
		total[p] = 0.0

	for g in range(N):
		var b: Variant = bp.instantiate()
		get_root().add_child(b)
		await process_frame
		b._begin_action_phase()
		var steps := 0
		while not b.game_over and steps < 6000:
			b._automa_run()
			steps += 1
			if steps % 12 == 0:
				await process_frame
		var dbg: Dictionary = b._vp_dbg
		for pl in b.gs.players:
			var pw: String = pl.power
			total[pw] += pl.victory_points
			var known := 0.0
			var src: Dictionary = dbg.get(pw, {})
			for s in sources:
				if s == "carte": continue
				var v := float(src.get(s, 0))
				acc[pw][s] += v
				known += v
			# "carte/altro" = tutto ciò che non è stato classificato (VP iniziali, carte Crescita/Azione...)
			acc[pw]["carte"] += float(pl.victory_points) - known
		b.queue_free()
		await process_frame

	# --- Report ---
	print("\n===== SCOMPOSIZIONE VP PER FONTE: %d partite (4 Automa) =====" % N)
	print("(medie per partita)")
	var header := "%-8s | %7s |" % ["POTENZA", "VP tot"]
	for s in sources: header += " %9s |" % s
	print(header)
	for p in powers:
		var n := float(N)
		var row := "%-8s | %7.1f |" % [p.to_upper(), total[p] / n]
		for s in sources:
			row += " %9.1f |" % (acc[p][s] / n)
		print(row)
	# Divario rispetto alla Russia, fonte per fonte (chi guadagna di più dove)
	print("\n--- Divario MEDIA(altre 3) - RUSSIA, per fonte (positivo = Russia perde lì) ---")
	for s in sources:
		var others := 0.0
		for p in powers:
			if p != "russia": others += float(acc[p][s]) / float(N)
		others /= 3.0
		var rus: float = float(acc["russia"][s]) / float(N)
		print("%-10s: altre %6.1f | russia %6.1f | divario %+6.1f" % [s, others, rus, others - rus])
	quit()
