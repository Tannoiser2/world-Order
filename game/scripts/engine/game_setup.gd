class_name GameSetup
extends RefCounted
## Inizializza una nuova partita a partire dai dati (board.json, player_boards.json,
## carte). Implementa il setup del regolamento (pag. 8-9) per la parte modellabile.

## Nazioni amiche iniziali per potenza (estratte dal salvataggio TTS).
const STARTING_ALLIES := {
	"usa": ["Iceland", "Japan", "Iraq", "Mexico"],
	"eu": ["Jordan", "EU Member States", "Nigeria", "Norway", "Canada"],
	"russia": ["Belarus", "Syria", "Armenia", "India"],
	"china": ["South Africa", "Pakistan", "Tajikistan", "Laos"],
}

## Crea un GameState per le potenze indicate (es. ["usa","china"]).
static func new_game(powers: Array) -> GameState:
	var gs := GameState.new()
	gs.player_count = powers.size()
	gs.board_data = DataLoader.load_board()
	var pboards := DataLoader.load_player_boards()
	var starting_abilities := DataLoader.load_starting_abilities()
	# Strategic Asset per potenza (5 ciascuna).
	var strategic_by_power := {}
	for sa in DataLoader.load_strategic_assets():
		var pw := String(sa.get("power", ""))
		if not strategic_by_power.has(pw):
			strategic_by_power[pw] = []
		strategic_by_power[pw].append(sa)

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

	# Indice nazioni per nome (per gli alleati iniziali).
	var by_name := {}
	for c in DataLoader.load_countries():
		by_name[String(c.get("display_name", ""))] = c

	# Giocatori.
	var pdata := {}
	for entry in pboards.get("powers", []):
		pdata[entry["power"]] = entry
	for power in powers:
		var ps := PlayerState.new()
		ps.power = power
		var entry: Dictionary = pdata.get(power, {})
		# Produzione iniziale dalle plance.
		for rtype in entry.get("starting_production", {}):
			var v: Variant = entry["starting_production"][rtype]
			ps.production[rtype] = int(v) if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else 1
		# Risorse iniziali = una produzione di setup (stessa quantità della
		# produzione, escluse le Armate che sono un tracciato a parte).
		for rtype in ["energy", "raw_materials", "food", "consumer_goods", "services", "diplomacy"]:
			ps.resources[rtype] = int(ps.production.get(rtype, 0))
		# Nazioni amiche iniziali (carte Country davanti al giocatore).
		for cname in STARTING_ALLIES.get(power, []):
			if by_name.has(cname):
				ps.allied_countries.append((by_name[cname] as Dictionary).duplicate())
		# Strategic Asset (regolamento pag. 9): pesca 3 dei 5, ne tiene 2; i VP
		# iniziali sono la somma degli "starting_vp" dei 2 tenuti. (Auto: tiene i 2
		# con più VP; la scelta manuale arriverà col flusso interattivo.)
		var sa_all: Array = (strategic_by_power.get(power, []) as Array).duplicate()
		sa_all.shuffle()
		var drawn := sa_all.slice(0, 3)
		drawn.sort_custom(func(a, b): return int(a.get("starting_vp", 0)) > int(b.get("starting_vp", 0)))
		for c in drawn.slice(0, 2):
			ps.strategic_assets.append(c)
			ps.victory_points += int(c.get("starting_vp", 0))
		# Mazzo iniziale completo (12 carte, doppioni inclusi).
		ps.deck = (starting_abilities.get(power, []) as Array).duplicate()
		gs.players.append(ps)

	# Ordine di turno iniziale (placeholder: ordine di inserimento).
	for i in gs.players.size():
		gs.turn_order.append(i)

	gs.round = 1
	gs.phase = WO.Phase.PREPARATION
	return gs
