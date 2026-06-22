class_name GameCommands
extends RefCounted
## Command bus (Step A) — vedi docs/multiplayer-design.md.
##
## UNICO vocabolario degli input di GIOCO. Un comando è un Dictionary
## SERIALIZZABILE (niente riferimenti a oggetti vivi: solo id/indici stabili),
## così lo stesso input vale in hot-seat (applicato localmente) e in rete
## (spedito all'host). Qui vivono SOLO: catalogo, costruttori e validazione di
## FORMA. La validazione delle REGOLE e l'applicazione le fa la Vista/host
## (board_view.apply_command), che nello Step B migrerà su un SessionContext.
##
## Step A copre il sottoinsieme che valida l'impianto; il catalogo si estenderà
## a trade/produce/sotto-scelte/aftermath nei passi successivi.

const KNOWN := [
	# Azione (turno del giocatore attivo) e Preparazione
	"choose_focus", "play_card", "end_turn", "use_ongoing",
	# Sotto-scelte durante la risoluzione di una carta/azione
	"pick_region", "pick_influence_cell", "pick_allied_country", "exhaust_ally",
]


## Forma comune: { type, seat, seq, args }.
## - seat: indice del seggio mittente (in gs.players / turn_order)
## - seq:  progressivo per-seggio (ordina e rende idempotente lato host)
static func make(type: String, seat: int, seq: int, args: Dictionary = {}) -> Dictionary:
	return {"type": type, "seat": seat, "seq": seq, "args": args.duplicate(true)}


static func choose_focus(seat: int, seq: int, focus: int) -> Dictionary:
	return make("choose_focus", seat, seq, {"focus": focus})


## La carta è riferita per INDICE in mano (stabile e non ambiguo, anche con
## carte duplicate); l'ordine mano è preservato nello stato redatto del proprietario.
static func play_card(seat: int, seq: int, hand_index: int) -> Dictionary:
	return make("play_card", seat, seq, {"hand_index": hand_index})


static func end_turn(seat: int, seq: int) -> Dictionary:
	return make("end_turn", seat, seq, {})


static func use_ongoing(seat: int, seq: int, tag: String) -> Dictionary:
	return make("use_ongoing", seat, seq, {"tag": tag})


## Sotto-scelte (risolvono uno stato `awaiting` durante la risoluzione di una carta).
## Riferimenti per ID/nome stabili (region, slot "permanent"/"temporary", country_id).
static func pick_region(seat: int, seq: int, region: String) -> Dictionary:
	return make("pick_region", seat, seq, {"region": region})


static func pick_influence_cell(seat: int, seq: int, region: String, slot: String) -> Dictionary:
	return make("pick_influence_cell", seat, seq, {"region": region, "slot": slot})


static func pick_allied_country(seat: int, seq: int, country_id: String) -> Dictionary:
	return make("pick_allied_country", seat, seq, {"country_id": country_id})


static func exhaust_ally(seat: int, seq: int, country_id: String) -> Dictionary:
	return make("exhaust_ally", seat, seq, {"country_id": country_id})


## Validazione STRUTTURALE (forma e tipi), non di merito: le regole le verifica
## il motore quando il comando viene applicato.
static func valid_shape(cmd: Variant) -> bool:
	if typeof(cmd) != TYPE_DICTIONARY:
		return false
	if not (String(cmd.get("type", "")) in KNOWN):
		return false
	if typeof(cmd.get("seat")) != TYPE_INT or typeof(cmd.get("seq")) != TYPE_INT:
		return false
	var args: Variant = cmd.get("args", {})
	if typeof(args) != TYPE_DICTIONARY:
		return false
	match String(cmd["type"]):
		"choose_focus":
			return typeof(args.get("focus")) == TYPE_INT and int(args["focus"]) in [0, 1, 2]
		"play_card":
			return typeof(args.get("hand_index")) == TYPE_INT and int(args["hand_index"]) >= 0
		"end_turn":
			return true
		"use_ongoing":
			return typeof(args.get("tag")) == TYPE_STRING and String(args["tag"]) != ""
		"pick_region":
			return typeof(args.get("region")) == TYPE_STRING and String(args["region"]) != ""
		"pick_influence_cell":
			return typeof(args.get("region")) == TYPE_STRING and String(args["region"]) != "" \
				and String(args.get("slot", "")) in ["permanent", "temporary"]
		"pick_allied_country", "exhaust_ally":
			return typeof(args.get("country_id")) == TYPE_STRING and String(args["country_id"]) != ""
	return false
