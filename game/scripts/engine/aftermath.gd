class_name Aftermath
extends RefCounted
## Fase di Aftermath (regolamento pag. 19-21): Return on Investments, scoring
## delle Regioni (vedi Scoring), i 3 token Maggioranza e le abilita' speciali
## di fine partita. Logica dei pareggi condivisa con Scoring (i pari prendono
## la posizione piu' bassa). Validato contro l'esempio dei token (pag. 21).

## Return on Investments: 2 money per ogni FDI moltiplicato per il valore del
## Paese; + 5 money per Country alleato della Regione per ogni Engage token
## scartato. Ritorna il money guadagnato.
static func return_on_investments(p: PlayerState, fdi_country_values: Array,
		engage_discards: Array) -> int:
	var gained := 0
	for v in fdi_country_values:
		gained += 2 * int(v)
	for allied_count in engage_discards:
		gained += 5 * int(allied_count)
	p.money += gained
	return gained


## Assegna i bonus di una maggioranza (token o Regione).
## - metric: Dictionary player -> valore della metrica.
## - bonus: Array[int] dei bonus per posizione (1°, 2°, ...).
## - two_player: in 2 giocatori solo il 1° assoluto (non in pareggio) segna.
## Ritorna Dictionary player -> VP.
static func score_majority(metric: Dictionary, bonus: Array, two_player: bool = false) -> Dictionary:
	var entries := []
	for player in metric:
		entries.append({"player": player, "value": int(metric[player])})
	entries.sort_custom(func(a, b): return a["value"] > b["value"])

	var result := {}
	var i := 0
	while i < entries.size():
		var j := i
		while j + 1 < entries.size() and entries[j + 1]["value"] == entries[i]["value"]:
			j += 1
		# posizioni i..j pari -> prendono il bonus della posizione piu' bassa (indice j)
		if two_player:
			# solo il 1° assoluto e senza pareggio segna
			if i == 0 and j == 0:
				result[entries[0]["player"]] = bonus[0] if bonus.size() > 0 else 0
			break
		var b: int = bonus[j] if j < bonus.size() else 0
		for k in range(i, j + 1):
			result[entries[k]["player"]] = b
		i = j + 1
	return result


# --- Abilita' speciali di fine partita ---

## USA — Global Superpower Status: penalita' se le Regioni con la maggioranza
## (o pari) di Influenza USA sono meno di 4.
static func global_superpower_status_penalty(num_regions_majority: int, table: Dictionary) -> int:
	if num_regions_majority >= 4:
		return 0
	return int(table.get(str(num_regions_majority), 0))


## Russia — Secured Sphere of Influence: VP per ogni Regione della propria zona
## dove Russia ha piu' Armate (o pari, con almeno 1).
static func secured_sphere_vp(num_zone_regions_most_armies: int, vp_per_region: int) -> int:
	return num_zone_regions_most_armies * vp_per_region


## China — Global FDI Network: VP in base alle Regioni con almeno 1 FDI cinese.
static func global_fdi_network_vp(num_regions_with_fdi: int, table: Dictionary) -> int:
	# soglia minima: la prima chiave della tabella.
	var best := 0
	for k in table:
		var threshold := int(k)
		if num_regions_with_fdi >= threshold:
			best = max(best, int(table[k]))
	return best
