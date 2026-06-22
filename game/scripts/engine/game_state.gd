class_name GameState
extends RefCounted
## Stato di gioco completo e serializzabile (nessun nodo di scena).
## Contenitore: la logica vive in GameSetup, GamePhases, Scoring, ecc.

const TOTAL_ROUNDS := 6

var player_count: int = 2
var round: int = 1
var phase: int = WO.Phase.PREPARATION
var active_seat: int = 0
var turn_order: Array[int] = []          # indici dei giocatori nell'ordine del round

var players: Array = []                  # Array[PlayerState]
var regions: Dictionary = {}             # region_id -> { track: InfluenceTrack, armies: {power:int}, engage_cost, majority_bonus, zone:[...] }

## Riserva comune.
var supply: Dictionary = {"bases": 99, "fdi": 99}

## Market: 6 carte rivelate + mazzo.
var market: Array = []
var market_deck: Array = []

## Dati statici caricati.
var board_data: Dictionary = {}


func player_by_power(power: String) -> PlayerState:
	for p in players:
		if p.power == power:
			return p
	return null


func is_final_round() -> bool:
	return round >= TOTAL_ROUNDS


func is_scoring_round() -> bool:
	return round in board_data.get("global", {}).get("scoring_rounds", [3, 6])


func add_vp(power: String, amount: int) -> void:
	var p := player_by_power(power)
	if p:
		p.victory_points += amount


## --- Serializzazione (snapshot completo, per rete / salvataggio) -------------
## Cattura TUTTO lo stato dinamico. `board_data` (dati statici caricati da JSON) è
## incluso di default per un round-trip fedele; in rete si può escludere
## (include_static=false) perché ogni client lo ricarica da sé.
func to_dict(include_static := true) -> Dictionary:
	var pl := []
	for p in players:
		pl.append((p as PlayerState).to_dict())
	var reg := {}
	for rid in regions:
		var r: Dictionary = regions[rid]
		reg[rid] = {
			"track": (r["track"] as InfluenceTrack).to_dict(),
			"armies": (r.get("armies", {}) as Dictionary).duplicate(true),
			"engage_cost": r.get("engage_cost", 0),
			"majority_bonus": (r.get("majority_bonus", []) as Array).duplicate(true),
			"zone": (r.get("zone", []) as Array).duplicate(true),
		}
	var d := {
		"player_count": player_count,
		"round": round,
		"phase": phase,
		"active_seat": active_seat,
		"turn_order": turn_order.duplicate(),
		"players": pl,
		"regions": reg,
		"supply": supply.duplicate(true),
		"market": market.duplicate(true),
		"market_deck": market_deck.duplicate(true),
	}
	if include_static:
		d["board_data"] = board_data.duplicate(true)
	return d


static func from_dict(d: Dictionary, static_data: Dictionary = {}) -> GameState:
	var gs := GameState.new()
	gs.player_count = int(d.get("player_count", 2))
	gs.round = int(d.get("round", 1))
	gs.phase = int(d.get("phase", WO.Phase.PREPARATION))
	gs.active_seat = int(d.get("active_seat", 0))
	var to: Array[int] = []
	for v in d.get("turn_order", []):
		to.append(int(v))
	gs.turn_order = to
	gs.players = []
	for pd in d.get("players", []):
		gs.players.append(PlayerState.from_dict(pd))
	gs.regions = {}
	for rid in d.get("regions", {}):
		var r: Dictionary = d["regions"][rid]
		gs.regions[rid] = {
			"track": InfluenceTrack.from_dict(r.get("track", {})),
			"armies": (r.get("armies", {}) as Dictionary).duplicate(true),
			"engage_cost": r.get("engage_cost", 0),
			"majority_bonus": (r.get("majority_bonus", []) as Array).duplicate(true),
			"zone": (r.get("zone", []) as Array).duplicate(true),
		}
	gs.supply = (d.get("supply", {}) as Dictionary).duplicate(true)
	gs.market = (d.get("market", []) as Array).duplicate(true)
	gs.market_deck = (d.get("market_deck", []) as Array).duplicate(true)
	# board_data: dal dict se presente, altrimenti dai dati statici passati a parte.
	gs.board_data = (d.get("board_data", static_data) as Dictionary).duplicate(true)
	return gs


## Stato REDATTO per il giocatore al seggio `seat`: nasconde le informazioni
## segrete (mani avversarie, mazzi, asset strategici non rivelati). Le liste
## nascoste diventano solo un conteggio (campi *_count), così la UI può mostrare
## "N carte (coperte)" senza conoscerne il contenuto. È QUESTO ciò che l'arbitro
## (host) invia a ciascun client — mai lo stato completo.
func state_for_seat(seat: int, include_static := true) -> Dictionary:
	var d := to_dict(include_static)
	var plist: Array = d.get("players", [])
	for i in plist.size():
		var pd: Dictionary = plist[i]
		# Il MAZZO (ordine di pesca) è segreto per tutti, anche per sé: solo conteggio.
		pd["deck_count"] = (pd.get("deck", []) as Array).size()
		pd["deck"] = []
		# La MANO è sempre nota almeno come numero.
		pd["hand_count"] = (pd.get("hand", []) as Array).size()
		if i != seat:
			# Avversari: mano e asset strategici non rivelati restano coperti.
			pd["hand"] = []
			pd["strategic_assets_count"] = (pd.get("strategic_assets", []) as Array).size()
			pd["strategic_assets"] = []
	d["viewer_seat"] = seat
	return d
