extends SceneTree
## Simula N partite tutte-Bot (4 Automa) e stampa statistiche di bilanciamento.
## Uso: godot --headless --path game --script res://scripts/tests/_sim_bots.gd -- <N>

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
	GameConfig.fast_sim = true   # salta il lavoro UI: simulazione molto più veloce

	var wins := {}; var vp_sum := {}; var vp_min := {}; var vp_max := {}
	var money_sum := {}; var pros_sum := {}; var allied_sum := {}; var vp_all := {}
	for p in powers:
		wins[p] = 0.0; vp_sum[p] = 0; vp_min[p] = 999; vp_max[p] = -999
		money_sum[p] = 0; pros_sum[p] = 0; allied_sum[p] = 0; vp_all[p] = []
	var spread_sum := 0
	var rounds_sum := 0
	var done := 0

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
		# Raccogli i risultati finali
		var vps := {}
		for p in b.gs.players:
			vps[p.power] = p.victory_points
			vp_sum[p.power] += p.victory_points
			vp_min[p.power] = mini(vp_min[p.power], p.victory_points)
			vp_max[p.power] = maxi(vp_max[p.power], p.victory_points)
			money_sum[p.power] += p.money
			pros_sum[p.power] += p.prosperity_level
			allied_sum[p.power] += p.allied_countries.size()
			(vp_all[p.power] as Array).append(p.victory_points)
		var top: int = -999
		for pw in vps: top = maxi(top, int(vps[pw]))
		var low: int = 999
		for pw in vps: low = mini(low, int(vps[pw]))
		spread_sum += (top - low)
		var winners := []
		for pw in vps:
			if int(vps[pw]) == top: winners.append(pw)
		for pw in winners:
			wins[pw] += 1.0 / winners.size()   # pareggio = vittoria frazionaria
		rounds_sum += b.gs.round
		if b.game_over: done += 1
		b.queue_free()
		await process_frame

	# --- Report ---
	print("\n===== SIMULAZIONE BOT: %d partite (4 Automa, difficolta' normale) =====" % N)
	print("Partite concluse: %d/%d   |   round medio finale: %.1f   |   scarto medio 1°-4° (VP): %.1f" % [
		done, N, float(rounds_sum) / N, float(spread_sum) / N])
	print("%-8s | %6s | %5s | %7s | %7s | %7s | %7s | %7s" % ["POTENZA", "Vitt.", "Vitt%", "VP med", "VP min", "VP max", "money", "prosp"])
	for p in powers:
		var n := float(N)
		print("%-8s | %6.1f | %4.0f%% | %7.1f | %7d | %7d | %7.0f | %6.1f" % [
			p.to_upper(), wins[p], 100.0 * wins[p] / n, vp_sum[p] / n, vp_min[p], vp_max[p],
			money_sum[p] / n, pros_sum[p] / n])
	# Deviazione standard delle vittorie (0 = perfetto 25/25/25/25)
	var mean_w := float(N) / powers.size()
	var var_w := 0.0
	for p in powers: var_w += pow(wins[p] - mean_w, 2)
	print("Equilibrio vittorie: atteso %.1f a testa; scarto-tipo %.2f (più basso = più equilibrato)" % [mean_w, sqrt(var_w / powers.size())])
	quit()
