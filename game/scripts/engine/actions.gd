class_name Actions
extends RefCounted
## Le 8 azioni della fase di Azione (regolamento pag. 12-15).
## I calcoli di costo sono funzioni pure (testabili); le funzioni execute_*
## applicano gli effetti al GameState. owner = colore potenza (es. "usa").

# Tabella Trade (regolamento pag. 13).
const EXPORT_GAIN := {
	"energy": 5, "raw_materials": 5, "food": 5,
	"consumer_goods": 15, "services": 15, "diplomacy": 20,
}
const IMPORT_COST := {
	"energy": 3, "raw_materials": 3, "food": 3,
	"consumer_goods": 10, "services": 10,
}
const MOVE_COST := 5
const BASE_COST := 5

# Requisiti di produzione delle risorse secondarie (cosa spendi per produrne 1).
const SECONDARY_REQ := {
	"consumer_goods": {"energy": 1, "raw_materials": 1},
	"services": {"food": 1, "raw_materials": 1},
	"diplomacy": {"food": 1},
	"armies": {"raw_materials": 1},
}

# ---------------------------------------------------------------------------
# IMPROVE RELATIONS (Diplomatic)
# ---------------------------------------------------------------------------

## Costo in Diplomacy: valore del Paese meno la somma dei valori degli alleati
## della stessa Regione che si exhaustano (minimo 0).
static func improve_relations_cost(country_value: int, exhausted_values: Array) -> int:
	var discount := 0
	for v in exhausted_values:
		discount += int(v)
	return maxi(0, country_value - discount)


static func execute_improve_relations(gs: GameState, owner: String, country: Dictionary,
		exhausted_values: Array = []) -> bool:
	var p := gs.player_by_power(owner)
	if p == null:
		return false
	var cost := improve_relations_cost(int(country.get("value", 0)), exhausted_values)
	if not p.spend({"diplomacy": cost}):
		return false
	p.allied_countries.append(country)
	p.exhausted[country.get("id", "")] = false
	return true

# ---------------------------------------------------------------------------
# ENGAGE (Diplomatic)
# ---------------------------------------------------------------------------

static func engage_cost(base_cost: int, exhausted_values: Array, diplomatic_focus: bool) -> int:
	var discount := 0
	for v in exhausted_values:
		discount += int(v)
	if diplomatic_focus:
		discount += 2  # ongoing: Engage costa 2 Diplomacy in meno
	return maxi(0, base_cost - discount)


## Ritorna i VP immediati guadagnati (dallo slot Influenza), o -1 se fallisce.
static func execute_engage(gs: GameState, owner: String, region: String,
		exhausted_values: Array = [], diplomatic_focus: bool = false,
		slot_type: String = "") -> int:
	var p := gs.player_by_power(owner)
	if p == null or not gs.regions.has(region):
		return -1
	var cost := engage_cost(int(gs.regions[region]["engage_cost"]), exhausted_values, diplomatic_focus)
	if not p.spend({"diplomacy": cost}):
		return -1
	var vp: int = gs.regions[region]["track"].add(owner, slot_type)
	p.victory_points += vp
	return vp

# ---------------------------------------------------------------------------
# TRADE (Economic)
# ---------------------------------------------------------------------------

## Guadagno totale dall'Export di una lista di {type, qty}.
static func export_gain(transactions: Array) -> int:
	var total := 0
	for t in transactions:
		total += int(EXPORT_GAIN.get(t["type"], 0)) * int(t["qty"])
	return total


## Costo totale dell'Import di una lista di {type, qty}.
static func import_cost(transactions: Array) -> int:
	var total := 0
	for t in transactions:
		total += int(IMPORT_COST.get(t["type"], 0)) * int(t["qty"])
	return total

# ---------------------------------------------------------------------------
# INVEST (Economic)
# ---------------------------------------------------------------------------

static func execute_invest(gs: GameState, owner: String, country: Dictionary,
		slot_type: String = "") -> int:
	var p := gs.player_by_power(owner)
	if p == null:
		return -1
	var cid: String = country.get("id", "")
	if p.exhausted.get(cid, false):
		return -1  # deve essere ready
	if not p.spend({"money": int(country.get("invest_cost", 0))}):
		return -1
	p.exhausted[cid] = true
	if gs.supply.get("fdi", 0) > 0:
		gs.supply["fdi"] -= 1
	var region: String = country.get("region", "")
	var vp := 0
	if gs.regions.has(region):
		vp = gs.regions[region]["track"].add(owner, slot_type)
		p.victory_points += vp
	return vp

