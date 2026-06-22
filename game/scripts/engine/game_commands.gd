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

const KNOWN := ["choose_focus", "play_card", "end_turn"]


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
	return false
