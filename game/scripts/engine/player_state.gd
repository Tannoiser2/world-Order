class_name PlayerState
extends RefCounted
## Stato di un giocatore (una potenza).

var power: String = ""            # "usa" | "eu" | "russia" | "china"
var money: int = 0
var victory_points: int = 0

## Risorse correnti: tipo -> quantita' (cap a 10 sul Resource Track).
var resources: Dictionary = {
	"energy": 0, "raw_materials": 0, "food": 0,
	"consumer_goods": 0, "services": 0, "diplomacy": 0, "armies": 0,
}
## Livello di Produzione per tipo di risorsa.
var production: Dictionary = {}

var prosperity_level: int = 0
var focus: int = WO.Focus.DOMESTIC

## Mazzo / mano / scarti / carte giocate (liste di card-id o dati carta).
var deck: Array = []
var hand: Array = []
var discard: Array = []
var played: Array = []

## Country alleate (dati carta) e loro stato exhausted.
var allied_countries: Array = []
var exhausted: Dictionary = {}    # country_id -> bool

var armies_available: int = 0     # Army token sulla plancia (non sul Resource Track)
var strategic_assets: Array = []
var growth_cards: Array = []
var used_strategic_assets: Array = []
var executive_order_used: bool = false   # Executive Order: se NON usata, +3 VP a fine partita
var fdi_values: Array = []         # valori dei Paesi con un tuo token FDI (per Return on Investments)
var fdi_countries: Array = []      # id dei Paesi su cui hai un token FDI (per il rendering)
var bases: Array = []              # id dei Paesi su cui hai una Base militare
var engage_tokens: Array = []      # Regioni su cui hai un Engage token (max 3)

const RESOURCE_CAP := 10

## Aggiunge risorse rispettando il cap a 10 (regolamento pag. 16): oltre il 10
## ogni unità si converte in money pari al suo Import cost, TRANNE Diplomazia e
## Armate, la cui eccedenza va semplicemente persa. Ritorna il money guadagnato.
func gain_resource(rtype: String, amount: int, import_cost: int = 0) -> int:
	var overflow_money := 0
	for _i in amount:
		if resources[rtype] < RESOURCE_CAP:
			resources[rtype] += 1
		elif rtype != "armies" and rtype != "diplomacy":
			overflow_money += import_cost
	money += overflow_money
	return overflow_money


func has_resources(cost: Dictionary) -> bool:
	# Chiave speciale "any" = N risorse QUALSIASI (qualunque tipo prodotto): si riservano prima
	# i costi specifici, poi si controlla che il RESIDUO copra "any".
	if not cost.has("any"):
		for k in cost:
			if k == "money":
				if money < int(cost[k]):
					return false
			elif int(resources.get(k, 0)) < int(cost[k]):
				return false
		return true
	var remaining := resources.duplicate()
	for k in cost:
		if k == "any":
			continue
		if k == "money":
			if money < int(cost[k]):
				return false
		else:
			remaining[k] = int(remaining.get(k, 0)) - int(cost[k])
			if remaining[k] < 0:
				return false
	var pool := 0
	for k in remaining:
		pool += maxi(0, int(remaining[k]))
	return pool >= int(cost["any"])


## Pesca n carte dal mazzo (rimescola gli scarti se il mazzo si esaurisce).
func draw_cards(n: int) -> int:
	var drawn := 0
	for _i in n:
		if deck.is_empty():
			if discard.is_empty():
				break
			deck = discard.duplicate()
			discard.clear()
			deck.shuffle()
		hand.append(deck.pop_back())
		drawn += 1
	return drawn


func spend(cost: Dictionary) -> bool:
	if not has_resources(cost):
		return false
	var any_needed := 0
	for k in cost:
		if k == "any":
			any_needed = int(cost[k])
		elif k == "money":
			money -= int(cost[k])
		else:
			resources[k] -= int(cost[k])
	# "any": preleva dalle risorse piu' abbondanti (dopo aver pagato i costi specifici).
	if any_needed > 0:
		var order: Array = resources.keys()
		order.sort_custom(func(a, b): return int(resources[a]) > int(resources[b]))
		for k in order:
			while any_needed > 0 and int(resources[k]) > 0:
				resources[k] -= 1
				any_needed -= 1
	return true


## Serializzazione (snapshot/rete): solo dati puri (le carte sono già dizionari).
## duplicate(true) = copia profonda, così lo snapshot è indipendente dallo stato vivo.
func to_dict() -> Dictionary:
	return {
		"power": power, "money": money, "victory_points": victory_points,
		"resources": resources.duplicate(true),
		"production": production.duplicate(true),
		"prosperity_level": prosperity_level, "focus": focus,
		"deck": deck.duplicate(true), "hand": hand.duplicate(true),
		"discard": discard.duplicate(true), "played": played.duplicate(true),
		"allied_countries": allied_countries.duplicate(true),
		"exhausted": exhausted.duplicate(true),
		"armies_available": armies_available,
		"strategic_assets": strategic_assets.duplicate(true),
		"growth_cards": growth_cards.duplicate(true),
		"used_strategic_assets": used_strategic_assets.duplicate(true),
		"executive_order_used": executive_order_used,
		"fdi_values": fdi_values.duplicate(true),
		"fdi_countries": fdi_countries.duplicate(true),
		"bases": bases.duplicate(true),
		"engage_tokens": engage_tokens.duplicate(true),
	}


static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.power = String(d.get("power", ""))
	p.money = int(d.get("money", 0))
	p.victory_points = int(d.get("victory_points", 0))
	p.resources = (d.get("resources", {}) as Dictionary).duplicate(true)
	p.production = (d.get("production", {}) as Dictionary).duplicate(true)
	p.prosperity_level = int(d.get("prosperity_level", 0))
	p.focus = int(d.get("focus", WO.Focus.DOMESTIC))
	p.deck = (d.get("deck", []) as Array).duplicate(true)
	p.hand = (d.get("hand", []) as Array).duplicate(true)
	p.discard = (d.get("discard", []) as Array).duplicate(true)
	p.played = (d.get("played", []) as Array).duplicate(true)
	p.allied_countries = (d.get("allied_countries", []) as Array).duplicate(true)
	p.exhausted = (d.get("exhausted", {}) as Dictionary).duplicate(true)
	p.armies_available = int(d.get("armies_available", 0))
	p.strategic_assets = (d.get("strategic_assets", []) as Array).duplicate(true)
	p.growth_cards = (d.get("growth_cards", []) as Array).duplicate(true)
	p.used_strategic_assets = (d.get("used_strategic_assets", []) as Array).duplicate(true)
	p.executive_order_used = bool(d.get("executive_order_used", false))
	p.fdi_values = (d.get("fdi_values", []) as Array).duplicate(true)
	p.fdi_countries = (d.get("fdi_countries", []) as Array).duplicate(true)
	p.bases = (d.get("bases", []) as Array).duplicate(true)
	p.engage_tokens = (d.get("engage_tokens", []) as Array).duplicate(true)
	return p