# ---------------------------------------------------------------------------
# MOVE (Military)
# ---------------------------------------------------------------------------

static func move_cost(num_armies: int) -> int:
	return MOVE_COST * num_armies


static func execute_move(gs: GameState, owner: String, moves: Array) -> bool:
	# moves: Array di { region } (destinazione di 1 Armata ciascuno).
	var p := gs.player_by_power(owner)
	if p == null:
		return false
	var n := moves.size()
	if p.armies_available < n:
		return false
	if not p.spend({"money": move_cost(n)}):
		return false
	p.armies_available -= n
	for m in moves:
		var region: String = m["region"]
		if gs.regions.has(region):
			var a: Dictionary = gs.regions[region]["armies"]
			a[owner] = int(a.get(owner, 0)) + 1
	return true

# ---------------------------------------------------------------------------
# BUILD A BASE (Military)
# ---------------------------------------------------------------------------

static func build_base_cost(num_armies_moved: int) -> int:
	return BASE_COST + MOVE_COST * num_armies_moved


static func execute_build_base(gs: GameState, owner: String, country: Dictionary,
		armies_to_move: int, slot_type: String = "") -> int:
	var p := gs.player_by_power(owner)
	if p == null:
		return -1
	var cid: String = country.get("id", "")
	if p.exhausted.get(cid, false):
		return -1
	if not bool(country.get("has_base_symbol", false)):
		return -1
	if owner not in country.get("base_allowed_powers", []):
		return -1
	var max_move: int = maxi(1, int(country.get("value", 1)))
	armies_to_move = clampi(armies_to_move, 0, mini(max_move, p.armies_available))
	if not p.spend({"money": build_base_cost(armies_to_move)}):
		return -1
	p.exhausted[cid] = true
	if gs.supply.get("bases", 0) > 0:
		gs.supply["bases"] -= 1
	var region: String = country.get("region", "")
	p.armies_available -= armies_to_move
	var vp := 0
	if gs.regions.has(region):
		var a: Dictionary = gs.regions[region]["armies"]
		a[owner] = int(a.get(owner, 0)) + armies_to_move
		vp = gs.regions[region]["track"].add(owner, slot_type)
		p.victory_points += vp
	return vp

# ---------------------------------------------------------------------------
# GET A GROWTH CARD (Domestic)
# ---------------------------------------------------------------------------

## next_level: il livello che il giocatore deve prendere (1 la prima volta, poi +1).
static func execute_get_growth(p: PlayerState, growth_card: Dictionary, next_level: int) -> bool:
	if int(growth_card.get("level", 0)) != next_level:
		return false
	if not p.spend(growth_card.get("cost", {})):
		return false
	p.growth_cards.append(growth_card)
	p.victory_points += int(growth_card.get("victory_points", 0))
	return true

# ---------------------------------------------------------------------------
# PRODUCE (Domestic)
# ---------------------------------------------------------------------------

const PRIMARY := ["energy", "raw_materials", "food"]

## Produce un tipo di risorsa. Per le primarie gain = Produzione; per le
## secondarie fino alla Produzione, spendendo i requisiti per ciascuna unita'.
## Ritorna la quantita' effettivamente prodotta.
static func execute_produce(p: PlayerState, rtype: String, desired: int = -1) -> int:
	var prod: int = int(p.production.get(rtype, 0))
	if rtype in PRIMARY:
		var amount := prod if desired < 0 else mini(desired, prod)
		p.gain_resource(rtype, amount, 3)
		return amount
	# secondaria: paga i requisiti per ogni unita'
	var req: Dictionary = SECONDARY_REQ.get(rtype, {})
	var target := prod if desired < 0 else mini(desired, prod)
	var made := 0
	for _i in target:
		if not p.has_resources(req):
			break
		p.spend(req)
		p.gain_resource(rtype, 1, 10)
		made += 1
	return made
