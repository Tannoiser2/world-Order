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
## Ordine di turno (regolamento pag. 9): chi ha PIÙ VP gioca per primo; a parità
## di VP gioca prima chi ha meno money.
static func determine_turn_order(gs: GameState) -> void:
	var seats := range(gs.players.size())
	var sorted_seats := Array(seats)
	sorted_seats.sort_custom(func(a, b):
		var pa: PlayerState = gs.players[a]
		var pb: PlayerState = gs.players[b]
		if pa.victory_points != pb.victory_points:
			return pa.victory_points > pb.victory_points
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


## Research step (regolamento pag. 17): rivela le carte rimaste in mano,
## guadagna i top bonus, somma il Research; +2 se Domestic Focus.
## Ritorna i punti Research disponibili per comprare dal Market.
static func research_step(p: PlayerState, revealed_cards: Array, domestic_focus: bool) -> int:
	var research := 0
	for card in revealed_cards:
		research += int(card.get("research_bonus", 0))
		var tb: Dictionary = card.get("top_bonus", {})
		match String(tb.get("kind", "")):
			"money": p.money += int(tb.get("amount", 0))
			"diplomacy": p.gain_resource("diplomacy", int(tb.get("amount", 0)))
			"army": p.armies_available += int(tb.get("amount", 0))
	if domestic_focus:
		research += 2
	return research


## Compra una carta dal Market spendendo Research (eventualmente +Research da
## Country alleati exhaustati). Ritorna il Research speso, o -1 se non basta.
static func buy_market_card(p: PlayerState, card: Dictionary, available_research: int,
		extra_from_countries: int = 0) -> int:
	var cost := int(card.get("market_cost", 0))
	if available_research + extra_from_countries < cost:
		return -1
	p.deck.push_back(card)  # la nuova carta va in cima al mazzo
	return cost


## Add Auto-Influence (regolamento pag. 18, solo 2-3 giocatori): applica UNA
## carta Auto-Influence. Per ogni potenza NON controllata da un giocatore,
## aggiunge Influenza (slot permanente se disponibile, altrimenti temporaneo)
## e un'Armata se indicato. Ritorna la lista dei giocatori indicati da una
## bandiera 'trade_with': il loro "commercio" (girare una Commerce card a faccia
## in su per +10 money) è gestito dal chiamante, perché dipende dallo stato delle
## Commerce card (che vive nella UI).
static func add_auto_influence(gs: GameState, ai_card: Dictionary, player_powers: Array) -> Array:
	var rows: Dictionary = ai_card.get("rows", {})
	var trade_players := []
	for power in rows:
		var row: Dictionary = rows[power]
		if power not in player_powers:
			var region: String = row.get("region", "")
			if gs.regions.has(region):
				var track: InfluenceTrack = gs.regions[region]["track"]
				var slot := "permanent" if not track.all_permanent_filled() else "temporary"
				track.add(power, slot)
				if bool(row.get("army", false)):
					var a: Dictionary = gs.regions[region]["armies"]
					a[power] = int(a.get(power, 0)) + 1
		var tw: Variant = row.get("trade_with", null)
		if tw != null and String(tw) in player_powers:
			trade_players.append(String(tw))
	return trade_players


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
