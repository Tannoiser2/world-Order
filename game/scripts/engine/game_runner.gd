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
	return run_game_logged(powers, seed)["state"]


## Come run_game ma ritorna anche un log testuale ({"state":.., "log":[...]}).
static func run_game_logged(powers: Array, seed: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var gs := GameSetup.new_game(powers)
	var log: Array[String] = []
	log.append("Partita: %s (seed %d)" % [", ".join(powers), seed])

	for round_no in range(1, GameState.TOTAL_ROUNDS + 1):
		gs.round = round_no
		gs.phase = WO.Phase.PREPARATION
		GamePhases.determine_turn_order(gs)
		GamePhases.produce_primary_resources(gs)

		gs.phase = WO.Phase.ACTION
		for _turn in range(4):
			for seat in gs.turn_order:
				_simple_turn(gs, gs.players[seat], rng)

		gs.phase = WO.Phase.AFTERMATH
		if gs.is_scoring_round():
			var rs := score_all_regions(gs)
			for power in rs:
				gs.add_vp(power, int(rs[power]))
			# Abilità speciali applicate ad ogni Scoring step (USA penalità, Russia sfera).
			var sp := apply_power_special_scoring(gs)
			# I 3 token Maggioranza si segnano ad OGNI round di punteggio (3 e 6).
			var mt := score_majority_tokens(gs)
			for power in mt:
				gs.add_vp(power, int(mt[power]))
			log.append("— Scoring round %d — " % round_no + _vp_line(gs)
				+ ("  [speciali: %s]" % _fmt(sp) if not sp.is_empty() else "")
				+ "  [Maggioranza: %s]" % _fmt(mt))

	# Bonus di fine partita: China FDI, Strategic Asset/Executive Order non usati.
	var eb := apply_game_end_bonuses(gs)
	log.append("— Bonus fine partita — " + _fmt(eb))
	log.append("Classifica finale: " + _vp_line(gs))
	log.append("Vincitore: %s" % ", ".join(winners(gs)))
	return {"state": gs, "log": log}


static func _vp_line(gs: GameState) -> String:
	var parts := []
	for p in gs.players:
		parts.append("%s=%d" % [p.power, p.victory_points])
	return ", ".join(parts)


static func _fmt(d: Dictionary) -> String:
	var parts := []
	for k in d:
		parts.append("%s=%d" % [k, int(d[k])])
	return ", ".join(parts)


# --- Abilità speciali di fine partita / scoring step (regolamento pag. 20) ---

## Numero di Regioni in cui `power` ha la maggioranza di Influenza (più cubi, o pari)
## tra TUTTI gli owner sul tracciato (inclusi 'local'/neutrali). Conta solo le
## Regioni dove `power` ha almeno 1 cubo. (USA — Global Superpower Status.)
static func count_majority_influence_regions(gs: GameState, power: String) -> int:
	var n := 0
	for rid in gs.regions:
		var track: InfluenceTrack = gs.regions[rid]["track"]
		var pc := track.count(power)
		if pc <= 0:
			continue
		var maxc := 0
		for owner in track.owners():
			maxc = maxi(maxc, track.count(owner))
		if pc == maxc:
			n += 1
	return n


## Regioni della zona di interesse di `power` dove ha più Armate (o pari) con ≥1
## Armata. (Russia — Secured Sphere of Influence.)
static func count_zone_most_armies_regions(gs: GameState, power: String) -> int:
	var n := 0
	for rid in gs.regions:
		var rd: Dictionary = gs.regions[rid]
		if power not in rd.get("zone", []):
			continue
		var armies: Dictionary = rd.get("armies", {})
		var pa := int(armies.get(power, 0))
		if pa < 1:
			continue
		var maxa := 0
		for k in armies:
			maxa = maxi(maxa, int(armies[k]))
		if pa == maxa:
			n += 1
	return n


## Regioni distinte in cui `power` ha almeno 1 token FDI. (China — Global FDI Network.)
static func count_fdi_regions(gs: GameState, power: String) -> int:
	var p := gs.player_by_power(power)
	if p == null:
		return 0
	var regions := {}
	for c in p.allied_countries:
		if String(c.get("id", "")) in p.fdi_countries:
			regions[String(c.get("region", ""))] = true
	return regions.size()


## Abilità speciali applicate ad OGNI Scoring step (round 3 e 6): USA (penalità
## Global Superpower Status) e Russia (Secured Sphere). Ritorna i delta VP applicati.
static func apply_power_special_scoring(gs: GameState) -> Dictionary:
	var ssp: Dictionary = gs.board_data.get("global", {}).get("power_special_scoring", {})
	if ssp.is_empty():
		return {}
	var deltas := {}
	var usa := gs.player_by_power("usa")
	if usa:
		var nreg := count_majority_influence_regions(gs, "usa")
		var pen := Aftermath.global_superpower_status_penalty(nreg, ssp.get("global_superpower_status_penalty", {}))
		if pen != 0:
			usa.victory_points += pen
			deltas["usa"] = int(deltas.get("usa", 0)) + pen
	var rus := gs.player_by_power("russia")
	if rus:
		var nz := count_zone_most_armies_regions(gs, "russia")
		var vp := Aftermath.secured_sphere_vp(nz, int(ssp.get("secured_sphere_vp_per_region", 0)))
		if vp != 0:
			rus.victory_points += vp
			deltas["russia"] = int(deltas.get("russia", 0)) + vp
	return deltas


## Bonus assegnati una sola volta a fine partita: China (Global FDI Network),
## +2 VP per ogni Strategic Asset NON usato, +3 VP per Executive Order NON usata.
static func apply_game_end_bonuses(gs: GameState) -> Dictionary:
	var ssp: Dictionary = gs.board_data.get("global", {}).get("power_special_scoring", {})
	var deltas := {}
	var chn := gs.player_by_power("china")
	if chn and not ssp.is_empty():
		var nfdi := count_fdi_regions(gs, "china")
		var vp := Aftermath.global_fdi_network_vp(nfdi, ssp.get("global_fdi_network", {}))
		if vp != 0:
			chn.victory_points += vp
			deltas["china"] = int(deltas.get("china", 0)) + vp
	for p in gs.players:
		var unused_sa := 0
		for a in p.strategic_assets:
			if a not in p.used_strategic_assets:
				unused_sa += 1
		var b := unused_sa * 2                     # +2 VP per Strategic Asset non usato (pag. 21/FAQ)
		if not p.executive_order_used:
			b += 3                                 # +3 VP se l'Executive Order non è stata usata
		if b != 0:
			p.victory_points += b
			deltas[p.power] = int(deltas.get(p.power, 0)) + b
	return deltas


# --- Vincitore e spareggi (regolamento "GAME END", pag. 21) ---

## Regioni (che segnano) in cui un giocatore ha preso da solo il 1° bonus Maggioranza.
static func first_majority_region_counts(gs: GameState) -> Dictionary:
	var counts := {}
	for p in gs.players:
		counts[p.power] = 0
	for rid in gs.regions:
		var rd: Dictionary = gs.regions[rid]
		var track: InfluenceTrack = rd["track"]
		if not track.all_permanent_filled():
			continue
		var ranking := Scoring.region_ranking(track, rd["majority_bonus"], rd.get("armies", {}))
		if ranking.is_empty():
			continue
		# Il 1° bonus va solo a un leader UNICO: il suo bonus è majority_bonus[0].
		var top: Dictionary = ranking[0]
		var first_bonus: int = int(rd["majority_bonus"][0]) if (rd["majority_bonus"] as Array).size() > 0 else 0
		if int(top["bonus"]) == first_bonus and counts.has(top["owner"]):
			counts[top["owner"]] += 1
	return counts


## Cubi di Influenza totali sul tabellone per giocatore.
static func total_influence_cubes(gs: GameState) -> Dictionary:
	var counts := {}
	for p in gs.players:
		counts[p.power] = 0
	for rid in gs.regions:
		var track: InfluenceTrack = gs.regions[rid]["track"]
		for p in gs.players:
			counts[p.power] += track.count(p.power)
	return counts


static func _keep_max(tied: Array, metric: Dictionary) -> Array:
	var best := -999999
	for pw in tied:
		best = maxi(best, int(metric.get(pw, 0)))
	var out := []
	for pw in tied:
		if int(metric.get(pw, 0)) == best:
			out.append(pw)
	return out


## Vincitore/i con gli spareggi del regolamento: più VP → più Regioni col 1° bonus
## Maggioranza nel scoring finale → più cubi Influenza sul tabellone → vittoria condivisa.
static func winners(gs: GameState) -> Array:
	var max_vp := -999999
	for p in gs.players:
		max_vp = maxi(max_vp, p.victory_points)
	var tied := []
	for p in gs.players:
		if p.victory_points == max_vp:
			tied.append(p.power)
	if tied.size() <= 1:
		return tied
	tied = _keep_max(tied, first_majority_region_counts(gs))
	if tied.size() <= 1:
		return tied
	tied = _keep_max(tied, total_influence_cubes(gs))
	return tied


## Potenza vincente (il primo dei vincitori; in caso di vittoria condivisa, vedi winners()).
static func winner(gs: GameState) -> String:
	var w := winners(gs)
	return String(w[0]) if w.size() > 0 else ""


## Policy minimale per un turno: Engage in una Regione di zona se possibile,
## altrimenti Produce Diplomacy o passa (+10 money).
static func _simple_turn(gs: GameState, p: PlayerState, rng: RandomNumberGenerator) -> void:
	# prova un Engage dove ha gia' Influenza E una Country alleata (prerequisito,
	# pag. 13) se ha abbastanza Diplomacy
	var candidates := []
	for rid in gs.regions:
		if gs.regions[rid]["track"].count(p.power) > 0 and Actions.has_allied_country_in_region(p, rid):
			candidates.append(rid)
	if candidates.size() > 0 and p.resources.get("diplomacy", 0) >= 6:
		var rid: String = candidates[rng.randi() % candidates.size()]
		Actions.execute_engage(gs, p.power, rid, [], p.focus == WO.Focus.DIPLOMATIC, "temporary")
	elif p.production.get("diplomacy", 0) > 0 and p.resources.get("diplomacy", 0) < 6:
		Actions.execute_produce(p, "diplomacy")
	else:
		p.money += 10  # Pass
