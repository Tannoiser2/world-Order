class_name GameSetup
extends RefCounted
## Inizializza una nuova partita a partire dai dati (board.json, player_boards.json,
## carte). Implementa il setup del regolamento (pag. 8-9) per la parte modellabile.

## Crea un GameState per le potenze indicate (es. ["usa","china"]).
static func new_game(powers: Array) -> GameState:
	var gs := GameState.new()
	gs.player_count = powers.size()
	gs.board_data = DataLoader.load_board()
	var pboards := DataLoader.load_player_boards()
	var starting_abilities := DataLoader.load_starting_abilities()

	# Regioni: crea gli InfluenceTrack e piazza i cubi iniziali.
	for region in gs.board_data.get("regions", []):
		var rid: String = region["region"]
		var track := InfluenceTrack.new(region["permanent_slots"], region["temporary_slots"])
		for si in region.get("starting_influence", []):
			track.add(String(si["owner"]), String(si.get("slot", "permanent")))
		gs.regions[rid] = {
			"track": track,
			"armies": {},
			"engage_cost": int(region["engage_cost"]),
			"majority_bonus": region["majority_bonus"],
			"zone": region.get("zone_of_interest", []),
		}

	# Giocatori.
	var pdata := {}
	for entry in pboards.get("powers", []):
		pdata[entry["power"]] = entry
	for power in powers:
		var ps := PlayerState.new()
		ps.power = power
		var entry: Dictionary = pdata.get(power, {})
		# Produzione iniziale (solo valori numerici; i 'verify' restano a 0).
		for rtype in entry.get("starting_production", {}):
			var v: Variant = entry["starting_production"][rtype]
			ps.production[rtype] = int(v) if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else 0
		# Mazzo iniziale: 12 carte (semplificazione: le 9 distinte; i doppioni
		# andranno aggiunti quando definito il conteggio esatto per potenza).
		ps.deck = (starting_abilities.get(power, []) as Array).duplicate()
		gs.players.append(ps)

	# Ordine di turno iniziale (placeholder: ordine di inserimento).
	for i in gs.players.size():
		gs.turn_order.append(i)

	gs.round = 1
	gs.phase = WO.Phase.PREPARATION
	return gs
