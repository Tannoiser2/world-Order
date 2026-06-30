class_name Objectives
extends RefCounted
## Valutazione degli Obiettivi Superpotenze (espansione Diplomacy & Dominance).
## Ogni Obiettivo ha 3 condizioni (soglie round 3 | round 6) e una RICOMPENSA a 3 livelli:
## soddisfi 1/2/3 condizioni -> reward[0/1/2] VP. Si calcola nei round di Scoring (3 e 6).
##
## `ri` (round index) = 0 per il round 3, 1 per il round 6 (sceglie la soglia in cond.min).

const PRIMARY := ["energy", "raw_materials", "food"]
const SECONDARY := ["consumer_goods", "services"]
const PRODUCTION_KEYS := ["energy", "raw_materials", "food", "consumer_goods", "services", "diplomacy", "armies"]


## VP dell'Obiettivo per `power` nel round dato: conta le condizioni soddisfatte e ritorna
## reward[n-1] (0 se nessuna).
static func objective_score(gs: GameState, power: String, obj: Dictionary, ri: int) -> int:
	var met := 0
	for cond in obj.get("conditions", []):
		if condition_met(gs, power, cond, ri):
			met += 1
	if met <= 0:
		return 0
	var reward: Array = obj.get("reward", [])
	var idx: int = mini(met, reward.size()) - 1
	return int(reward[idx]) if idx >= 0 else 0


# --- Accessori ---------------------------------------------------------------

static func _thr(cond: Dictionary, ri: int) -> int:
	var m: Array = cond.get("min", [])
	if m.is_empty():
		return 0
	return int(m[clampi(ri, 0, m.size() - 1)])


static func _inf(gs: GameState, power: String, region: String) -> int:
	if not gs.regions.has(region):
		return 0
	var tr: InfluenceTrack = gs.regions[region].get("track")
	return tr.count(power) if tr != null else 0


static func _armies(gs: GameState, power: String, region: String) -> int:
	if not gs.regions.has(region):
		return 0
	return int((gs.regions[region].get("armies", {}) as Dictionary).get(power, 0))


static func _others(gs: GameState, power: String) -> Array:
	var out := []
	for p in gs.players:
		if p.power != power:
			out.append(p.power)
	return out


## Country alleate di `power` in una Regione.
static func _allied_in_region(p: PlayerState, region: String) -> int:
	var n := 0
	for c in p.allied_countries:
		if String((c as Dictionary).get("region", "")) == region:
			n += 1
	return n


## FDI di `power` in una Regione (Country alleate con un suo segnalino IDE).
static func _fdi_in_region(p: PlayerState, region: String) -> int:
	var n := 0
	for c in p.allied_countries:
		var cid := String((c as Dictionary).get("id", ""))
		if cid in p.fdi_countries and String(c.get("region", "")) == region:
			n += 1
	return n


# --- Valutazione di una singola condizione -----------------------------------

