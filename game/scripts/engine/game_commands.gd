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
	"choose_focus", "play_card", "end_turn", "use_ongoing", "increase_production",
	# Giocare una carta a faccia in giù: +10 money, oppure come costo di una Carta Strategica
	"play_money_token", "play_strategic_asset",
	# Sotto-scelte durante la risoluzione di una carta/azione
	"pick_region", "pick_influence_cell", "pick_allied_country", "exhaust_ally",
	# Improve Relations: scelta della Country sul tabellone + conferma/salta dello sconto
	# (esaurire alleati). Le callback non sono serializzabili: le esegue l'host.
	"pick_board_country", "exhaust_confirm", "exhaust_skip",
	# Scelta a "popup" (es. quante Armate / quanto money): il client invia l'INDICE scelto,
	# l'host esegue la callback corrispondente (non serializzabile).
	"popup_choice",
	# Azioni a PAYLOAD pieno (la selezione si compone in locale, poi si invia il risultato)
	"produce", "trade", "move_army", "move_finish",
	# Annullo di Commercio/Produce e della giocata in corso (Move/scelte): deve passare
	# dall'host, altrimenti il client esce ma l'host resta dentro -> tutto bloccato.
	"trade_cancel", "produce_cancel", "cancel_card",
	# Get a Growth Card (Azione) e acquisto al Market (Research)
	"buy_growth", "buy_market",
	# Research (fase per-giocatore): oltre a buy_market, esaurire un alleato, rimescolare il
	# Market e AVANZARE al giocatore successivo (così anche il client le instrada all'host).
	"research_exhaust_ally", "research_reshuffle", "research_continue",
	# Aftermath (fase per-giocatore; gating sul giocatore Aftermath, non su active_seat)
	"aftermath_token", "aftermath_prosperity", "aftermath_continue",
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


## Carta di mano (per INDICE) giocata a faccia in giù per +10 money.
static func play_money_token(seat: int, seq: int, hand_index: int) -> Dictionary:
	return make("play_money_token", seat, seq, {"hand_index": hand_index})


## Carta di mano (per INDICE) usata come costo per attivare uno Strategic Asset (per id).
static func play_strategic_asset(seat: int, seq: int, hand_index: int, asset_id: String) -> Dictionary:
	return make("play_strategic_asset", seat, seq, {"hand_index": hand_index, "asset_id": asset_id})


static func use_ongoing(seat: int, seq: int, tag: String) -> Dictionary:
	return make("use_ongoing", seat, seq, {"tag": tag})


## Aumento Produzione opzionale (passo Choose Focus della Preparazione). `type` vuoto
## = il giocatore SALTA l'aumento. Se `type` è una primaria, l'effetto dà +1 risorsa.
static func increase_production(seat: int, seq: int, type: String) -> Dictionary:
	return make("increase_production", seat, seq, {"type": type})


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


## Scelta a popup: `index` = posizione dell'opzione scelta (l'host ha le opzioni+callback).
static func popup_choice(seat: int, seq: int, index: int) -> Dictionary:
	return make("popup_choice", seat, seq, {"index": index})


## Improve Relations: scelta della Country (per ID, nella Regione) e conferma/salta sconto.
static func pick_board_country(seat: int, seq: int, region: String, country_id: String) -> Dictionary:
	return make("pick_board_country", seat, seq, {"region": region, "country_id": country_id})


static func exhaust_confirm(seat: int, seq: int) -> Dictionary:
	return make("exhaust_confirm", seat, seq, {})


static func exhaust_skip(seat: int, seq: int) -> Dictionary:
	return make("exhaust_skip", seat, seq, {})


## Produce (azione domestica): `sel` mappa tipo_risorsa -> quantità da produrre. La
## selezione si compone in locale sulla resource track; il comando porta il RISULTATO.
static func produce(seat: int, seq: int, sel: Dictionary) -> Dictionary:
	return make("produce", seat, seq, {"sel": sel.duplicate(true)})


## Trade (Commercio): `export`/`import` mappano risorsa -> quantità; `import_src` mappa
## risorsa -> venditore scelto ("reserve" o potenza); `armies` = Armate vendute dalla riserva.
static func trade(seat: int, seq: int, export_sel: Dictionary, import_sel: Dictionary, import_src: Dictionary, armies: int) -> Dictionary:
	return make("trade", seat, seq, {
		"export": export_sel.duplicate(true), "import": import_sel.duplicate(true),
		"import_src": import_src.duplicate(true), "armies": armies})


## Move: UN singolo spostamento di 1 Armata da `src` (id Regione o "_reserve") a `dest`
## (id Regione). Ogni passo è un comando; l'host applica costo/limiti e ribroadcasta.
static func move_army(seat: int, seq: int, src: String, dest: String) -> Dictionary:
	return make("move_army", seat, seq, {"src": src, "dest": dest})


