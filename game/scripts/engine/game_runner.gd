class_name GameRunner
extends RefCounted
## Orchestrazione di una partita completa headless (integrazione del motore).
## La "policy" dei giocatori e' volutamente semplice: serve a esercitare il
## loop completo (fasi, azioni, aftermath, scoring finale, vincitore), non a
## giocare bene. Verra' sostituita da UI (input umano) e bot.

## Somma i VP da tutte le Regioni che segnano (permanenti pieni).
static func score_all_regions(gs: GameState) -> Dictionary:
	var totals := {}
	var players := []
	for p in gs.players:
		players.append(p.power)
		totals[p.power] = 0
	for rid in gs.regions:
		var r: Dictionary = gs.regions[rid]
		var res := Scoring.score_region(r["track"], r["majority_bonus"], r["armies"], players)
		for power in res:
			totals[power] = int(totals.get(power, 0)) + int(res[power])
	return totals


## Punteggio dei 3 token Maggioranza (denaro, armate sul board, paesi alleati).
static func score_majority_tokens(gs: GameState) -> Dictionary:
	var two_player := gs.players.size() == 2
	var bonus: Dictionary = gs.board_data["global"]["majority_token_bonus"]
	var money := {}
	var armies := {}
	var countries := {}
	for p in gs.players:
		money[p.power] = p.money
		countries[p.power] = p.allied_countries.size()
		armies[p.power] = 0
	for rid in gs.regions:
		for power in gs.regions[rid]["armies"]:
			if armies.has(power):
				armies[power] += int(gs.regions[rid]["armies"][power])
	var totals := {}
	for p in gs.players:
		totals[p.power] = 0
	for metric_bonus in [[money, bonus["most_money"]], [armies, bonus["most_armies_on_board"]], [countries, bonus["most_allied_countries"]]]:
		var res := Aftermath.score_majority(metric_bonus[0], metric_bonus[1], two_player)
		for power in res:
			totals[power] = int(totals.get(power, 0)) + int(res[power])
	return totals


## Esegue una partita completa con policy semplice. Ritorna il GameState finale.
static func run_game(powers: Array, seed: int = 1) -> GameState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var gs := GameSetup.new_game(powers)

	for round_no in range(1, GameState.TOTAL_ROUNDS + 1):
		gs.round = round_no
		gs.phase = WO.Phase.PREPARATION
		# Preparation (saltata nel round 1 nella sua interezza, ma produrre/ordine ok).
		GamePhases.determine_turn_order(gs)
		GamePhases.produce_primary_resources(gs)

		# Action Phase: 4 turni per giocatore (policy semplice).
		gs.phase = WO.Phase.ACTION
		for _turn in range(4):
			for seat in gs.turn_order:
				_simple_turn(gs, gs.players[seat], rng)

		# Aftermath.
		gs.phase = WO.Phase.AFTERMATH
		# scoring intermedio nei round 3 e 6
		if gs.is_scoring_round():
			var rs := score_all_regions(gs)
			for power in rs:
				gs.add_vp(power, int(rs[power]))

	# Game End: token Maggioranza + abilita' speciali semplificate.
	var mt := score_majority_tokens(gs)
	for power in mt:
		gs.add_vp(power, int(mt[power]))

	return gs


## Potenza con piu' VP (spareggio semplice: ordine di inserimento).
static func winner(gs: GameState) -> String:
	var best := ""
	var best_vp := -999999
	for p in gs.players:
		if p.victory_points > best_vp:
			best_vp = p.victory_points
			best = p.power
	return best


## Policy minimale per un turno: Engage in una Regione di zona se possibile,
## altrimenti Produce Diplomacy o passa (+10 money).
static func _simple_turn(gs: GameState, p: PlayerState, rng: RandomNumberGenerator) -> void:
	# prova un Engage dove ha gia' Influenza (zona) se ha abbastanza Diplomacy
	var candidates := []
	for rid in gs.regions:
		if gs.regions[rid]["track"].count(p.power) > 0:
			candidates.append(rid)
	if candidates.size() > 0 and p.resources.get("diplomacy", 0) >= 6:
		var rid: String = candidates[rng.randi() % candidates.size()]
		Actions.execute_engage(gs, p.power, rid, [], p.focus == WO.Focus.DIPLOMATIC, "temporary")
	elif p.production.get("diplomacy", 0) > 0 and p.resources.get("diplomacy", 0) < 6:
		Actions.execute_produce(p, "diplomacy")
	else:
		p.money += 10  # Pass
