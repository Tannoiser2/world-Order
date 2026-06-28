class_name DataLoader
extends RefCounted
## Carica i dati di gioco (JSON in res://data/) in Dictionary/Array.
## I JSON sono sincronizzati da ../data/ tramite tools/sync_data.py.

const BASE := "res://data/"

static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: file mancante %s" % path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Tutte le Country (unione delle 7 Regioni).
static func load_countries() -> Array:
	var out := []
	for region in ["europe", "central_asia", "americas", "middle_east_north_africa",
			"africa", "south_asia", "east_asia_pacific"]:
		var doc: Variant = _read(BASE + "countries/%s.json" % region)
		if doc:
			out.append_array(doc.get("countries", []))
	return out


## Carte abilita' iniziali per potenza: Dictionary power -> Array.
static func load_starting_abilities() -> Dictionary:
	var out := {}
	for power in ["usa", "eu", "russia", "china"]:
		var doc: Variant = _read(BASE + "abilities/%s_starting.json" % power)
		if doc:
			out[power] = doc.get("cards", [])
	return out


static func load_market() -> Array:
	var doc: Variant = _read(BASE + "market_cards.json")
	return doc.get("cards", []) if doc else []


static func load_growth() -> Array:
	var doc: Variant = _read(BASE + "growth_cards.json")
	return doc.get("cards", []) if doc else []


static func load_strategic_assets() -> Array:
	var doc: Variant = _read(BASE + "strategic_assets.json")
	return doc.get("cards", []) if doc else []


static func load_board() -> Dictionary:
	var doc: Variant = _read(BASE + "board.json")
	return doc if doc else {}


static func load_player_boards() -> Dictionary:
	var doc: Variant = _read(BASE + "player_boards.json")
	return doc if doc else {}


static func load_trade_deals() -> Dictionary:
	var doc: Variant = _read(BASE + "trade_deals.json")
	return doc if doc else {}


static func load_auto_influence() -> Array:
	var doc: Variant = _read(BASE + "auto_influence.json")
	return doc.get("cards", []) if doc else []


## Executive Order (modulo opzionale): carta unica con le azioni (effect_ops = scelta a 8 opzioni).
static func load_executive_order() -> Dictionary:
	var doc: Variant = _read(BASE + "executive_orders.json")
	return doc if doc else {}


## Automa board universale (mappa tipo carta -> azione, focus money). Solo mode.
static func load_automa_board() -> Dictionary:
	var doc: Variant = _read(BASE + "automa_board.json")
	return doc if doc else {}


## Player card degli Automa per potenza (money iniziale, priorita', prosperity). Solo mode.
static func load_automa_players() -> Dictionary:
	var doc: Variant = _read(BASE + "automa_players.json")
	return doc.get("powers", {}) if doc else {}