## Move: termina la fase di spostamento (verifica il minimo e consuma la giocata).
static func move_finish(seat: int, seq: int) -> Dictionary:
	return make("move_finish", seat, seq, {})


static func trade_cancel(seat: int, seq: int) -> Dictionary:
	return make("trade_cancel", seat, seq, {})


static func produce_cancel(seat: int, seq: int) -> Dictionary:
	return make("produce_cancel", seat, seq, {})


static func cancel_card(seat: int, seq: int) -> Dictionary:
	return make("cancel_card", seat, seq, {})


static func buy_growth(seat: int, seq: int, card_id: String) -> Dictionary:
	return make("buy_growth", seat, seq, {"card_id": card_id})


static func buy_market(seat: int, seq: int, card_id: String) -> Dictionary:
	return make("buy_market", seat, seq, {"card_id": card_id})


## Research (fase di fine round, per-giocatore). `seat` = giocatore di turno (active_seat).
static func research_exhaust_ally(seat: int, seq: int, country_id: String) -> Dictionary:
	return make("research_exhaust_ally", seat, seq, {"country_id": country_id})


static func research_reshuffle(seat: int, seq: int) -> Dictionary:
	return make("research_reshuffle", seat, seq, {})


static func research_continue(seat: int, seq: int) -> Dictionary:
	return make("research_continue", seat, seq, {})


## Aftermath. `kind`: "money" (ROI) o "defense" (THREAT). seat = giocatore Aftermath.
static func aftermath_token(seat: int, seq: int, region: String, kind: String) -> Dictionary:
	return make("aftermath_token", seat, seq, {"region": region, "kind": kind})


static func aftermath_prosperity(seat: int, seq: int) -> Dictionary:
	return make("aftermath_prosperity", seat, seq, {})


static func aftermath_continue(seat: int, seq: int) -> Dictionary:
	return make("aftermath_continue", seat, seq, {})


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
		"play_money_token":
			return typeof(args.get("hand_index")) == TYPE_INT and int(args["hand_index"]) >= 0
		"play_strategic_asset":
			return typeof(args.get("hand_index")) == TYPE_INT and int(args["hand_index"]) >= 0 \
				and typeof(args.get("asset_id")) == TYPE_STRING and String(args["asset_id"]) != ""
		"use_ongoing":
			return typeof(args.get("tag")) == TYPE_STRING and String(args["tag"]) != ""
		"increase_production":
			return typeof(args.get("type")) == TYPE_STRING   # "" ammesso = salta
		"pick_region":
			return typeof(args.get("region")) == TYPE_STRING and String(args["region"]) != ""
		"pick_influence_cell":
			return typeof(args.get("region")) == TYPE_STRING and String(args["region"]) != "" \
				and String(args.get("slot", "")) in ["permanent", "temporary"]
		"pick_allied_country", "exhaust_ally":
			return typeof(args.get("country_id")) == TYPE_STRING and String(args["country_id"]) != ""
		"popup_choice":
			return typeof(args.get("index")) == TYPE_INT and int(args["index"]) >= 0
		"pick_board_country":
			return typeof(args.get("region")) == TYPE_STRING and String(args["region"]) != "" \
				and typeof(args.get("country_id")) == TYPE_STRING and String(args["country_id"]) != ""
		"exhaust_confirm", "exhaust_skip":
			return true
		"produce":
			return typeof(args.get("sel")) == TYPE_DICTIONARY
		"trade":
			return typeof(args.get("export")) == TYPE_DICTIONARY \
				and typeof(args.get("import")) == TYPE_DICTIONARY \
				and typeof(args.get("import_src")) == TYPE_DICTIONARY \
				and typeof(args.get("armies")) == TYPE_INT
		"move_army":
			return typeof(args.get("src")) == TYPE_STRING and String(args["src"]) != "" \
				and typeof(args.get("dest")) == TYPE_STRING and String(args["dest"]) != ""
		"move_finish", "trade_cancel", "produce_cancel", "cancel_card":
			return true
		"buy_growth", "buy_market":
			return typeof(args.get("card_id")) == TYPE_STRING and String(args["card_id"]) != ""
		"research_exhaust_ally":
			return typeof(args.get("country_id")) == TYPE_STRING and String(args["country_id"]) != ""
		"research_reshuffle", "research_continue":
			return true
		"aftermath_token":
			return typeof(args.get("region")) == TYPE_STRING and String(args["region"]) != "" \
				and String(args.get("kind", "")) in ["money", "defense"]
		"aftermath_prosperity", "aftermath_continue":
			return true
	return false
