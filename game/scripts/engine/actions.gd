class_name Actions
extends RefCounted
## Le 8 azioni della fase di Azione (regolamento pag. 12-15).
## I calcoli di costo sono funzioni pure (testabili); le funzioni execute_*
## applicano gli effetti al GameState. owner = colore potenza (es. "usa").

# Tabella Trade (regolamento pag. 13). Il bene di valore 20 è ARMATE (vendibili
# solo dalla riserva sulla plancia, mai dal tabellone) e NON è importabile; la
# Diplomazia non è commerciabile (non compare nella tabella).
const EXPORT_GAIN := {
	"energy": 5, "raw_materials": 5, "food": 5,
	"consumer_goods": 15, "services": 15, "armies": 20,
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
static func improve_relations_cost(country_value: int, exhausted_values: Array,
		extra_discount: int = 0) -> int:
	var discount := extra_discount
	for v in exhausted_values:
		discount += int(v)
	return maxi(0, country_value - discount)


static func execute_improve_relations(gs: GameState, owner: String, country: Dictionary,
		exhausted_values: Array = [], extra_discount: int = 0) -> bool:
	var p := gs.player_by_power(owner)
	if p == null:
		return false
	# Restrizione del regolamento (pag. 12): alcune potenze non possono allearsi
	# con certi Paesi (es. USA con l'Iran).
	if owner in country.get("no_relations_powers", []):
		return false
	var cost := improve_relations_cost(int(country.get("value", 0)), exhausted_values, extra_discount)
	if not p.spend({"diplomacy": cost}):
		return false
	p.allied_countries.append(country)
	p.exhausted[country.get("id", "")] = false
	return true

# ---------------------------------------------------------------------------
# ENGAGE (Diplomatic)
# ---------------------------------------------------------------------------

static func engage_cost(base_cost: int, exhausted_values: Array, diplomatic_focus: bool,
		extra_discount: int = 0) -> int:
	var discount := extra_discount
	for v in exhausted_values:
		discount += int(v)
	if diplomatic_focus:
		discount += 2  # ongoing: Engage costa 2 Diplomacy in meno
	return maxi(0, base_cost - discount)


## True se il giocatore ha almeno una Country alleata nella Regione indicata.
static func has_allied_country_in_region(p: PlayerState, region: String) -> bool:
	for c in p.allied_countries:
		if String(c.get("region", "")) == region:
			return true
	return false


## Ritorna i VP immediati guadagnati (dallo slot Influenza), o -1 se fallisce.
static func execute_engage(gs: GameState, owner: String, region: String,
		exhausted_values: Array = [], diplomatic_focus: bool = false,
		slot_type: String = "", extra_discount: int = 0) -> int:
	var p := gs.player_by_power(owner)
	if p == null or not gs.regions.has(region):
		return -1
	# Prerequisito (regolamento pag. 13): si può Engage solo in una Regione dove si
	# ha almeno 1 Country alleata.
	if not has_allied_country_in_region(p, region):
		return -1
	var cost := engage_cost(int(gs.regions[region]["engage_cost"]), exhausted_values, diplomatic_focus, extra_discount)
	if not p.spend({"diplomacy": cost}):
		return -1
	var vp: int = gs.regions[region]["track"].add(owner, slot_type)
	p.victory_points += vp
	# Piazza un Engage token sulla Regione (max 3 disponibili: se pieni, ne sposti
	# uno già sul tabellone -> rimuovi il più vecchio).
	if region not in p.engage_tokens:
		if p.engage_tokens.size() >= 3:
			p.engage_tokens.pop_front()
		p.engage_tokens.append(region)
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
	if cid != "" and cid in p.fdi_countries:
		return -1  # regolamento pag. 14: si può Investire una sola volta per Country
	if not p.spend({"money": int(country.get("invest_cost", 0))}):
		return -1
	p.exhausted[cid] = true
	if gs.supply.get("fdi", 0) > 0:
		gs.supply["fdi"] -= 1
	p.fdi_values.append(int(country.get("value", 0)))   # token FDI per Return on Investments
	if cid != "" and cid not in p.fdi_countries:
		p.fdi_countries.append(cid)                     # token FDI sul Paese (rendering)
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


## Destinazione valida per un Move (regolamento pag. 14): una Regione della propria
## zona di interesse (bandiera della potenza), oppure dove si ha una Base militare.
static func move_dest_valid(gs: GameState, p: PlayerState, region: String) -> bool:
	if not gs.regions.has(region):
		return false
	if p.power in gs.regions[region].get("zone", []):
		return true
	for c in p.allied_countries:
		if String(c.get("id", "")) in p.bases and String(c.get("region", "")) == region:
			return true
	return false


static func execute_move(gs: GameState, owner: String, moves: Array) -> bool:
	# moves: Array di { region } (destinazione di 1 Armata ciascuno).
	var p := gs.player_by_power(owner)
	if p == null:
		return false
	var n := moves.size()
	if p.armies_available < n:
		return false
	# Ogni destinazione dev'essere in zona di interesse o dove si ha una Base.
	for m in moves:
		if not move_dest_valid(gs, p, String(m["region"])):
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
	if cid != "" and cid in p.bases:
		return -1  # regolamento pag. 15: si può costruire una sola Base per Country
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
	if cid != "" and cid not in p.bases:
		p.bases.append(cid)                             # Base sul Paese (rendering + Move)
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
