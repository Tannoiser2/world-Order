class_name Threat
extends RefCounted
## Risoluzione THREAT/Defense in una Regione (Aftermath, regolamento pag. 19).
## Logica validata contro gli Esempi 1 (Central Asia) e 2 (Europe) del regolamento.

## Calcola i VP persi da ciascun giocatore per la THREAT in una Regione.
## - zone: Array dei poteri la cui bandiera e' nella Regione (solo loro "controllano").
## - armies: Dictionary power -> numero di Armate nella Regione.
## - military_focus: Dictionary power -> bool (Military Focus questo round).
## - defense_bonus: Dictionary power -> int (es. +2 per Country da Engage scartato).
## - nato: Array di coppie [a, b] che ignorano la THREAT reciproca.
## Ritorna Dictionary power -> VP persi (>= 0).
static func resolve_region(zone: Array, armies: Dictionary, military_focus: Dictionary,
		defense_bonus: Dictionary, nato: Array = []) -> Dictionary:

	var threat := func(p: String) -> int:
		var a: int = int(armies.get(p, 0))
		var t := a
		if bool(military_focus.get(p, false)) and a > 0:
			t += 1
		return t

	var defense := func(p: String) -> int:
		var d: int = int(armies.get(p, 0))
		if bool(military_focus.get(p, false)) and p in zone:
			d += 1
		d += int(defense_bonus.get(p, 0))
		return d

	var ignores := func(a: String, b: String) -> bool:
		for pair in nato:
			if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
				return true
		return false

	# Tutti i poteri presenti (con almeno 1 Armata) o nella zona.
	var present := {}
	for p in armies.keys():
		present[p] = true
	for p in zone:
		present[p] = true

	var loss := {}
	for p in zone:
		var def_p: int = defense.call(p)
		var count := 0
		for q in present.keys():
			if q == p:
				continue
			if ignores.call(p, q):
				continue
			if threat.call(q) > def_p:
				count += 1
		if count > 0:
			loss[p] = 2 * count
	return loss
