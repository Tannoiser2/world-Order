class_name GamePhases
extends RefCounted
## Macchina a stati delle fasi e dei round (regolamento "How to Play").
## Le azioni dei giocatori sono delegate (vedi Fase 1 successiva); qui c'e' la
## struttura del round e i passi deterministici.

const PRIMARY := ["energy", "raw_materials", "food"]
const IMPORT_COST_PRIMARY := 3
const IMPORT_COST_SECONDARY := 10


## Produce le 3 risorse primarie per un giocatore.
static func produce_primary_resources_for(p: PlayerState) -> void:
	for rtype in PRIMARY:
		var amount: int = int(p.production.get(rtype, 0))
		p.gain_resource(rtype, amount, IMPORT_COST_PRIMARY)


## Produce le 3 risorse primarie per tutti i giocatori (Preparation Phase).
static func produce_primary_resources(gs: GameState) -> void:
	for p in gs.players:
		produce_primary_resources_for(p)


## Ordine di turno: chi ha meno VP sceglie per primo dove posizionarsi.
## Modello di default: ordina i posti per VP crescente (spareggio: meno money).
static func determine_turn_order(gs: GameState) -> void:
	var seats := range(gs.players.size())
	var sorted_seats := Array(seats)
	sorted_seats.sort_custom(func(a, b):
		var pa: PlayerState = gs.players[a]
		var pb: PlayerState = gs.players[b]
		if pa.victory_points != pb.victory_points:
			return pa.victory_points < pb.victory_points
		return pa.money < pb.money)
	gs.turn_order.clear()
	for s in sorted_seats:
		gs.turn_order.append(int(s))


## Avanza la macchina a stati. Ritorna una stringa con la nuova fase/round.
static func advance_phase(gs: GameState) -> String:
	match gs.phase:
		WO.Phase.PREPARATION:
			gs.phase = WO.Phase.ACTION
			gs.active_seat = 0
		WO.Phase.ACTION:
			gs.phase = WO.Phase.AFTERMATH
		WO.Phase.AFTERMATH:
			if gs.is_final_round():
				return "GAME_END"
			gs.round += 1
			gs.phase = WO.Phase.PREPARATION
			# Preparation Phase del nuovo round (saltata al round 1).
			determine_turn_order(gs)
			produce_primary_resources(gs)
	return "round %d / %s" % [gs.round, WO.Phase.keys()[gs.phase]]


## Increase Prosperity (Aftermath): spende Consumer Goods e avanza di 1 spazio.
## prosperity_steps: Array di {cost_consumer_goods, vp, money}.
static func increase_prosperity(p: PlayerState, prosperity_steps: Array) -> bool:
	if p.prosperity_level >= prosperity_steps.size():
		return false
	var step: Dictionary = prosperity_steps[p.prosperity_level]
	var cost: int = int(step.get("cost_consumer_goods", 999))
	if p.resources.get("consumer_goods", 0) < cost:
		return false
	p.resources["consumer_goods"] -= cost
	p.prosperity_level += 1
	p.victory_points += int(step.get("vp", 0))
	p.money += int(step.get("money", 0))
	return true
