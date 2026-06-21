class_name Scoring
extends RefCounted
## Calcolo del punteggio di una Regione (Score Regions, regolamento pag. 20).
## Logica validata contro l'esempio MENA del regolamento.

## Calcola i VP per ciascun giocatore in una Regione.
## - track: InfluenceTrack della Regione
## - majority_bonus: Array[int] dei bonus per posizione (1°, 2°, ...)
## - armies: Dictionary owner -> numero di Armate nella Regione (per i pareggi)
## - players: lista degli owner reali (esclude "local")
## Ritorna Dictionary owner -> VP totali (1 per cubo + bonus maggioranza).
static func score_region(track: InfluenceTrack, majority_bonus: Array, armies: Dictionary, players: Array) -> Dictionary:
	# Una Regione segna solo se tutti gli slot permanenti sono coperti.
	if not track.all_permanent_filled():
		return {}

	# Raccogli (owner, conteggio, armate) per chi ha almeno 1 Influenza.
	var entries := []
	for owner in track.owners():
		var c: int = track.count(owner)
		if c > 0:
			entries.append({"owner": owner, "count": c, "armies": int(armies.get(owner, 0))})

	# 1 VP per cubo (solo giocatori reali).
	var result := {}
	for e in entries:
		if e["owner"] in players:
			result[e["owner"]] = e["count"]

	# Ordina per (Influenza desc, Armate desc).
	entries.sort_custom(func(a, b):
		if a["count"] != b["count"]:
			return a["count"] > b["count"]
		return a["armies"] > b["armies"])

	# Assegna i bonus maggioranza; i pari condividono la posizione PIU' BASSA.
	var i := 0
	while i < entries.size():
		var j := i
		while j + 1 < entries.size() \
				and entries[j + 1]["count"] == entries[i]["count"] \
				and entries[j + 1]["armies"] == entries[i]["armies"]:
			j += 1
		var b: int = majority_bonus[j] if j < majority_bonus.size() else 0
		for k in range(i, j + 1):
			var owner: String = entries[k]["owner"]
			if owner in players:
				result[owner] = int(result.get(owner, 0)) + b
		i = j + 1

	return result


## Classifica di maggioranza per la UI: ritorna, IN ORDINE di posizione (1°, 2°, …),
## un Dictionary {owner, count, bonus} per ogni partecipante (inclusi i 'local').
## Riflette le stesse regole di score_region (ordina per Influenza desc, poi Armate;
## i pari condividono la posizione più bassa). Ritorna [] se la Regione non segna
## (permanenti non tutti pieni). Il chiamante mostra bandiera+bonus sulle posizioni.
static func region_ranking(track: InfluenceTrack, majority_bonus: Array, armies: Dictionary) -> Array:
	if not track.all_permanent_filled():
		return []
	var entries := []
	for owner in track.owners():
		var c: int = track.count(owner)
		if c > 0:
			entries.append({"owner": owner, "count": c, "armies": int(armies.get(owner, 0))})
	entries.sort_custom(func(a, b):
		if a["count"] != b["count"]:
			return a["count"] > b["count"]
		return a["armies"] > b["armies"])
	var out := []
	var i := 0
	while i < entries.size():
		var j := i
		while j + 1 < entries.size() \
				and entries[j + 1]["count"] == entries[i]["count"] \
				and entries[j + 1]["armies"] == entries[i]["armies"]:
			j += 1
		var b: int = majority_bonus[j] if j < majority_bonus.size() else 0
		for k in range(i, j + 1):
			out.append({"owner": entries[k]["owner"], "count": entries[k]["count"], "bonus": b})
		i = j + 1
	return out
