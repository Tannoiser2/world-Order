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