static func condition_met(gs: GameState, power: String, cond: Dictionary, ri: int) -> bool:
	var p := gs.player_by_power(power)
	if p == null:
		return false
	var t := String(cond.get("t", ""))
	var thr := _thr(cond, ri)
	var others := _others(gs, power)
	match t:
		# --- Risorse / economia ---
		"resource":
			return int(p.resources.get(String(cond.get("res", "")), 0)) >= thr
		"money":
			return p.money >= thr
		"money_most":
			for o in others:
				if gs.player_by_power(o) != null and gs.player_by_power(o).money >= p.money:
					return false
			return true
		"growth_cards":
			return p.growth_cards.size() >= thr
		"deck_size":
			return p.deck.size() >= thr
		"prosperity_times":
			return p.prosperity_level >= thr
		"fdi_count":
			return p.fdi_countries.size() >= thr
		"engage_markers":
			return p.engage_tokens.size() >= thr

		# --- Produzione (rispetto al baseline iniziale) ---
		"production_increase":
			var res := String(cond.get("res", ""))
			return int(p.production.get(res, 0)) - int(p.initial_production.get(res, 0)) >= thr
		"production_increase_any":
			for res in cond.get("res", []):
				if int(p.production.get(String(res), 0)) - int(p.initial_production.get(String(res), 0)) >= maxi(1, thr):
					return true
			return false
		"production_increases_count":
			var keys: Array = SECONDARY if bool(cond.get("secondary", false)) else PRODUCTION_KEYS
			var inc := 0
			for k in keys:
				if int(p.production.get(String(k), 0)) > int(p.initial_production.get(String(k), 0)):
					inc += 1
			return inc >= thr

		# --- Influenza ---
		"influence_region":
			return _inf(gs, power, String(cond.get("region", ""))) >= thr
		"influence_total":
			var s := 0
			for r in cond.get("regions", []):
				s += _inf(gs, power, String(r))
			return s >= thr
		"influence_board_total":
			var sb := 0
			for r in gs.regions:
				sb += _inf(gs, power, r)
			return sb >= thr
		"influence_highest":
			return _is_highest(gs, power, String(cond.get("region", "")), bool(cond.get("strict", false)), others, true)
		"influence_more_than":
			var reg := String(cond.get("region", ""))
			return _inf(gs, power, reg) > _inf(gs, String(cond.get("power", "")), reg)
		"influence_more_than_any_of":
			var reg2 := String(cond.get("region", ""))
			for tp in cond.get("powers", []):
				if _inf(gs, power, reg2) > _inf(gs, String(tp), reg2):
					return true
			return false
		"influence_more_than_combined":
			var reg3 := String(cond.get("region", ""))
			var sum_others := 0
			for o in others:
				sum_others += _inf(gs, o, reg3)
			return _inf(gs, power, reg3) > sum_others
		"influence_highest_in_n_regions":
			var c := 0
			for r in gs.regions:
				if _is_highest(gs, power, r, false, others, true):
					c += 1
			return c >= thr
		"influence_most_board":
			var mine := 0
			for r in gs.regions:
				mine += _inf(gs, power, r)
			if mine <= 0:
				return false
			for o in others:
				var ot := 0
				for r in gs.regions:
					ot += _inf(gs, o, r)
				if ot >= mine:
					return false
			return true
		"regions_with_influence":
			var per := int(cond.get("per", 1))
			var rc := 0
			for r in gs.regions:
				if _inf(gs, power, r) >= per:
					rc += 1
			return rc >= thr

		# --- Armate ---
		"armies_region":
			return _armies(gs, power, String(cond.get("region", ""))) >= thr
		"armies_total":
			var a := 0
			for r in cond.get("regions", []):
				a += _armies(gs, power, String(r))
			return a >= thr
		"regions_with_armies":
			var perA := int(cond.get("per", 1))
			var ac := 0
			for r in gs.regions:
				if _armies(gs, power, r) >= perA:
					ac += 1
			return ac >= thr
		"armies_most":
			var minea := 0
			for r in gs.regions:
				minea += _armies(gs, power, r)
			if minea <= 0:
				return false
			for o in others:
				var oa := 0
				for r in gs.regions:
					oa += _armies(gs, o, r)
				if oa >= minea:
					return false
			return true
		"armies_more_than":
			var regm := String(cond.get("region", ""))
			return _armies(gs, power, regm) > _armies(gs, String(cond.get("power", "")), regm)
		"armies_most_in_n_regions":
			var cnt := 0
			for r in gs.regions:
				if _strictly_most_armies(gs, power, r, others):
					cnt += 1
			return cnt >= thr

		# --- Nazioni Alleate ---
		"allied_total":
			return p.allied_countries.size() >= thr
		"allied_region":
			return _allied_in_region(p, String(cond.get("region", ""))) >= thr
		"regions_with_allied":
			var perAl := int(cond.get("per", 1))
			var alc := 0
			for r in gs.regions:
				if _allied_in_region(p, r) >= perAl:
					alc += 1
			return alc >= thr
		"allied_most":
			for o in others:
				var op := gs.player_by_power(o)
				if op != null and op.allied_countries.size() >= p.allied_countries.size():
					return false
			return true
		"allied_more_than":
			var regAl := String(cond.get("region", ""))
			var op2 := gs.player_by_power(String(cond.get("power", "")))
			var theirs := _allied_in_region(op2, regAl) if op2 != null else 0
			return _allied_in_region(p, regAl) > theirs

		# --- FDI ---
		"fdi_in_region":
			return _fdi_in_region(p, String(cond.get("region", ""))) >= thr
		"fdi_most_in_n_regions":
			var fc := 0
			for r in gs.regions:
				if _strictly_most_fdi(gs, power, r, others):
					fc += 1
			return fc >= thr
		"fdi_export_to":
			var resf: Array = cond.get("res", [])
			var nf := 0
			for c in p.allied_countries:
				var cid := String((c as Dictionary).get("id", ""))
				if cid in p.fdi_countries and _has_any(c.get("exports", []), resf):
					nf += 1
			return nf >= thr
		"fdi_income_one_step":
			return false   # richiede tracciamento del Ritorno sugli investimenti (futuro)

		# --- Simboli Export/Import sulle Nazioni Alleate ---
		"export_symbols_total":
			var et := 0
			for c in p.allied_countries:
				et += (c.get("exports", []) as Array).size()
			return et >= thr
		"export_symbols_distinct":
			var seen := {}
			for c in p.allied_countries:
				for s in c.get("exports", []):
					seen[String(s)] = true
			return seen.size() >= thr
		"allied_export_to":
			var rese: Array = cond.get("res", [])
			var ne := 0
			for c in p.allied_countries:
				if _has_any(c.get("exports", []), rese):
					ne += 1
			return ne >= thr
		"allied_import_from":
			var resi: Array = cond.get("res", [])
			var ni := 0
			for c in p.allied_countries:
				if _has_any(c.get("imports", []), resi):
					ni += 1
			return ni >= thr
		_:
			return false


## True se `power` ha l'Influenza più alta nella Regione. `strict` = strettamente più di ogni
## altro; altrimenti >= (pareggio in testa ammesso). `need_positive` = serve almeno 1 cubetto.
static func _is_highest(gs: GameState, power: String, region: String, strict: bool, others: Array, need_positive: bool) -> bool:
	var mine := _inf(gs, power, region)
	if need_positive and mine <= 0:
		return false
	for o in others:
		var ot := _inf(gs, o, region)
		if strict:
			if ot >= mine:
				return false
		elif ot > mine:
			return false
	return true


static func _strictly_most_armies(gs: GameState, power: String, region: String, others: Array) -> bool:
	var mine := _armies(gs, power, region)
	if mine <= 0:
		return false
	for o in others:
		if _armies(gs, o, region) >= mine:
			return false
	return true


static func _strictly_most_fdi(gs: GameState, power: String, region: String, others: Array) -> bool:
	var mine := _fdi_in_region(gs.player_by_power(power), region)
	if mine <= 0:
		return false
	for o in others:
		var op := gs.player_by_power(o)
		if op != null and _fdi_in_region(op, region) >= mine:
			return false
	return true


static func _has_any(symbols: Array, wanted: Array) -> bool:
	for s in symbols:
		if String(s) in wanted:
			return true
	return false
