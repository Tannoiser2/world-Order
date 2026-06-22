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
	for k in cost:
		if k == "money":
			if money < int(cost[k]):
				return false
		elif int(resources.get(k, 0)) < int(cost[k]):
			return false
	return true


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
	for k in cost:
		if k == "money":
			money -= int(cost[k])
		else:
			resources[k] -= int(cost[k])
	return true
