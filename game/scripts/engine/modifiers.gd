class_name Modifiers
extends RefCounted
## Applica gli `effect_modifiers` delle carte (sconti/bonus condizionali) durante
## il flusso di gioco. Un modifier e' una stringa "chiave" o "chiave:valore"
## (es. "improve_discount:1", "engage_discount_per_army", "pay_money_for_services:10").
## Qui sono gestiti i modifier che incidono sui COSTI delle azioni; gli altri
## (condizionali sull'Influenza, ripetizioni, ecc.) restano marcati nei dati.

## Trasforma una lista di stringhe in Dictionary chiave -> valore (int o true).
static func parse(list: Array) -> Dictionary:
	var out := {}
	for raw in list:
		var s := String(raw)
		var idx := s.find(":")
		if idx == -1:
			out[s] = true
		else:
			var key := s.substr(0, idx)
			var val := s.substr(idx + 1)
			out[key] = int(val) if val.is_valid_int() else val
	return out


## Sconto in Diplomacy su Improve Relations dato dai modifier.
static func improve_discount(mods: Dictionary) -> int:
	return int(mods.get("improve_discount", 0))


## Sconto in Diplomacy su Engage in una Regione: somma i contributi condizionali
## (per Armata schierata, per alleato nella Regione, sconto fisso in certe Regioni).
static func engage_discount(mods: Dictionary, gs: GameState, power: String, region: String) -> int:
	var disc := 0
	if mods.has("engage_discount_per_army"):
		var a: Dictionary = gs.regions.get(region, {}).get("armies", {})
		disc += int(a.get(power, 0))
	if mods.has("engage_discount_per_allied"):
		var p := gs.player_by_power(power)
		if p:
			for c in p.allied_countries:
				if String(c.get("region", "")) == region:
					disc += 1
	if mods.has("engage_discount_1_in"):
		var regions := String(mods["engage_discount_1_in"]).split(",")
		if region in regions:
			disc += 1
	return disc


## Quanti money si possono pagare al posto di 1 Services (0 = non consentito).
static func money_for_services(mods: Dictionary) -> int:
	return int(mods.get("pay_money_for_services", 0))


## Quanti money si possono pagare al posto di 1 Diplomacy (0 = non consentito).
static func money_for_diplomacy(mods: Dictionary) -> int:
	return int(mods.get("pay_money_for_diplomacy", 0))
