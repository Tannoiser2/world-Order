extends Control
## Scena di gioco (Fase 2, MVP hot-seat): tabellone reale + Regioni cliccabili,
## plancia del giocatore attivo, mano di carte GIOCABILI. Cliccando una carta se
## ne risolvono le effect_ops, chiedendo i target (Regione sul board, oppure
## Country/risorsa/scelta via popup). Renderer + input sul motore (GameState).

const POWER_COLORS := {
	"usa": Color(0.45, 0.62, 0.9), "eu": Color(0.95, 0.82, 0.2),
	"russia": Color(0.9, 0.9, 0.9), "china": Color(0.9, 0.3, 0.3),
	"local": Color(0.3, 0.3, 0.3),
}
## Nome leggibile delle superpotenze (per i bottoni "compra da:" nel Commercio).
const POWER_LABEL := {"usa": "USA", "eu": "Europa", "china": "Cina", "russia": "Russia"}
const RES := ["energy", "raw_materials", "food", "consumer_goods", "services", "diplomacy", "armies"]
const RES_LABEL := {
	"energy": "En", "raw_materials": "RM", "food": "Food",
	"consumer_goods": "CG", "services": "Serv", "diplomacy": "Dip", "armies": "Army",
}
const FOCUS_NAME := ["Domestic", "Diplomatic", "Military"]
## Op che si risolvono da sole (senza target).
const AUTO_OPS := ["gain_money", "gain_resource", "gain_armies", "gain_vp", "trade",
	"draw", "play_another", "noop", "spend", "ongoing", "research_free",
	"gain_money_per_fdi", "increase_production", "reset_influence", "convert_influence",
	"ready_country", "trash", "sell_armies", "spend_for_gain", "spend_then", "repeat",
	"discard", "increase_prosperity"]
## Risorse commerciabili nella Trade action (no armi/diplomazia per ora).
const TRADE_RES := ["energy", "raw_materials", "food", "consumer_goods", "services"]
## Caselle "1° 2° 3° 4°" dell'area TURN ORDER sotto il titolo (normalizzato sul tabellone).
const TURN_ORDER_SLOTS := [Vector2(0.0886, 0.2427), Vector2(0.1380, 0.2428), Vector2(0.1886, 0.2428), Vector2(0.2394, 0.2427)]

var gs: GameState
var active_seat := 0
## Command bus (Step A, vedi docs/multiplayer-design.md): gli input di gioco
## passano per apply_command(). _cmd_seq numera i comandi del seggio locale;
## _command_log li registra (utile per test/replay e, in futuro, per la rete).
var _cmd_seq := 0
var _command_log: Array = []
var board_rect: TextureRect
var overlay: Control
var card_layer: Control            # carte nazione nelle aree designate
var map_viewport: Control          # finestra che ritaglia la mappa
var map_content: Control           # nodo pannato/zoomato (mappa + Regioni)
var board_native: Vector2 = Vector2(2200, 1964)
var _min_zoom := 0.1
var _user_adjusted := false   # true quando l'utente ha pannato/zoomato a mano (stop auto-fit)
var _mouse_dragging := false
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var layout: Dictionary
var status_label: Label
var board_bg: TextureRect          # plancia di produzione (immagine) della potenza attiva
var hand_box: HBoxContainer
var popup_layer: Control
# HUD persistente + cassetto (drawer) della plancia giocatore.
var top_hud: PanelContainer
var hud_box: HBoxContainer
var choice_bar: Panel             # barra SOTTO l'HUD per le scelte (niente popup sulla board)
var choice_flow: HFlowContainer   # contenuto della barra scelte (prompt + bottoni)
var drawer: Panel                   # foglio in basso, mostrato a richiesta
var drawer_veil: ColorRect
var drawer_content: VBoxContainer
var hand_pinned: VBoxContainer   # mano del giocatore, in un pannello full-width in basso
var hand_panel: Panel            # pannello MANO a tutta larghezza (overlay su mappa+board)
var market_panel: Panel          # "board mercato" (Research): appare al posto della mappa
var market_content: VBoxContainer  # contenuto scrollabile del pannello mercato
var hand_collapsed := false      # mano collassabile (per non coprire la plancia)
var _selected_hand_card: Dictionary = {}  # carta evidenziata nella mano (1° tap); 2° tap = gioca
var card_preview: TextureRect    # anteprima ingrandita della carta (flyover)
var tab_bar: HBoxContainer          # una scheda per ogni potenza in gioco
var end_turn_btn: Button            # "Fine turno": in basso a destra (comodo), non più in alto
var tab_bg: Panel                   # sfondo solido della barra linguette
var drawer_open := false
var drawer_power := ""              # potenza la cui plancia è mostrata nel cassetto
var ui_theme: Theme                 # font/scala globale proporzionale alla viewport

var all_countries: Array = []
var region_countries: Dictionary = {}   # rid -> { available:[c,c], deck:[...] }
var market_deck: Array = []             # mazzo Market mescolato
var market_display: Array = []          # carte Market scoperte (acquistabili)
var growth_pool: Array = []             # tutte le Growth card (per livello)
var trade_deals: Dictionary = {}        # limiti Export/Import e import_from per potenza
var focus_bonuses: Dictionary = {}      # ready/produce/ongoing per ogni Focus (domestic/diplomatic/military)
var _auto_inf_deck: Array = []          # mazzo Auto-Influence (potenze neutrali, <4 giocatori)
var _trade_sel: Dictionary = {}         # selezione in corso: {export:{R:q}, import:{R:q}}
var _trade_import_src: Dictionary = {}  # R -> venditore scelto ("reserve" o power)
var _trade_mode := false                # Commercio attivo: la resource track della plancia è interattiva
var _trade_active_res := ""             # risorsa selezionata di cui si stanno mostrando le caselle valide
var _trade_armies := 0                  # Armate vendute dalla riserva in questo Commercio (#14, 20 cad.)
var _exhaust_sel: Dictionary = {}       # id nazione -> true: alleati scelti per lo sconto
var _exhaust_ctx: Dictionary = {}       # scelta sconto attiva: {region, title, cb} (click sulle carte)
var _produce_sel: Dictionary = {}       # rtype -> quantità da produrre (azione Produce)
var _produce_mode := false              # Produce attivo: si imposta sulla resource track della plancia
var _trade_exported: Dictionary = {}    # risorse esportate nell'ultimo Trade (per i bonus condizionali)
var _playing_asset := false             # true se stiamo risolvendo un Strategic Asset (non una carta di mano)
var _focus_round: Dictionary = {}       # power -> round in cui ha già scelto il Focus (gratis 1x/round)
var _prep_idx := 0                       # giocatore corrente nella PREPARATION guidata (scelta Focus)
var _prep_awaiting_increase := false     # in attesa della scelta "Increase Production" (post-Focus)
var _research_idx := 0                  # indice nel turn_order durante la Research
var _research_points := 0               # Research disponibili al giocatore corrente
const MARKET_SLOTS := 5
# Stato dell'Aftermath interattivo (scelte per giocatore prima di THREAT/Scoring).
var _aftermath_idx := 0                  # giocatore corrente nella fase scelte
var _aftermath_choice_p: PlayerState = null  # giocatore in scelta Aftermath (sulla mappa/plancia)
var _aftermath_lines: Array[String] = [] # righe del riepilogo di fine round
var _aftermath_ai_art := ""             # art della carta Auto-Influence (per il riepilogo)
var _threat_defense: Dictionary = {}    # {region: {power: +Difesa}} da Engage token scartati
# Stato del gioco di una carta:
var playing_card: Dictionary = {}
var play_queue: Array = []
var active_mods: Dictionary = {}   # effect_modifiers della carta in gioco (parse)
var awaiting := ""          # "" | "region" | "board_country" | "allied_country" | "move"
var awaiting_op: Dictionary = {}
## Stati che richiedono di toccare la MAPPA (Regioni): i bottoni-Regione diventano
## cliccabili e il cassetto plancia va CHIUSO per non coprire/bloccare la mappa.
const AWAITING_REGION := ["region", "move", "convert_influence", "reset_influence"]
## Tutti gli stati di interazione con la mappa (Regioni + Country sul tabellone).
const AWAITING_MAP := ["region", "move", "convert_influence", "reset_influence", "board_country", "influence_cell"]
var _move_ctx: Dictionary = {}   # stato dello spostamento Armate multi-Regione
var _influence_pick: Dictionary = {}   # scelta Influenza sulla MAPPA: {regions, force, cb}
var _used_ongoing: Dictionary = {}   # power -> [tag] abilità once-per-round già usate nel round
var _commerce_flipped: Dictionary = {}  # venditore(power) -> [indici] carte Commerce già girate nel round
var _plays_left := 1                  # carte ancora giocabili nel turno corrente (1 base)

## Abilità continuative (Growth): descrizione e se sono attivabili una volta/round.
const ONGOING_DESC := {
	"extra_draw_per_round": "Pesca 1 carta in più ogni round.",
	"extra_play_first_turn": "Primo turno del round: puoi giocare 1 carta in più.",
	"ready_extra_on_focus": "Quando fai Focus, prepari 1 Country card in più.",
	"once_per_round:draw_then_trash": "1x/round: pesca 1 carta, poi scartane 1.",
	"once_per_round:draw_highest_value_then_discard": "1x/round: pesca la carta di valore più alto del mazzo, poi scartane 1.",
	"once_per_round:improve_again_plus1": "1x/round: fai di nuovo Improve Relations (con +1).",
	"once_per_round:convert_influence": "1x/round: converti 1 Influenza temporanea in permanente.",
}
# Gestione round/turni:
var round_turn_count := 0   # turni totali presi nel round corrente
var game_over := false
var _ui_phase := "Azione"   # fase mostrata nell'HUD: Azione - Research - Aftermath


func _ready() -> void:
	ui_theme = Theme.new()
	theme = ui_theme   # ereditato da tutta la scena: font scalati in _layout_ui
	_apply_button_theme()   # i bottoni "normali" hanno una chiara forma da pulsante
	var powers: Array = GameConfig.powers if GameConfig.powers.size() >= 2 else GameConfig.powers_for_count_n(2)
	gs = GameSetup.new_game(powers)
	for p in gs.players:
		p.draw_cards(6)   # denaro iniziale: impostato per potenza in GameSetup
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_layout.json"))
	all_countries = DataLoader.load_countries()
	_setup_country_decks()
	market_deck = DataLoader.load_market().duplicate()
	market_deck.shuffle()
	growth_pool = DataLoader.load_growth()
	trade_deals = DataLoader.load_trade_deals()
	focus_bonuses = DataLoader.load_player_boards().get("focus_bonuses", {})
	_auto_inf_deck = DataLoader.load_auto_influence().duplicate()
	_auto_inf_deck.shuffle()
	_refill_market()

	# La radice non cattura il mouse: gli eventi sulle zone vuote della mappa
	# arrivano a _unhandled_input (così il trascinamento col mouse panna la mappa).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La mappa vive dentro un nodo pannabile/zoomabile (pinch + trascinamento).
	# Il suo rettangolo è impostato in _layout_ui, INCASTONATO tra HUD e linguette
	# (fuori dalla barra in alto, come le schede in basso).
	map_viewport = Control.new()
	map_viewport.clip_contents = true
	map_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_viewport)
	map_content = Control.new()
	map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_viewport.add_child(map_content)

	board_rect = TextureRect.new()
	board_rect.texture = load(layout.get("board_image", "res://assets/board/board.jpg"))
	if board_rect.texture:
		board_native = board_rect.texture.get_size()
	board_rect.stretch_mode = TextureRect.STRETCH_SCALE
	board_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_rect.position = Vector2.ZERO
	board_rect.size = board_native
	map_content.add_child(board_rect)
	map_content.size = board_native

	overlay = Control.new()
	overlay.position = Vector2.ZERO
	overlay.size = board_native
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(overlay)

	card_layer = Control.new()
	card_layer.position = Vector2.ZERO
	card_layer.size = board_native
	card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(card_layer)

	_build_hud()
	_build_drawer()
	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)

	# Anteprima carta ingrandita (flyover): compare passando sopra una carta.
	card_preview = TextureRect.new()
	card_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_preview.visible = false
	card_preview.z_index = 200
	add_child(card_preview)

	GamePhases.determine_turn_order(gs)
	round_turn_count = 0
	active_seat = gs.turn_order[0]
	_reset_plays()

	resized.connect(_on_resized)
	_layout_ui()
	_begin_preparation()   # Round 1: scelta guidata del Focus prima di agire (fa lei layout/refresh)


func _on_resized() -> void:
	_layout_ui()
	_layout_overlays()


func _active() -> PlayerState:
	return gs.players[active_seat]


## Stile globale dei Button "normali" (non flat, senza override): sfondo, bordo e
## padding così OGNI scelta cliccabile si vede chiaramente come un pulsante.
## I bottoni flat (carte, zone Focus...) e quelli con stylebox propria restano invariati.
func _apply_button_theme() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.22, 0.30)
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1); normal.border_color = Color(0.52, 0.62, 0.78, 0.85)
	normal.content_margin_left = 11; normal.content_margin_right = 11
	normal.content_margin_top = 5; normal.content_margin_bottom = 5
	var hover := normal.duplicate(); hover.bg_color = Color(0.26, 0.32, 0.42)
	var pressed := normal.duplicate(); pressed.bg_color = Color(0.33, 0.41, 0.54)
	var disabled := normal.duplicate(); disabled.bg_color = Color(0.13, 0.15, 0.19); disabled.border_color = Color(0.3, 0.33, 0.38, 0.6)
	ui_theme.set_stylebox("normal", "Button", normal)
	ui_theme.set_stylebox("hover", "Button", hover)
	ui_theme.set_stylebox("pressed", "Button", pressed)
	ui_theme.set_stylebox("focus", "Button", normal)
	ui_theme.set_stylebox("disabled", "Button", disabled)


## Mazzi Country per Regione: 2 carte disponibili (visibili) + mazzo.
func _setup_country_decks() -> void:
	var by_region := {}
	for c in all_countries:
		var rid: String = c.get("region", "")
		if not by_region.has(rid):
			by_region[rid] = []
		by_region[rid].append(c)
	for rid in gs.regions:
		var deck: Array = (by_region.get(rid, []) as Array).duplicate()
		deck.shuffle()
		var avail := []
		for _i in mini(2, deck.size()):
			avail.append(deck.pop_back())
		region_countries[rid] = {"available": avail, "deck": deck}


func _refill_available(rid: String) -> void:
	var rc: Dictionary = region_countries.get(rid, {})
	while rc.get("available", []).size() < 2 and rc.get("deck", []).size() > 0:
		rc["available"].append(rc["deck"].pop_back())


# --- Tabellone e Regioni ---

func _layout_overlays() -> void:
	if overlay == null:
		return
	for c in overlay.get_children():
		c.queue_free()
	# Le Regioni sono posizionate in coordinate native della mappa; lo zoom/pan
	# del contenitore le scala insieme all'immagine.
	for region in layout.get("regions", {}):
		var r: Array = layout["regions"][region]
		var btn := _make_region_button(region)
		btn.position = Vector2(r[0] * board_native.x, r[1] * board_native.y)
		btn.size = Vector2((r[2] - r[0]) * board_native.x, (r[3] - r[1]) * board_native.y)
		overlay.add_child(btn)
	_layout_card_slots()
	_layout_influence_cubes()
	_layout_army_badges()
	_layout_engage_tokens()
	if awaiting == "influence_cell":
		_layout_influence_cells()
	_layout_majority()
	_layout_score_markers()
	_layout_turn_order_markers()
	_layout_round_marker()


## Posa i cubi Influenza sulle caselle stampate di ogni Regione: una casella per
## slot del modello (permanenti sopra la linea, temporanei sotto), colore = potenza.
## Coordinate da board_layout.json -> influence_slots.
func _layout_influence_cubes() -> void:
	var slots: Dictionary = layout.get("influence_slots", {})
	var s := board_native.y * 0.025
	for region in gs.regions:
		var conf: Dictionary = slots.get(region, {})
		if conf.is_empty():
			continue
		var track: InfluenceTrack = gs.regions[region].get("track")
		if track == null:
			continue
		# Influenza permanente: i primi K cubi (quelli INIZIALI di setup) restano sulle
		# caselle colorate in alto (conf.permanent); quelli AGGIUNTI in gioco vanno sulle
		# caselle permanenti vere sotto (conf.permanent_fill). K = influenze iniziali permanenti.
		var k := _starting_perm_count(region)
		_place_perm_cubes(track.perm, conf.get("permanent", []), conf.get("permanent_fill", []), k, s)
		_place_slot_cubes(track.temp, conf.get("temporary", []), s)


## Numero di Influenze INIZIALI permanenti (di setup) della Regione (dai dati board).
func _starting_perm_count(region: String) -> int:
	for r in gs.board_data.get("regions", []):
		if String(r.get("region", "")) == region:
			var k := 0
			for si in r.get("starting_influence", []):
				if String(si.get("slot", "permanent")) == "permanent":
					k += 1
			return k
	return 0


## Posa i cubi permanenti: i primi `k` (iniziali) su `initial_coords` (riga colorata),
## i successivi (aggiunti in gioco) su `fill_coords` (riga permanente sotto).
func _place_perm_cubes(owners: Array, initial_coords: Array, fill_coords: Array, k: int, s: float) -> void:
	for i in owners.size():
		var owner: Variant = owners[i]
		if owner == null:
			continue
		var coords: Array = initial_coords if i < k else fill_coords
		var idx: int = i if i < k else i - k
		if idx < coords.size():
			_draw_cube(coords[idx], owner, s)


func _place_slot_cubes(owners: Array, coords: Array, s: float) -> void:
	for i in owners.size():
		if owners[i] == null or i >= coords.size():
			continue
		_draw_cube(coords[i], owners[i], s)


func _draw_cube(pos: Array, owner: Variant, s: float) -> void:
	var cube := Panel.new()
	cube.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cube.position = Vector2(float(pos[0]) * board_native.x - s * 0.5, float(pos[1]) * board_native.y - s * 0.5)
	cube.size = Vector2(s, s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = POWER_COLORS.get(String(owner), Color(0.8, 0.8, 0.8))
	sb.border_color = Color(0, 0, 0, 0.9)
	sb.set_border_width_all(maxi(1, int(s * 0.14)))
	sb.set_corner_radius_all(int(s * 0.18))
	cube.add_theme_stylebox_override("panel", sb)
	overlay.add_child(cube)


## --- Segnalini sul tabellone: VP (traccia perimetrale) e ordine di turno ---

## Posizione normalizzata (0..1 sul tabellone) di un valore VP sulla traccia
## perimetrale: 0 in alto-sinistra, oraria. Top 0->30, destra 30->50, basso 50->80,
## sinistra 80->100. DA CALIBRARE al pixel se serve.
func _vp_to_pos(vp: int) -> Vector2:
	var v := ((vp % 100) + 100) % 100
	if v <= 30:
		return Vector2(0.022 + (v / 30.0) * 0.955, 0.022)        # top L->R
	elif v <= 50:
		return Vector2(0.978, 0.022 + ((v - 30) / 20.0) * 0.953) # destra T->B
	elif v <= 80:
		return Vector2(0.975 - ((v - 50) / 30.0) * 0.953, 0.975) # basso R->L
	else:
		return Vector2(0.022, 0.975 - ((v - 80) / 20.0) * 0.953) # sinistra B->T


## Segnalino VP per ogni potenza sulla traccia perimetrale (bandiera + numero).
## Potenze con lo stesso VP vengono sfalsate per non sovrapporsi.
func _layout_score_markers() -> void:
	var stack: Dictionary = {}   # vp -> quante già piazzate (per lo sfalsamento)
	for p in gs.players:
		var pos := _vp_to_pos(p.victory_points)
		var n := int(stack.get(p.victory_points, 0)); stack[p.victory_points] = n + 1
		var s := board_native.y * 0.026
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = Vector2(pos.x * board_native.x - s * 0.5, pos.y * board_native.y - s * 0.5 + n * s * 0.7)
		holder.custom_minimum_size = Vector2(s, s)
		var fl := TextureRect.new()
		fl.texture = load("res://assets/flags/%s.png" % p.power)
		fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fl.size = Vector2(s, s)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fl)
		overlay.add_child(holder)


## Segnalino Round: un riquadro evidenziato sulla casella del round corrente nella
## traccia ROUND stampata (coordinate round_slots, indice 0 = round 1).
func _layout_round_marker() -> void:
	var rs: Array = layout.get("round_slots", {}).get("slots", [])
	var idx := gs.round - 1
	if idx < 0 or idx >= rs.size():
		return
	var pos: Array = rs[idx]
	var s := board_native.y * 0.052
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.8, 0.2, 0.30)
	sb.border_color = Color(1.0, 0.85, 0.25, 0.95)
	sb.set_border_width_all(maxi(2, int(board_native.y * 0.004)))
	sb.set_corner_radius_all(int(board_native.y * 0.006))
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(float(pos[0]) * board_native.x - s * 0.5, float(pos[1]) * board_native.y - s * 0.5)
	panel.size = Vector2(s, s)
	overlay.add_child(panel)


## Segnalini ordine di turno nelle 4 caselle 1°-4° sotto il titolo (bandiere).
func _layout_turn_order_markers() -> void:
	for i in gs.turn_order.size():
		if i >= TURN_ORDER_SLOTS.size():
			break
		var seat: int = gs.turn_order[i]
		if seat >= gs.players.size():
			continue
		var power: String = gs.players[seat].power
		var slot: Vector2 = TURN_ORDER_SLOTS[i]
		var s := board_native.y * 0.044
		var fl := TextureRect.new()
		fl.texture = load("res://assets/flags/%s.png" % power)
		fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fl.position = Vector2(slot.x * board_native.x - s * 0.5, slot.y * board_native.y - s * 0.5)
		fl.size = Vector2(s, s)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(fl)


# --- Zoom & pan della mappa (pinch + trascinamento, rotella su desktop) ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			_pinch_dist = _touch_distance()
		return
	# Se è in corso un drag&drop (es. trascinamento di un carro Armata), NON pannare
	# la mappa: il gesto deve spostare il carro, non il tabellone.
	var dragging_dnd := get_viewport().gui_is_dragging()
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			if not dragging_dnd:
				_pan(event.relative)
		elif _touches.size() == 2:
			var d := _touch_distance()
			if _pinch_dist > 0.0:
				_zoom_at(d / _pinch_dist, _touch_midpoint())
			_pinch_dist = d
		return
	if _touches.size() > 0:
		return  # su touch ignoriamo gli eventi mouse emulati
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(1.0 / 1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = event.pressed
	elif event is InputEventMouseMotion and _mouse_dragging and not dragging_dnd:
		_pan(event.relative)


func _touch_distance() -> float:
	var pts := _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2) if pts.size() >= 2 else 0.0


func _touch_midpoint() -> Vector2:
	var pts := _touches.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5 if pts.size() >= 2 else Vector2.ZERO


func _pan(delta: Vector2) -> void:
	if map_content == null:
		return
	_user_adjusted = true
	map_content.position += delta
	_clamp_map()


## Zoom attorno a un punto-schermo mantenendolo fermo.
func _zoom_at(factor: float, focal_screen: Vector2) -> void:
	if map_content == null:
		return
	var focal := focal_screen - map_viewport.position   # coord. locali alla viewport mappa
	var s0: float = map_content.scale.x
	var s1: float = clampf(s0 * factor, _min_zoom, _min_zoom * 6.0)
	if is_equal_approx(s0, s1):
		return
	_user_adjusted = true
	var local := (focal - map_content.position) / s0
	map_content.scale = Vector2(s1, s1)
	map_content.position = focal - local * s1
	_clamp_map()


## Adatta la mappa alla viewport (intera visibile) e centra. Una volta sola.
func _fit_map() -> void:
	if map_content == null or board_native.x <= 0:
		return
	var mv := map_viewport.size
	var fit := minf(mv.x / board_native.x, mv.y / board_native.y)
	_min_zoom = fit
	map_content.scale = Vector2(fit, fit)
	# Mappa allineata a DESTRA (l'eventuale grigio resta a sinistra, accanto alla board);
	# verticalmente centrata.
	map_content.position = Vector2(mv.x - board_native.x * fit, (mv.y - board_native.y * fit) * 0.5)


## Tiene almeno una parte della mappa visibile dopo pan/zoom. Su un asse dove la
## mappa è PIÙ PICCOLA della viewport la centra (altrimenti clampf riceveva min>max
## e rimbalzava la posizione a ogni frame -> sfarfallio durante il pan).
func _clamp_map() -> void:
	if map_content == null:
		return
	var sc: float = map_content.scale.x
	var bw := board_native.x * sc
	var bh := board_native.y * sc
	var mv := map_viewport.size
	var margin := 80.0
	var pos := map_content.position
	var min_x := mv.x - bw - margin
	var min_y := mv.y - bh - margin
	# Se la mappa è più piccola della viewport la teniamo a DESTRA (grigio a sinistra,
	# verso la board); sull'asse Y resta centrata.
	pos.x = mv.x - bw if min_x > margin else clampf(pos.x, min_x, margin)
	pos.y = (mv.y - bh) * 0.5 if min_y > margin else clampf(pos.y, min_y, margin)
	map_content.position = pos


func _make_region_button(region: String) -> Button:
	var awaiting_region := (awaiting in AWAITING_REGION)
	var btn := Button.new()
	# Le Regioni catturano il mouse SOLO quando devi sceglierne una; altrimenti
	# lasciano passare il drag così puoi trascinare/pannare la mappa anche da zoomata.
	btn.mouse_filter = Control.MOUSE_FILTER_STOP if awaiting_region else Control.MOUSE_FILTER_IGNORE
	btn.pressed.connect(_cmd_pick_region.bind(region))
	# Durante un Move la Regione è anche un DROP TARGET del drag&drop dei carri.
	if awaiting == "move":
		btn.set_drag_forwarding(Callable(), _region_can_drop.bind(region), _region_do_drop.bind(region))
	# Zona Regione: invisibile di default (il tabellone mostra già nome ed Eng);
	# si evidenzia solo quando devi SCEGLIERE una Regione. Durante un Move il colore
	# indica il ruolo: verde = sorgente possibile, giallo = sorgente scelta, blu = destinazione.
	var st := StyleBoxFlat.new()
	var role := _move_role(region) if awaiting == "move" else ("pick" if awaiting_region else "")
	# IMPORTANTE: un Button `flat` NON disegna lo stylebox "normal" -> l'evidenziazione
	# sparirebbe. Quindi flat SOLO quando non c'è ruolo (zona trasparente, lascia passare).
	btn.flat = (role == "")
	if role != "":
		match role:
			"source": st.bg_color = Color(0.3, 0.85, 0.4, 0.42); st.border_color = Color(0.4, 1, 0.5, 1)
			"selected": st.bg_color = Color(0.95, 0.8, 0.2, 0.46); st.border_color = Color(1, 0.9, 0.3, 1)
			"dest": st.bg_color = Color(0.2, 0.6, 0.95, 0.42); st.border_color = Color(0.4, 0.9, 1, 1)
			_: st.bg_color = Color(0.2, 0.6, 0.95, 0.42); st.border_color = Color(0.4, 0.9, 1, 1)
		st.set_border_width_all(maxi(4, int(board_native.y * 0.006)))
		st.set_corner_radius_all(6)
	else:
		st.bg_color = Color(0, 0, 0, 0)
	var hv := st.duplicate()
	if role != "":
		hv.bg_color = st.bg_color; hv.bg_color.a = minf(1.0, st.bg_color.a + 0.18)
	for stn in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(stn, hv if stn == "hover" else st)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", int(board_native.y * 0.004))
	btn.add_child(vb)
	return btn


## Pedine Armata schierate nelle Regioni: ogni superpotenza ha la SUA casella
## (4 per Regione, 2x2 stampate). Coordinate da board_layout.json -> army_slots.
func _layout_army_badges() -> void:
	var slots: Dictionary = layout.get("army_slots", {})
	var h := board_native.y * 0.030                 # altezza pedina
	var bw := h * 2.0                               # larghezza pedina (tank ~2:1)
	for region in gs.regions:
		var conf: Dictionary = slots.get(region, {})
		if conf.is_empty():
			continue
		var armies: Dictionary = gs.regions[region].get("armies", {})
		for owner in armies:
			var cnt := int(armies[owner])
			if cnt <= 0 or not conf.has(owner):
				continue
			var pos: Array = conf[owner]
			var x := float(pos[0]) * board_native.x - bw * 0.5
			var y := float(pos[1]) * board_native.y - h * 0.5
			var tank := TextureRect.new()
			tank.texture = load("res://assets/armies/%s.png" % owner)
			tank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tank.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Durante un Move i TUOI carri si possono TRASCINARE (drag source); altrimenti
			# sono solo decorativi e lasciano passare il mouse (pan/zoom della mappa).
			if awaiting == "move" and owner == _active().power:
				tank.mouse_filter = Control.MOUSE_FILTER_STOP
				tank.set_drag_forwarding(_army_drag_data.bind(region), Callable(), Callable())
				tank.tooltip_text = "Trascina un carro (verso una Regione o sulla Riserva)"
			else:
				tank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tank.position = Vector2(x, y)
			tank.size = Vector2(bw, h)
			overlay.add_child(tank)
			if cnt > 1:
				var lbl := Label.new()
				lbl.text = "x%d" % cnt
				lbl.add_theme_color_override("font_color", POWER_COLORS.get(owner, Color.WHITE))
				lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
				lbl.add_theme_constant_override("outline_size", maxi(2, int(h * 0.12)))
				lbl.add_theme_font_size_override("font_size", int(h * 0.62))
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				lbl.position = Vector2(x + bw * 0.72, y - h * 0.04)
				overlay.add_child(lbl)



## Classifica di maggioranza in tempo reale: SOTTO ogni numero della traccia
## maggioranza mostra la BANDIERA della potenza in quella posizione + i PV.
## Dal più alto a sinistra. Le bandiere sono distanziate e centrate sulla traccia.
## Se i permanenti della Regione NON sono tutti pieni la classifica è OPACA (la
## Regione non segna ancora, regolamento pag. 20).
func _layout_majority() -> void:
	var mslots: Dictionary = layout.get("majority_slots", {})
	var fw := board_native.y * 0.026
	var fh := fw * 0.66
	for region in gs.regions:
		var positions: Array = mslots.get(region, [])
		if positions.is_empty():
			continue
		var rd: Dictionary = gs.regions[region]
		var track: InfluenceTrack = rd.get("track")
		if track == null:
			continue
		var ranking: Array = Scoring.region_ranking(track, rd.get("majority_bonus", []), rd.get("armies", {}))
		if ranking.is_empty():
			continue
		var alpha := 1.0 if track.all_permanent_filled() else 0.4
		var n: int = mini(ranking.size(), positions.size())
		# Riga di bandiere distanziata e centrata sulla traccia, posata SOTTO i numeri.
		var pitch_px := (float(positions[1][0]) - float(positions[0][0])) * board_native.x if positions.size() >= 2 else fw * 1.2
		var spacing: float = maxf(pitch_px, fw * 1.18)
		var center_x := 0.0
		for k in n:
			center_x += float(positions[k][0]) * board_native.x
		center_x /= float(n)
		var row_y := float(positions[0][1]) * board_native.y
		var x0 := center_x - spacing * (n - 1) * 0.5
		for i in n:
			var owner: String = ranking[i]["owner"]
			var bonus: int = ranking[i]["bonus"]
			var fx := x0 + i * spacing - fw * 0.5
			var fy := row_y - fh * 0.25    # appena sotto/sul numero stampato (rialzato)
			if owner == "local":
				var disc := Panel.new()
				disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var ds := StyleBoxFlat.new()
				ds.bg_color = Color(0.55, 0.55, 0.58)
				ds.set_corner_radius_all(int(fh))
				disc.add_theme_stylebox_override("panel", ds)
				disc.position = Vector2(x0 + i * spacing - fh * 0.5, fy)
				disc.size = Vector2(fh, fh)
				disc.modulate.a = alpha
				overlay.add_child(disc)
			else:
				var fl := TextureRect.new()
				fl.texture = load("res://assets/flags/%s.png" % owner)
				fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fl.position = Vector2(fx, fy)
				fl.size = Vector2(fw, fh)
				fl.modulate.a = alpha
				overlay.add_child(fl)
			# PV (bonus effettivo) come piccolo numero accanto alla bandiera.
			var lbl := Label.new()
			lbl.text = str(bonus)
			lbl.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, alpha))
			lbl.add_theme_constant_override("outline_size", maxi(2, int(fh * 0.16)))
			lbl.add_theme_font_size_override("font_size", int(fh * 0.85))
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.position = Vector2(x0 + i * spacing + fw * 0.30, fy + fh * 0.05)
			overlay.add_child(lbl)


## Engage token (stretta di mano colorata per potenza) sulle Regioni dove il
## giocatore ha "engaged": posati in fila vicino alla traccia Influenza.
## Token Engage: il PRIMO sul simbolo handshake calibrato (engage_slots); gli extra
## si impilano lateralmente, o SOTTO per americas/europe/central_asia (poco spazio).
func _layout_engage_tokens() -> void:
	var slots: Dictionary = layout.get("engage_slots", {})
	var h := board_native.y * 0.034
	var w := h * 1.47
	var stack_down := ["americas", "europe", "central_asia"]
	for region in gs.regions:
		var pos: Array = slots.get(region, [])
		if pos.is_empty():
			continue
		var bx := float(pos[0]) * board_native.x - w * 0.5
		var by := float(pos[1]) * board_native.y - h * 0.5
		var n := 0
		for p in gs.players:
			if region in p.engage_tokens:
				var tex := load("res://assets/markers/engage_%s.png" % p.power)
				var px := bx if region in stack_down else bx + n * w * 1.05
				var py := by + n * h * 1.05 if region in stack_down else by
				# In Aftermath il token del giocatore di turno è CLICCABILE (scarta per
				# money o Difesa): lo si tocca direttamente sulla mappa.
				if _aftermath_choice_p != null and _aftermath_choice_p == p:
					var btn := Button.new()
					# Niente `flat`: il bordo giallo (evidenziazione del token cliccabile)
					# deve restare visibile, non solo all'hover.
					btn.position = Vector2(px, py)
					btn.size = Vector2(w, h)
					var bst := StyleBoxFlat.new(); bst.bg_color = Color(0, 0, 0, 0)
					bst.set_border_width_all(maxi(2, int(h * 0.14))); bst.border_color = Color(1, 0.95, 0.4, 0.95)
					bst.set_corner_radius_all(4)
					for stn in ["normal", "hover", "pressed", "focus"]:
						btn.add_theme_stylebox_override(stn, bst)
					btn.tooltip_text = "Scarta Engage in %s (money o Difesa)" % region.replace("_", " ")
					var im := TextureRect.new()
					im.texture = tex
					im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					im.mouse_filter = Control.MOUSE_FILTER_IGNORE
					im.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					btn.add_child(im)
					btn.pressed.connect(_on_aftermath_token.bind(p, region))
					overlay.add_child(btn)
				else:
					var tok := TextureRect.new()
					tok.texture = tex
					tok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
					tok.position = Vector2(px, py)
					tok.size = Vector2(w, h)
					overlay.add_child(tok)
				n += 1


## Posa le carte nazione disponibili (immagini originali) nei 2 SLOT designati di
## ogni Regione, centrate sui pallini calibrati (board_layout.json -> card_slots).
func _layout_card_slots() -> void:
	for c in card_layer.get_children():
		c.queue_free()
	var slots: Dictionary = layout.get("card_slots", {})
	for region in slots:
		if region.begins_with("_"):
			continue
		var centers: Array = slots[region]
		if centers.is_empty():
			continue
		# Larghezza carta = distanza tra i 2 slot (carte affiancate come sul tabellone).
		var spacing: float = 0.08
		if centers.size() >= 2:
			spacing = absf(float(centers[1][0]) - float(centers[0][0]))
		var cw: float = spacing * 0.96 * board_native.x
		var ch: float = cw / 0.71
		var avail: Array = region_countries.get(region, {}).get("available", [])
		for i in mini(avail.size(), centers.size()):
			# Niente flyover sulle carte sul tabellone: si leggono zoomando la mappa.
			var card := _country_card_button(avail[i], Vector2(cw, ch), awaiting == "board_country", false)
			card.pressed.connect(_on_country_pressed.bind(avail[i], region))
			card.position = Vector2(float(centers[i][0]) * board_native.x - cw * 0.5, float(centers[i][1]) * board_native.y - ch * 0.5)
			card_layer.add_child(card)


## Carta nazione come immagine originale (campo `art`), senza handler: chi la usa
## collega il proprio (_on_country_pressed sul tabellone, _on_allied_pressed tra gli alleati).
func _country_card_button(cn: Dictionary, sz: Vector2, highlight: bool, with_preview: bool = true) -> Button:
	var b := Button.new()
	b.flat = true
	b.size = sz
	b.custom_minimum_size = sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.4, 1, 0.5) if highlight else Color(0, 0, 0, 0)
	sb.set_border_width_all(int(board_native.y * 0.004) if highlight else 0)
	sb.set_corner_radius_all(int(board_native.y * 0.006))
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)

	var img := TextureRect.new()
	img.texture = load("res://assets/cards/%s" % String(cn.get("art", "")))
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(img)
	# Evidenziazione della SELEZIONE: un bordo brillante SOPRA l'immagine (il bordo
	# della stylebox sarebbe coperto dalla carta). Così si vede subito cosa hai scelto.
	if highlight:
		var hl := Panel.new()
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(0.4, 1.0, 0.5, 0.10)
		hs.set_border_width_all(maxi(3, int(sz.y * 0.045)))
		hs.border_color = Color(0.45, 1.0, 0.55)
		hs.set_corner_radius_all(int(sz.y * 0.03))
		hl.add_theme_stylebox_override("panel", hs)
		b.add_child(hl)
	if with_preview:
		_attach_preview(b, img.texture)
	return b


## Flyover: passando il mouse su una carta ne mostra una versione ingrandita
## al centro dello schermo; uscendo, la nasconde.
func _attach_preview(btn: Control, tex: Texture2D) -> void:
	if tex == null or card_preview == null:
		return
	btn.mouse_entered.connect(func():
		# Anteprima ANCORATA A DESTRA (e più contenuta) così non copre il centro
		# della board né i testi delle scelte nei popup.
		var h: float = minf(size.y * 0.6, 440.0)
		var w: float = h * 0.71
		var margin := 16.0
		card_preview.texture = tex
		card_preview.size = Vector2(w, h)
		card_preview.position = Vector2(size.x - w - margin, (size.y - h) * 0.5)
		card_preview.visible = true)
	btn.mouse_exited.connect(func(): card_preview.visible = false)


## Click su una Country disponibile sul board: target di Improve Relations.
## Solo durante il gioco di una carta con effetto improve_relations: serve sempre
## giocare la carta (niente azione diretta).
func _on_country_pressed(country: Dictionary, region: String) -> void:
	if awaiting == "board_country":
		awaiting = ""
		# La risoluzione (con eventuale sconto) avanza la carta da sé.
		_do_improve_relations(country, region)


func _do_improve_relations(country: Dictionary, region: String) -> void:
	# Prima offri di esaurire nazioni amiche della Regione per scontare il costo,
	# poi risolvi.
	_pick_exhaust_discount(region,
		"Improve Relations con %s (valore %d)" % [country.get("display_name", ""), int(country.get("value", 0))],
		func(chosen: Array): _resolve_improve(country, region, chosen))


func _resolve_improve(country: Dictionary, region: String, chosen: Array) -> void:
	var p := _active()
	var disc := Modifiers.improve_discount(active_mods)
	var values := _values_of(chosen)
	var cost := Actions.improve_relations_cost(int(country.get("value", 0)), values, disc)
	if p.resources.get("diplomacy", 0) < cost:
		_status("Diplomazia insufficiente per Improve Relations con %s (serve %d)." % [country.get("display_name", ""), cost])
		_advance_play()
		return
	if Actions.execute_improve_relations(gs, p.power, country, values, disc):
		for c in chosen:
			p.exhausted[c.get("id", "")] = true   # gli alleati usati per lo sconto si esauriscono
		region_countries.get(region, {}).get("available", []).erase(country)
		_refill_available(region)
		_status("%s: Improve Relations con %s (-%d Dip%s)." % [
			p.power.to_upper(), country.get("display_name", ""), cost,
			", %d alleati esauriti" % chosen.size() if chosen.size() > 0 else ""])
		_after_change()
	_advance_play()


## Click su una Country alleata (davanti al giocatore): target di Invest/Build a
## Base. Solo durante il gioco della carta corrispondente (niente azione diretta).
func _on_allied_pressed(country: Dictionary) -> void:
	var p := _active()
	if awaiting != "allied_country":
		return  # serve giocare la carta Invest/Build a Base
	var name := String(awaiting_op.get("op", ""))
	awaiting = ""
	# L'Influenza di Invest/Build va nella Regione della Country: scegli lo slot.
	var region := String(country.get("region", ""))
	_pick_slot(region, func(slot):
		if name == "invest":
			if Actions.execute_invest(gs, p.power, country, slot) < 0:
				_status("Money insufficiente per Invest in %s (serve %d)." % [country.get("display_name", "?"), int(country.get("invest_cost", 0))])
			_after_change()
			_advance_play()
		elif name == "build_base":
			# Build a Base: muovi da 1 fino al valore del Country (pag. 15), non 1 fisso.
			_pick_base_armies(country, func(n_armies):
				if Actions.execute_build_base(gs, p.power, country, n_armies, slot) < 0:
					_status("Impossibile costruire una Base in %s (money o requisiti)." % country.get("display_name", "?"))
				_after_change()
				_advance_play())
		else:
			_after_change()
			_advance_play())


## Sceglie quante Armate spostare costruendo una Base: da 1 fino al valore del
## Country (limitato dalle Armate in riserva). Con un solo valore possibile salta
## il popup. cb riceve il numero scelto.
func _pick_base_armies(country: Dictionary, cb: Callable) -> void:
	var p := _active()
	var max_n: int = mini(maxi(1, int(country.get("value", 1))), p.armies_available)
	if max_n <= 1:
		cb.call(1)
		return
	var items := []
	for n in range(1, max_n + 1):
		items.append({"label": "%d Armata/e  (costo %d money)" % [n, Actions.build_base_cost(n)], "value": n})
	_show_popup("Quante Armate sposti in %s?" % country.get("display_name", "?"), items,
		func(choice): cb.call(int(choice)))


func _on_region_pressed(region: String) -> void:
	if awaiting == "move":
		_on_move_region(region)
		return
	if awaiting == "reset_influence":
		awaiting = ""
		if gs.regions[region]["track"].reset_temporary(_active().power):
			_status("Influenza temporanea protetta (reset) in %s." % region.replace("_", " "))
		else:
			_status("Niente da resettare in %s." % region.replace("_", " "))
		_layout_overlays()
		_advance_play()
		return
	if awaiting == "convert_influence":
		awaiting = ""
		if gs.regions[region]["track"].convert_temp_to_permanent(_active().power):
			_status("Influenza convertita in permanente in %s." % region.replace("_", " "))
		else:
			_status("Nessuna Influenza temporanea da convertire in %s." % region.replace("_", " "))
		_layout_overlays()
		_refresh()
		return
	if awaiting == "region":
		_resolve_region_op(region)
		return
	# Senza una carta in gioco non si fa nulla: ogni azione richiede di giocare
	# la carta corrispondente dalla mano.


# --- Gioco di una carta ---

## Tocco su una carta della mano: 1° tap = la SELEZIONA (evidenziata); ri-tocco la
## stessa = la GIOCA (azione normale). Niente più popup "Come giochi?": per +10 money
## o per uno Strategic Asset, con la carta selezionata tocchi il gettone 💰10 o la carta
## Strategica nella mano (vedi _on_play_money_token / _on_play_strategic_token).
func _on_hand_card_tap(card: Dictionary) -> void:
	if not playing_card.is_empty() or _plays_left <= 0:
		return
	if _selected_hand_card == card:
		_selected_hand_card = {}
		_cmd_play_card(card)        # 2° tap sulla stessa carta = giocala (via command bus)
		return
	_selected_hand_card = card
	_status("Selezionata '%s': ri-toccala per giocarla, oppure tocca la Moneta +10 o una carta Strategica." % card.get("display_name", "carta"))
	_render_hand()


## Gettone 💰10: con una carta selezionata, la scarta (faccia in giù) per +10 money.
func _on_play_money_token() -> void:
	if not playing_card.is_empty() or _plays_left <= 0:
		return
	if _selected_hand_card.is_empty():
		_status("Prima seleziona una carta dalla mano, poi tocca la Moneta +10 per scartarla e prendere +10 money.")
		return
	var card := _selected_hand_card
	_selected_hand_card = {}
	_play_facedown_money(card)


## Carta Strategica nella mano: con una carta selezionata, la usa come costo (faccia
## in giù) per attivare quello Strategic Asset.
func _on_play_strategic_token(asset: Dictionary) -> void:
	if not playing_card.is_empty() or _plays_left <= 0:
		return
	if _selected_hand_card.is_empty():
		_status("Prima seleziona una carta dalla mano, poi tocca una carta Strategica per attivarla (la carta è il costo).")
		return
	var card := _selected_hand_card
	_selected_hand_card = {}
	_play_strategic_asset(card, asset)


## Carta a faccia in giù per +10 money: la carta va negli scarti, +10 money,
## consuma l'azione del turno.
func _play_facedown_money(card: Dictionary) -> void:
	if not playing_card.is_empty() or _plays_left <= 0:
		return
	var p := _active()
	p.hand.erase(card)
	p.discard.append(card)
	p.money += 10
	_plays_left -= 1
	_status("Carta a faccia in giù: +10 money.")
	_after_change()


## Carta a faccia in giù per attivare un Strategic Asset: la carta di mano è il
## costo (negli scarti), l'asset si usa UNA volta e ne risolve l'effetto.
func _play_strategic_asset(hand_card: Dictionary, asset: Dictionary) -> void:
	if not playing_card.is_empty() or _plays_left <= 0:
		return
	var p := _active()
	if not (asset in p.strategic_assets):
		return
	p.hand.erase(hand_card)
	p.discard.append(hand_card)              # la carta di mano è il costo (faccia in giù)
	p.strategic_assets.erase(asset)
	p.used_strategic_assets.append(asset)    # usabile una volta sola
	_playing_asset = true
	playing_card = asset
	play_queue = (asset.get("effect_ops", []) as Array).duplicate(true)
	active_mods = Modifiers.parse(asset.get("effect_modifiers", []))
	_status("Strategic Asset: %s%s" % [asset.get("display_name", "?"), _mods_text(active_mods)])
	_advance_play()


func _play_card(card: Dictionary) -> void:
	if not playing_card.is_empty():
		return  # gia' in risoluzione
	if _plays_left <= 0:
		_status("Hai già giocato in questo turno. Premi 'Fine turno'.")
		return
	if not card.has("effect_ops"):
		_status("Questa carta non ha effetto giocabile.")
		return
	playing_card = card
	play_queue = (card["effect_ops"] as Array).duplicate(true)
	active_mods = Modifiers.parse(card.get("effect_modifiers", []))
	var mtxt := _mods_text(active_mods)
	_status("Giochi: %s%s" % [card.get("display_name", "carta"), mtxt])
	_advance_play()


## Breve descrizione degli sconti attivi della carta (per la status bar).
func _mods_text(mods: Dictionary) -> String:
	var bits := []
	if Modifiers.improve_discount(mods) > 0:
		bits.append("Improve -%d Dip" % Modifiers.improve_discount(mods))
	if mods.has("engage_discount_per_army"): bits.append("Engage -1/Armata")
	if mods.has("engage_discount_per_allied"): bits.append("Engage -1/alleato")
	if mods.has("engage_discount_1_in"): bits.append("Engage -1 in alcune Regioni")
	if Modifiers.money_for_services(mods) > 0:
		bits.append("paga %d money per Servizio" % Modifiers.money_for_services(mods))
	return "  -  [" + ", ".join(bits) + "]" if bits.size() > 0 else ""


func _advance_play() -> void:
	if play_queue.is_empty():
		_finish_card()
		return
	var op: Dictionary = play_queue.pop_front()
	var name := String(op.get("op", ""))
	match name:
		"add_influence":
			# Bonus Influenza condizionale: salta se la condizione (aver esportato certe
			# risorse nel Trade della carta) non è soddisfatta.
			if _has_cond_influence() and not _cond_influence_ok():
				_status("Nessun bonus Influenza: condizione di Export non soddisfatta.")
				_advance_play()
				return
			# Influenza DIRETTAMENTE sulla mappa: si chiude il cassetto, si evidenziano le
			# caselle valide di TUTTE le Regioni e un click = scelta (Regione + slot).
			var force_slot := "permanent" if bool(op.get("permanent", false)) else ""
			if not _begin_influence_pick(gs.regions.keys(), force_slot, _apply_add_influence):
				_status("Nessuno slot Influenza libero.")
				_advance_play()
		"engage", "place_armies":
			awaiting = "region"
			awaiting_op = op
			_status("Tocca una Regione sulla mappa per: %s" % name)
			_after_change()   # chiude il cassetto: serve la mappa
		"move", "move_free", "move_to_regions":
			_begin_move(op)
		"improve_relations":
			# Seleziona una Country disponibile direttamente sul tabellone.
			awaiting = "board_country"
			awaiting_op = op
			_status("Scegli una Country disponibile sul tabellone (Improve Relations).")
			_after_change()
		"invest", "build_base":
			# Seleziona una Country alleata davanti al giocatore.
			if _eligible_allied(name).is_empty():
				_status("Nessuna Country alleata idonea per %s." % name)
				_advance_play()
				return
			awaiting = "allied_country"
			awaiting_op = op
			_status("Scegli una Country alleata (%s)." % name)
			_after_change()
		"produce":
			if op.has("types"):
				for r in op["types"]: Actions.execute_produce(_active(), String(r))
				_advance_play()
			else:
				_open_produce_ui()                              # Produce multi-traccia con quantità
		"choice", "choose_n":
			_pick_choice(op.get("options", []), func(sub):
				# antepone i sotto-op scelti alla coda
				var subs: Array = sub if sub is Array else [sub]
				for i in range(subs.size() - 1, -1, -1):
					play_queue.push_front(subs[i])
				_advance_play())
		"get_growth":
			_pick_growth()
		"trade":
			if op.has("exports") or op.has("imports"):
				EffectExecutor.run(gs, _active().power, [op])   # trade predefinito dalla carta
				_advance_play()
			else:
				_open_trade_ui()                                # trade generico: scelta interattiva
		"play_another":
			_plays_left += 1   # questa carta concede un gioco extra nel turno
			_advance_play()
		"reset_influence":
			# Proteggi una Influenza temporanea: scegli una Regione dove ne hai.
			var pr := _active()
			var any := false
			for rid in gs.regions:
				if gs.regions[rid]["track"].temp.has(pr.power):
					any = true; break
			if not any:
				_status("Nessuna Influenza temporanea da resettare.")
				_advance_play()
			else:
				awaiting = "reset_influence"
				_status("Tocca una Regione dove hai Influenza temporanea da proteggere (reset).")
				_after_change()
		"increase_production":
			var cnt := int(op.get("count", 1))
			_pick_resource("Aumenta quale Produzione (+%d)?" % cnt, func(rt):
				var pp := _active()
				pp.production[rt] = int(pp.production.get(rt, 0)) + cnt
				_status("Produzione %s +%d." % [RES_LABEL.get(rt, rt), cnt])
				_after_change()
				_advance_play())
		"ready_country":
			var n := int(op.get("n", 1))
			var pr2 := _active()
			var done := 0
			for cid in pr2.exhausted:
				if n <= 0: break
				if bool(pr2.exhausted[cid]):
					pr2.exhausted[cid] = false; n -= 1; done += 1
			_status("Preparate %d Country card." % done)
			_after_change()
			_advance_play()
		"trash":
			_pick_hand_card("Elimina una carta dal gioco (trash):", func(card):
				_active().hand.erase(card)   # rimossa del tutto (non negli scarti)
				_status("Carta eliminata: %s." % card.get("display_name", "?"))
				_after_change()
				_advance_play())
		"discard":
			_do_discard(int(op.get("n", 1)), op.get("then", []))
		"increase_prosperity":
			var pr3 := _active()
			var disc := int(op.get("discount", 0))
			if _increase_prosperity_discounted(pr3, disc):
				_status("Prosperità -> livello %d." % pr3.prosperity_level)
			else:
				_status("Prosperità: Beni di consumo insufficienti.")
			_after_change()
			_advance_play()
		_:
			if name in AUTO_OPS:
				EffectExecutor.run(gs, _active().power, [op])
			_advance_play()


func _resolve_region_op(region: String) -> void:
	var op := awaiting_op
	awaiting = ""
	awaiting_op = {}
	var name := String(op.get("op", ""))
	var p := _active()
	if name == "engage":
		# Offri lo sconto esaurendo alleati della Regione, poi risolvi.
		_pick_exhaust_discount(region,
			"Engage in %s (costo %d Dip)" % [region.replace("_", " "), int(gs.regions[region]["engage_cost"])],
			func(chosen: Array): _resolve_engage(region, chosen))
		return
	match name:
		"place_armies":
			var a: Dictionary = gs.regions[region]["armies"]
			a[p.power] = int(a.get(p.power, 0)) + int(op.get("n", 1))
	_status("%s su %s." % [name, region.replace("_", " ")])
	_layout_overlays()
	_advance_play()


## Slot dove mettere l'Influenza (Engage / Invest / Build a Base): la scelta si fa
## SULLA MAPPA (caselle evidenziate, verde = permanente, viola = temporanea), come per
## add_influence. Se non c'è un permanente libero va diretta in temporaneo. cb riceve
## "permanent" o "temporary".
func _pick_slot(region: String, cb: Callable) -> void:
	if _next_free_perm_pos(region).is_empty():
		cb.call("temporary")     # nessuno slot permanente libero: niente scelta
		return
	_begin_influence_pick([region], "", func(_r: String, slot: String): cb.call(slot))


## Coordinata normalizzata della PROSSIMA casella Influenza permanente libera della
## Regione (riga "permanent_fill" per quelle aggiunte in gioco); [] se nessuna libera.
func _next_free_perm_pos(region: String) -> Array:
	var conf: Dictionary = layout.get("influence_slots", {}).get(region, {})
	var track: InfluenceTrack = gs.regions[region].get("track")
	if track == null:
		return []
	var k := _starting_perm_count(region)
	for i in track.perm.size():
		if track.perm[i] == null:
			var coords: Array = conf.get("permanent_fill", []) if i >= k else conf.get("permanent", [])
			var idx: int = i - k if i >= k else i
			return coords[idx] if idx < coords.size() else []
	return []


## Coordinata normalizzata della PROSSIMA casella Influenza temporanea libera; [] se nessuna.
func _next_free_temp_pos(region: String) -> Array:
	var conf: Dictionary = layout.get("influence_slots", {}).get(region, {})
	var track: InfluenceTrack = gs.regions[region].get("track")
	if track == null:
		return []
	var coords: Array = conf.get("temporary", [])
	for i in track.temp.size():
		if track.temp[i] == null and i < coords.size():
			return coords[i]
	return []


## Avvia la scelta dell'Influenza SULLA MAPPA: chiude il cassetto ed evidenzia le
## caselle valide (verde = permanente, viola = temporanea). `force` può limitare a
## "permanent"/"temporary". cb riceve (region, slot). Ritorna false se nessuna casella.
func _begin_influence_pick(regions: Array, force: String, cb: Callable) -> bool:
	_influence_pick = {"regions": regions, "force": force, "cb": cb}
	awaiting = "influence_cell"
	if _count_influence_cells() == 0:
		_influence_pick = {}
		awaiting = ""
		return false
	_after_change()   # chiude il cassetto: serve la mappa
	_status("Tocca una casella evidenziata per posare l'Influenza (verde = permanente, viola = temporanea).")
	return true


## Quante caselle Influenza valide ci sono per la scelta corrente.
func _count_influence_cells() -> int:
	var n := 0
	var force := String(_influence_pick.get("force", ""))
	for region in _influence_pick.get("regions", []):
		if force != "temporary" and not _next_free_perm_pos(region).is_empty():
			n += 1
		if force != "permanent" and not _next_free_temp_pos(region).is_empty():
			n += 1
	return n


## Disegna le caselle Influenza cliccabili (sopra gli overlay) per la scelta corrente.
func _layout_influence_cells() -> void:
	var force := String(_influence_pick.get("force", ""))
	for region in _influence_pick.get("regions", []):
		if force != "temporary":
			var pp := _next_free_perm_pos(region)
			if not pp.is_empty():
				_add_influence_cell(region, "permanent", pp)
		if force != "permanent":
			var tp := _next_free_temp_pos(region)
			if not tp.is_empty():
				_add_influence_cell(region, "temporary", tp)


func _add_influence_cell(region: String, slot: String, pos: Array) -> void:
	# Caselle più GRANDI e contrastate, così si vedono bene e non si va a tentativi.
	# NB: niente `flat` (un Button flat NON disegnerebbe lo stylebox -> cella invisibile).
	var s := board_native.y * 0.046
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.position = Vector2(float(pos[0]) * board_native.x - s * 0.5, float(pos[1]) * board_native.y - s * 0.5)
	b.size = Vector2(s, s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 1.0, 0.45, 0.62) if slot == "permanent" else Color(1.0, 0.4, 1.0, 0.62)
	sb.border_color = Color(1, 1, 1, 0.95)
	sb.set_border_width_all(maxi(1, int(s * 0.08)))   # cornice SOTTILE
	sb.set_corner_radius_all(int(s * 0.20))
	var hv := sb.duplicate()
	hv.bg_color = Color(0.3, 1.0, 0.55, 0.85) if slot == "permanent" else Color(1.0, 0.5, 1.0, 0.85)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.tooltip_text = "Influenza %s in %s" % ["permanente" if slot == "permanent" else "temporanea", region.replace("_", " ")]
	b.set_meta("influence_cell", {"region": region, "slot": slot})
	b.pressed.connect(_cmd_pick_influence_cell.bind(region, slot))
	overlay.add_child(b)


## Posa l'Influenza scelta sulla mappa (callback di add_influence) e prosegue la carta.
func _apply_add_influence(region: String, slot: String) -> void:
	gs.regions[region]["track"].add(_active().power, slot)
	_status("Influenza (%s) su %s." % [slot, region.replace("_", " ")])
	_layout_overlays()
	_advance_play()


## Click su una casella Influenza: chiude la scelta e applica la callback (region, slot).
func _on_influence_cell(region: String, slot: String) -> void:
	var ip := _influence_pick
	_influence_pick = {}
	awaiting = ""
	var cb: Variant = ip.get("cb")
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call(region, slot)


func _resolve_engage(region: String, chosen: Array) -> void:
	_pick_slot(region, func(slot): _resolve_engage_slot(region, chosen, slot))


func _resolve_engage_slot(region: String, chosen: Array, slot: String) -> void:
	var p := _active()
	var ed := Modifiers.engage_discount(active_mods, gs, p.power, region)
	var values := _values_of(chosen)
	var diplo := p.focus == WO.Focus.DIPLOMATIC
	var cost := Actions.engage_cost(int(gs.regions[region]["engage_cost"]), values, diplo, ed)
	var vp := Actions.execute_engage(gs, p.power, region, values, diplo, slot, ed)
	if vp < 0:
		_status("Diplomazia insufficiente per Engage in %s (serve %d)." % [region.replace("_", " "), cost])
	else:
		for c in chosen:
			p.exhausted[c.get("id", "")] = true   # alleati usati per lo sconto
		_status("%s: Engage in %s (-%d Dip, +%d VP%s)." % [
			p.power.to_upper(), region.replace("_", " "), cost, vp,
			", %d alleati esauriti" % chosen.size() if chosen.size() > 0 else ""])
	_layout_overlays()
	_advance_play()


# --- Sconto diplomatico: esaurisci nazioni amiche della Regione ---

## Somma dei valori delle nazioni scelte (sconto in Diplomazia).
func _values_of(countries: Array) -> Array:
	var out := []
	for c in countries:
		out.append(int(c.get("value", 0)))
	return out


## Nazioni amiche della Regione non ancora esaurite (deduplicate per id): sono i
## candidati per scontare Engage/Improve Relations esaurendole.
func _exhaustable_allies(region: String) -> Array:
	var p := _active()
	var out := []
	var seen := {}
	for c in p.allied_countries:
		var id := String(c.get("id", ""))
		if id in seen or String(c.get("region", "")) != region:
			continue
		if bool(p.exhausted.get(id, false)):
			continue
		seen[id] = true
		out.append(c)
	return out


## Apre un popup per scegliere quali nazioni amiche della Regione esaurire e
## scontare il costo. cb riceve le nazioni scelte (le esaurisce chi risolve, solo
## se l'azione va a buon fine). Senza candidati, chiama subito cb([]).
## Sconto esaurendo alleati: si fa CLICCANDO le carte alleate della Regione nella
## plancia (un click le attiva per lo sconto, un altro le annulla). La barra in alto
## mostra lo sconto e "Conferma" / "Salta". Senza candidati, chiama subito cb([]).
func _pick_exhaust_discount(region: String, title: String, cb: Callable) -> void:
	if _exhaustable_allies(region).is_empty():
		cb.call([])
		return
	_exhaust_sel = {}
	_exhaust_ctx = {"region": region, "title": title, "cb": cb}
	drawer_open = true
	drawer_power = _active().power
	_refresh()
	_show_exhaust_choice_bar()


## Barra scelte per lo sconto: testo con lo sconto corrente + Conferma/Salta.
func _show_exhaust_choice_bar() -> void:
	_clear_choice_bar()
	if _exhaust_ctx.is_empty():
		return
	var region := String(_exhaust_ctx["region"])
	var discount := 0
	for c in _exhaustable_allies(region):
		if bool(_exhaust_sel.get(String(c.get("id", "")), false)):
			discount += int(c.get("value", 0))
	var lab := Label.new()
	lab.text = "%s - tocca le tue nazioni alleate della Regione per scontare:  -%d Dip" % [String(_exhaust_ctx.get("title", "")), discount]
	lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(lab)
	var ok := Button.new(); ok.text = "Conferma sconto"
	ok.add_theme_font_size_override("font_size", _base_fs() + 1)
	ok.pressed.connect(_exhaust_confirm)
	choice_flow.add_child(ok)
	var skip := Button.new(); skip.text = "Salta (nessuno sconto)"
	skip.add_theme_font_size_override("font_size", _base_fs() + 1)
	skip.pressed.connect(_exhaust_skip)
	choice_flow.add_child(skip)
	choice_bar.visible = true
	_layout_ui()


## Toggle di una nazione alleata per lo sconto (click sulla carta).
func _on_exhaust_toggle(cn: Dictionary) -> void:
	var id := String(cn.get("id", ""))
	_exhaust_sel[id] = not bool(_exhaust_sel.get(id, false))
	_refresh()                  # ridisegna le carte (evidenziazione)
	_show_exhaust_choice_bar()  # aggiorna lo sconto in alto


func _exhaust_confirm() -> void:
	var region := String(_exhaust_ctx.get("region", ""))
	var cb: Variant = _exhaust_ctx.get("cb")
	var chosen := []
	for c in _exhaustable_allies(region):
		if bool(_exhaust_sel.get(String(c.get("id", "")), false)):
			chosen.append(c)
	_exhaust_ctx = {}
	_exhaust_sel = {}
	_clear_choice_bar()
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call(chosen)


func _exhaust_skip() -> void:
	var cb: Variant = _exhaust_ctx.get("cb")
	_exhaust_ctx = {}
	_exhaust_sel = {}
	_clear_choice_bar()
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call([])


# --- Move: spostamento libero delle Armate (riserva -> Regione e tra Regioni) ---

## Avvia un Move: il giocatore sceglie una SORGENTE (la Riserva o una Regione con
## sue Armate), poi una Regione di DESTINAZIONE; ripete fino al massimo o "Fine".
## Lo spostamento è libero su qualsiasi Regione (niente adiacenze). "move" paga 5
## money per Armata; le varianti free non pagano.
func _begin_move(op: Dictionary) -> void:
	var name := String(op.get("op", ""))
	var p := _active()
	var max_armies := int(op.get("max", 0))
	if max_armies <= 0:
		max_armies = int(op.get("count", 1)) * int(op.get("per_region", 1))
	var on_board := 0
	for rid in gs.regions:
		on_board += int((gs.regions[rid]["armies"] as Dictionary).get(p.power, 0))
	if p.armies_available <= 0 and on_board <= 0:
		_status("Nessuna Armata da spostare (né in riserva né schierata).")
		_advance_play()
		return
	var allowed: Array = []
	if op.has("region"):
		allowed = [op["region"]]
	elif op.has("regions"):
		allowed = (op["regions"] as Array).duplicate()
	_move_ctx = {
		"free": name != "move",
		"max": maxi(1, max_armies),
		"allowed": allowed,
		"exclude": (op.get("exclude", []) as Array),
		"min": int(op.get("min", 0)),
		"moved": 0,
		"source": null,        # null | "_reserve" | id Regione
	}
	awaiting = "move"
	_after_change()   # mostra la mappa
	_refresh_move_ui()


## Destinazione valida per lo spostamento corrente (rispetta allowed/exclude e
## non coincide con la sorgente).
func _move_valid_dest(region: String) -> bool:
	var c := _move_ctx
	if region in (c.get("exclude", []) as Array):
		return false
	var allowed: Array = c.get("allowed", [])
	if not allowed.is_empty() and not (region in allowed):
		return false
	return region != c.get("source", null)


## Ruolo di una Regione durante un Move (per evidenziarla): sorgente possibile
## (tue Armate, trascinabili), destinazione valida, o sorgente già scelta (tap).
func _move_role(region: String) -> String:
	var c := _move_ctx
	var has_mine: bool = int((gs.regions[region]["armies"] as Dictionary).get(_active().power, 0)) > 0
	# Flusso TAP: una sorgente è già stata scelta toccandola.
	if c.get("source", null) != null:
		if region == c["source"]:
			return "selected"
		return "dest" if _move_valid_dest(region) else ""
	# Drag&drop: evidenzia SEMPRE le sorgenti (tue Armate) e le destinazioni valide,
	# così sai da dove trascinare e dove rilasciare senza prima scegliere la sorgente.
	if has_mine:
		return "source"
	if int(c.get("moved", 0)) < int(c.get("max", 1)) and _move_valid_dest(region):
		return "dest"
	return ""


func _on_move_region(region: String) -> void:
	var c := _move_ctx
	var p := _active()
	if int(c.get("moved", 0)) >= int(c["max"]):
		return
	if c.get("source", null) == null:
		# scelta della sorgente: una Regione con tue Armate
		if int((gs.regions[region]["armies"] as Dictionary).get(p.power, 0)) > 0:
			c["source"] = region
			_refresh_move_ui()
		else:
			_status("Nessuna tua Armata qui. Scegli una Regione con tue Armate o 'Riserva'.")
		return
	# scelta della destinazione
	if region == c["source"]:
		c["source"] = null     # ri-tocco la sorgente = deseleziona
		_refresh_move_ui()
		return
	if not _move_valid_dest(region):
		_status("Destinazione non valida per questo spostamento.")
		return
	_do_move_step(region)


## Esegue lo spostamento di 1 Armata dalla sorgente alla destinazione, pagando il
## costo (per "move"). Resetta la sorgente; chiude se raggiunto il massimo.
func _do_move_step(dest: String) -> void:
	var c := _move_ctx
	var p := _active()
	var src: Variant = c["source"]
	if not bool(c["free"]):
		if p.money < Actions.MOVE_COST:
			_status("Money insufficiente: serve %d per spostare un'Armata." % Actions.MOVE_COST)
			c["source"] = null
			_refresh_move_ui()
			return
		p.money -= Actions.MOVE_COST
	if String(src) == "_reserve":
		p.armies_available -= 1
	else:
		var sa: Dictionary = gs.regions[src]["armies"]
		sa[p.power] = int(sa.get(p.power, 0)) - 1
	var da: Dictionary = gs.regions[dest]["armies"]
	da[p.power] = int(da.get(p.power, 0)) + 1
	c["moved"] = int(c["moved"]) + 1
	c["source"] = null
	var from_txt := 'Riserva' if String(src) == "_reserve" else String(src).replace("_", " ")
	_status("Armata: %s -> %s%s." % [from_txt, dest.replace("_", " "), "" if bool(c["free"]) else "  (-%d money)" % Actions.MOVE_COST])
	if int(c["moved"]) >= int(c["max"]):
		_finish_move()
	else:
		_refresh_move_ui()


func _finish_move() -> void:
	var c := _move_ctx
	if int(c.get("moved", 0)) < int(c.get("min", 0)):
		_status("Devi spostare almeno %d Armate." % int(c["min"]))
		return
	_move_ctx = {}
	awaiting = ""
	_hide_move_bar()
	_layout_overlays()
	_advance_play()


# --- Move via DRAG&DROP (input dell'azione Move): trascini i carri tra Riserva e
# Regioni. Costo/max/validità identici al tap; rientro in Riserva = annulla (gratis,
# non conta nel max). Le bind() di set_drag_forwarding aggiungono gli argomenti IN CODA. ---

## Anteprima (carro) mostrata sotto il dito durante il trascinamento.
func _army_drag_preview() -> Control:
	var prev := TextureRect.new()
	var h := board_native.y * 0.05
	prev.texture = load("res://assets/armies/%s.png" % _active().power)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.custom_minimum_size = Vector2(h * 2.0, h); prev.size = Vector2(h * 2.0, h)
	return prev

## Drag da un'Armata schierata in `region` (solo se è tua e c'è almeno un carro).
func _army_drag_data(_at: Vector2, region: String) -> Variant:
	if awaiting != "move" or int((gs.regions[region]["armies"] as Dictionary).get(_active().power, 0)) <= 0:
		return null
	set_drag_preview(_army_drag_preview())
	return {"move_src": region}

## Drag da un carro della Riserva.
func _reserve_drag_data(_at: Vector2) -> Variant:
	if awaiting != "move" or _active().armies_available <= 0:
		return null
	set_drag_preview(_army_drag_preview())
	return {"move_src": "_reserve"}

## Drop su una Regione: schiera/sposta 1 Armata lì (rispetta max/validità, paga il costo).
func _region_can_drop(_at: Vector2, data: Variant, region: String) -> bool:
	if not (data is Dictionary and (data as Dictionary).has("move_src")):
		return false
	if int(_move_ctx.get("moved", 0)) >= int(_move_ctx.get("max", 1)):
		return false
	if String((data as Dictionary)["move_src"]) == region:
		return false
	return _move_valid_dest(region)

func _region_do_drop(_at: Vector2, data: Variant, region: String) -> void:
	_move_ctx["source"] = String((data as Dictionary)["move_src"])
	_do_move_step(region)   # gestisce costo, trasferimento, moved++, cap e fine

## Drop sul vassoio Riserva: riporta 1 Armata dalla Regione alla Riserva (gratis,
## non conta nel max - annulla lo spostamento).
func _reserve_can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and String((data as Dictionary).get("move_src", "_reserve")) != "_reserve"

func _reserve_do_drop(_at: Vector2, data: Variant) -> void:
	var src := String((data as Dictionary)["move_src"])
	var p := _active()
	var sa: Dictionary = gs.regions[src]["armies"]
	if int(sa.get(p.power, 0)) <= 0:
		return
	sa[p.power] = int(sa.get(p.power, 0)) - 1
	p.armies_available += 1
	_move_ctx["moved"] = maxi(0, int(_move_ctx.get("moved", 0)) - 1)
	_status("Armata: %s -> Riserva (rientro)." % src.replace("_", " "))
	_refresh_move_ui()


## Ridisegna mappa, barra Move e messaggio di stato in base allo stato corrente.
func _refresh_move_ui() -> void:
	_layout_overlays()
	_refresh_move_bar()
	var c := _move_ctx
	_status("Sposta Armate (%d/%d): TRASCINA un carro dalla Riserva o da una Regione su una Regione di destinazione; trascinalo sulla Riserva per farlo rientrare." % [int(c["moved"]), int(c["max"])])


## Barra flottante del Move: vassoio RISERVA (carro trascinabile + drop per i rientri)
## e "Fine spostamento". Niente più scelta della sorgente: si trascina direttamente.
## Controlli del Move nella BARRA SCELTE in alto (non più galleggianti sulla mappa):
## info + vassoio Riserva (drag) + "Fine spostamento" (+ "Annulla" se non hai ancora mosso).
func _refresh_move_bar() -> void:
	_clear_choice_bar()
	var p := _active()
	var c := _move_ctx
	var info := Label.new()
	info.text = "Sposta Armate  %d/%d - trascina i carri (Riserva / mappa - zona / zona)" % [int(c.get("moved", 0)), int(c["max"])]
	info.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(info)
	choice_flow.add_child(_move_reserve_tray(p))
	var done := Button.new()
	done.text = "Fine spostamento"
	done.add_theme_font_size_override("font_size", _base_fs() + 1)
	done.pressed.connect(_finish_move)
	choice_flow.add_child(done)
	if int(c.get("moved", 0)) == 0:
		var cancel := Button.new()
		cancel.text = "Annulla"
		cancel.add_theme_font_size_override("font_size", _base_fs() + 1)
		cancel.pressed.connect(_cancel_card)   # niente mosse fatte: annulla e ridai la carta
		choice_flow.add_child(cancel)
	choice_bar.visible = true
	_layout_ui()


## Vassoio Riserva del Move: un carro TRASCINABILE (schiera dalla riserva) che è anche
## DROP TARGET (trascinaci un carro per farlo rientrare). Mostra "xN".
func _move_reserve_tray(p: PlayerState) -> Control:
	var tray := Panel.new()
	tray.custom_minimum_size = Vector2(118, 40)
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	var ts := StyleBoxFlat.new(); ts.bg_color = Color(0.18, 0.20, 0.25, 0.96)
	ts.set_corner_radius_all(6); ts.set_border_width_all(2); ts.border_color = Color(0.45, 0.8, 1.0, 0.7)
	tray.add_theme_stylebox_override("panel", ts)
	tray.tooltip_text = "Riserva: trascina un carro sulla mappa per schierarlo; trascinaci un carro per farlo rientrare"
	# Drag source (schiera dalla riserva) + drop target (rientro in riserva).
	tray.set_drag_forwarding(_reserve_drag_data, _reserve_can_drop, _reserve_do_drop)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 4)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.add_child(hb)
	if p.armies_available > 0:
		var tank := TextureRect.new()
		tank.texture = load("res://assets/armies/%s.png" % p.power)
		tank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tank.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tank.custom_minimum_size = Vector2(48, 26)
		hb.add_child(tank)
	var lbl := Label.new()
	lbl.text = "Riserva x%d" % p.armies_available
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	hb.add_child(lbl)
	return tray


func _hide_move_bar() -> void:
	_clear_choice_bar()


func _finish_card() -> void:
	var p := _active()
	if not _playing_asset:
		# Carta normale: va negli scarti. Un Strategic Asset NON entra nel mazzo.
		p.hand.erase(playing_card)
		p.played.append(playing_card)
	_playing_asset = false
	playing_card = {}
	_selected_hand_card = {}
	active_mods = {}
	awaiting = ""
	_trade_exported = {}
	_plays_left -= 1
	_status("Carta risolta.")
	_after_change()


# --- Popup di selezione ---

func _pick_country(prompt: String, countries: Array, cb: Callable) -> void:
	if countries.is_empty():
		_status(prompt + " (nessun Country disponibile)")
		_advance_play()
		return
	var items := []
	for cn in countries:
		items.append({"label": "%s (%s)" % [cn.get("display_name", "?"), cn.get("region", "")], "value": cn})
	_show_popup(prompt, items, cb)


## "Get a Growth Card": il giocatore sceglie una Growth del livello idoneo che può
## permettersi (paga il costo in risorse, guadagna i VP). Risolve sul gioco.
## Get a Growth Card: mostra le Growth del livello giusto come CARTE (immagini con
## flyover); le acquistabili sono cliccabili, le altre in grigio (costo non coperto).
func _pick_growth() -> void:
	var p := _active()
	var nl := _next_growth_level(p)
	var avail := _available_growth(p)
	if avail.is_empty():
		_status("Get a Growth Card: nessuna Growth di livello %d disponibile." % nl)
		_advance_play()
		return
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(center)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.08, 0.10, 0.14, 0.99); st.set_corner_radius_all(10); st.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var head := Label.new()
	head.text = "Get a Growth Card - livello %d" % nl
	head.add_theme_font_size_override("font_size", _base_fs() + 2)
	head.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	vb.add_child(head)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var cw := minf(size.x * 0.26, 260.0)
	var chh := cw * 0.42   # le Growth sono carte larghe (wide_aux ~2.5:1)
	for c in avail:
		var afford := p.has_resources(c.get("cost", {}))
		var cell := VBoxContainer.new(); cell.add_theme_constant_override("separation", 2)
		var card := _country_card_button(c, Vector2(cw, chh), false)
		card.disabled = not afford
		if not afford:
			card.modulate = Color(0.5, 0.5, 0.55)
		else:
			card.pressed.connect(_cmd_buy_growth.bind(c, nl))
		cell.add_child(card)
		var info := Label.new()
		info.text = "%s  (+%d VP)" % [_cost_text(c.get("cost", {})), int(c.get("victory_points", 0))]
		info.add_theme_font_size_override("font_size", maxi(10, _base_fs() - 3))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.custom_minimum_size = Vector2(cw, 0)
		cell.add_child(info)
		row.add_child(cell)
	var skip := Button.new(); skip.text = "- Salta -"
	skip.pressed.connect(func(): _close_popup(); _after_change(); _advance_play())
	vb.add_child(skip)


func _buy_growth_action(card: Dictionary, nl: int) -> void:
	var p := _active()
	if Actions.execute_get_growth(p, card, nl):
		_status("Ottenuta Growth: %s (+%d VP)." % [card.get("display_name", "?"), int(card.get("victory_points", 0))])
	_close_popup()
	_after_change()
	_advance_play()


# --- Trade action interattiva (Economic) ---

func _trade_deal(power: String) -> Dictionary:
	for c in trade_deals.get("cards", []):
		if String(c.get("power", "")) == power:
			return c
	return {"exports": 2, "imports": 2, "import_from": {}}


## Quante unità di R puoi esportare: simboli Export sulle nazioni amiche, limitato
## da quanto ne possiedi.
## La carta in gioco ha un modificatore di Influenza condizionale all'Export?
func _has_cond_influence() -> bool:
	return active_mods.has("cond_influence_export_cg_services") or active_mods.has("cond_influence_export_4_energy")


## Condizione soddisfatta in base a quanto esportato nell'ultimo Trade della carta.
func _cond_influence_ok() -> bool:
	if active_mods.has("cond_influence_export_cg_services"):
		if int(_trade_exported.get("consumer_goods", 0)) >= 1 or int(_trade_exported.get("services", 0)) >= 1:
			return true
	if active_mods.has("cond_influence_export_4_energy"):
		if int(_trade_exported.get("energy", 0)) >= 4:
			return true
	return false


func _trade_export_cap(p: PlayerState, R: String) -> int:
	var n := 0
	for c in p.allied_countries:
		n += (c.get("exports", []) as Array).count(R)
	# Modificatori carta: conta certi simboli due volte (Energy Titan, New Energy Markets).
	if R == "energy" and (active_mods.has("count_energy_twice") or active_mods.has("count_energy_or_raw_twice")):
		n *= 2
	elif R == "raw_materials" and active_mods.has("count_energy_or_raw_twice"):
		n *= 2
	return mini(n, int(p.resources.get(R, 0)))


## Simboli Import di R sulle nazioni amiche (import "dal mercato": paghi la banca).
func _trade_allied_import(p: PlayerState, R: String) -> int:
	var n := 0
	for c in p.allied_countries:
		n += (c.get("imports", []) as Array).count(R)
	return n


## Nomi delle Country alleate del giocatore che forniscono l'import di R (per chiarire
## che l'import "banca" passa in realtà dalle proprie nazioni alleate - non da una banca).
func _allied_importer_names(p: PlayerState, R: String) -> Array:
	var names := []
	for c in p.allied_countries:
		if (c.get("imports", []) as Array).has(R):
			names.append(String(c.get("display_name", c.get("id", "?"))))
	return names


## Carte prodotto (Commerce) di una potenza: lista di carte, ognuna è un dizionario
## {risorsa: quantità max vendibile} (USA/Cina/EU 2 carte, Russia 3). Si vende UNA
## risorsa per carta (es. una carta Russia: fino a 3 Energia O 3 Materie Prime).
func _commerce_cards(power: String) -> Array:
	return trade_deals.get("commerce_cards", {}).get(power, [])


## Quante unità di R può vendere `power` in UN trade = capacità della MIGLIORE singola
## carta prodotto scoperta. NON si sommano le carte: per trade se ne gira UNA sola
## (max 3 dalla Russia, +1 Diplomazia). Le altre carte servono per altri trade/giocatori.
func _commerce_faceup_for(power: String, R: String) -> int:
	var flipped: Array = _commerce_flipped.get(power, [])
	var best := 0
	var cards := _commerce_cards(power)
	for i in cards.size():
		if i not in flipped:
			best = maxi(best, int((cards[i] as Dictionary).get(R, 0)))
	return best


## Esaurisce (gira) UNA sola carta prodotto di `power` per vendere R: quella scoperta
## con più R (limite "una carta per trade"). Ritorna le carte girate (0 o 1).
func _commerce_consume(power: String, R: String, _q: int) -> int:
	if not _commerce_flipped.has(power):
		_commerce_flipped[power] = []
	var flipped: Array = _commerce_flipped[power]
	var cards := _commerce_cards(power)
	var best_i := -1
	var best_q := 0
	for i in cards.size():
		if i not in flipped:
			var cq := int((cards[i] as Dictionary).get(R, 0))
			if cq > best_q:
				best_q = cq
				best_i = i
	if best_i >= 0:
		flipped.append(best_i)
		return 1
	return 0


## Gira una qualunque carta prodotto di `power` a faccia in su (Auto-Influence, pag. 18).
func _commerce_flip_any(power: String) -> bool:
	if not _commerce_flipped.has(power):
		_commerce_flipped[power] = []
	var flipped: Array = _commerce_flipped[power]
	var cards := _commerce_cards(power)
	for i in cards.size():
		if i not in flipped:
			flipped.append(i)
			return true
	return false


## Import di R: la quantità importabile è la SOMMA dei simboli Import delle tue Country
## alleate (base, sempre disponibile dalla Riserva) PIÙ quanto vende il GIOCATORE che
## scegli (le sue Commerce card scoperte; +1 Diplomazia comprando da un vero giocatore).
## Le bandiere dei giocatori sono mutuamente esclusive (ne scegli UNA), ma quella scelta
## si AGGIUNGE alla base delle alleate. Ritorna [{src:"reserve"|power, n:int}] dove n è la
## quantità TOTALE importabile con quella scelta (Riserva = solo base; giocatore = base +
## sua vendita).
func _import_sources(p: PlayerState, R: String) -> Array:
	var base := _trade_allied_import(p, R)   # simboli Import delle tue alleate (base)
	var out := []
	# Riserva/Mercato: solo la base delle alleate (default, niente Diplomazia). La mostro
	# solo se hai dei simboli Import (altrimenti importeresti 0 dalla sola Riserva).
	if base > 0:
		out.append({"src": "reserve", "n": base})
	var td := _trade_deal(p.power)
	for other in (td.get("import_from", {}) as Dictionary):
		if not ((td["import_from"][other] as Array).has(R)):
			continue   # la relazione commerciale non include R
		# In 2-3 giocatori si compra anche dalle potenze NEUTRALI: le loro Commerce card
		# si girano comunque; la +1 Diplomazia si ha solo dai veri giocatori.
		var sells := _commerce_faceup_for(other, R)   # quanto vende (carte prodotto scoperte)
		if sells > 0:
			out.append({"src": other, "n": base + sells})   # base alleate + vendita del giocatore
	return out


## Capacità d'import di R = i simboli Import delle tue Country alleate (NON la somma
## delle sorgenti: la Riserva e i venditori sono "da chi", non capacità che si somma).
func _trade_import_cap(p: PlayerState, R: String) -> int:
	return _trade_allied_import(p, R)


func _trade_delta() -> int:
	var d := 0
	for R in (_trade_sel.get("export", {}) as Dictionary):
		d += int(Actions.EXPORT_GAIN.get(R, 0)) * int(_trade_sel["export"][R])
	for R in (_trade_sel.get("import", {}) as Dictionary):
		d -= int(Actions.IMPORT_COST.get(R, 0)) * int(_trade_sel["import"][R])
	d += int(Actions.EXPORT_GAIN.get("armies", 20)) * _trade_armies   # #14: vendita Armate
	return d


## Slot Export occupati = risorse esportate + 1 se stai vendendo Armate (#14).
func _trade_export_used() -> int:
	return (_trade_sel.get("export", {}) as Dictionary).size() + (1 if _trade_armies > 0 else 0)


## Avvia il Commercio: niente popup - si lavora sulla resource track della PLANCIA
## del giocatore (cassetto aperto). Si tocca un prodotto e lo si sposta verso 0
## (vendi) o verso 10 (compra).
func _open_trade_ui() -> void:
	_trade_sel = {"export": {}, "import": {}}
	_trade_import_src = {}
	_trade_active_res = ""
	_trade_armies = 0
	_trade_mode = true
	drawer_open = true
	drawer_power = _active().power
	_refresh()


## Re-render della plancia/cassetto + barra in alto durante il Commercio (dopo ogni scelta).
func _trade_rerender() -> void:
	_refresh()


## Quantità di R offerta da una specifica sorgente ("bank" o un power).
func _trade_src_qty(p: PlayerState, R: String, src: String) -> int:
	for s in _import_sources(p, R):
		if String(s["src"]) == src:
			return int(s["n"])
	return 0


## Sorgente d'import scelta per R (default: la prima disponibile - la banca se c'è).
func _trade_selected_src(p: PlayerState, R: String) -> String:
	if _trade_import_src.has(R):
		var chosen := String(_trade_import_src[R])
		if _trade_src_qty(p, R, chosen) > 0:
			return chosen
	var srcs := _import_sources(p, R)
	return String(srcs[0]["src"]) if not srcs.is_empty() else "reserve"


## Cap d'import di R dalla SOLA sorgente selezionata (così scegli da chi comprare).
func _trade_import_cap_sel(p: PlayerState, R: String) -> int:
	return _trade_src_qty(p, R, _trade_selected_src(p, R))


## Sceglie la sorgente d'import (bandierina) per R e ri-limita la quantità.
func _trade_pick_src(R: String, src: String) -> void:
	_trade_import_src[R] = src
	var p := _active()
	var imp: Dictionary = _trade_sel["import"]
	if imp.has(R):
		imp[R] = mini(int(imp[R]), _trade_src_qty(p, R, src))
		if int(imp[R]) <= 0:
			imp.erase(R)
	_trade_rerender()


func _trade_adjust(R: String, kind: String, delta: int) -> void:
	var p := _active()
	var sel: Dictionary = _trade_sel[kind]
	var other: Dictionary = _trade_sel["import" if kind == "export" else "export"]
	var maxT := int(_trade_deal(p.power).get(kind + "s", 2))
	# Import: cap = base alleate + venditore SELEZIONATO (somma), non solo la base.
	var cap := _trade_export_cap(p, R) if kind == "export" else _trade_import_cap_sel(p, R)
	var newq := clampi(int(sel.get(R, 0)) + delta, 0, cap)
	if newq > 0 and other.has(R):
		return  # una risorsa in una sola transazione (export O import)
	var used := _trade_export_used() if kind == "export" else sel.size()
	if newq > 0 and not sel.has(R) and used >= maxT:
		return  # superato il numero di transazioni della Trade Deals card
	if newq == 0:
		sel.erase(R)
	else:
		sel[R] = newq
	_trade_rerender()


## Regola quante Armate vendere dalla riserva (#14). Aggiungerne occupa uno slot
## Export se non se ne stanno già vendendo.
func _trade_armies_adjust(delta: int) -> void:
	var p := _active()
	var ex_max := int(_trade_deal(p.power).get("exports", 2))
	var newq := clampi(_trade_armies + delta, 0, p.armies_available)
	if newq > 0 and _trade_armies == 0 and (_trade_sel.get("export", {}) as Dictionary).size() >= ex_max:
		return  # nessuno slot Export libero per le Armate
	_trade_armies = newq
	_trade_rerender()


func _trade_confirm() -> void:
	var p := _active()
	_trade_exported = (_trade_sel["export"] as Dictionary).duplicate()  # per i bonus condizionali post-Trade
	for R in (_trade_sel["export"] as Dictionary):
		var q := int(_trade_sel["export"][R])
		p.resources[R] = int(p.resources.get(R, 0)) - q
		p.money += int(Actions.EXPORT_GAIN.get(R, 0)) * q
	# #14: vendita Armate dalla riserva (20 cad., non importabili).
	if _trade_armies > 0:
		var na := mini(_trade_armies, p.armies_available)
		p.armies_available -= na
		p.money += int(Actions.EXPORT_GAIN.get("armies", 20)) * na
	var diplo_eligible := false
	for R in (_trade_sel["import"] as Dictionary):
		var q := int(_trade_sel["import"][R])
		var cost := int(Actions.IMPORT_COST.get(R, 0))
		p.money -= cost * q              # paghi il costo per TUTTE le unità importate
		# La quantità si compone: prima il GIOCATORE scelto (fino a quanto vende), poi la
		# RISERVA (i simboli Import delle tue alleate). Solo il giocatore dà money/Diplomazia.
		var src := _trade_selected_src(p, R)
		if src != "reserve":
			var card_qty := _commerce_faceup_for(src, R)   # quante ne elenca la sua Commerce card
			var from_seller := mini(q, card_qty)           # quante vengono dal venditore
			if from_seller > 0:
				_commerce_consume(src, R, from_seller)   # gira la carta (anche per le neutrali)
				var seller := gs.player_by_power(src)
				if seller != null:
					# Giocatore reale: incassa il money delle SUE unità e prende +1 Servizio.
					seller.money += cost * from_seller
					seller.gain_resource("services", 1, 0)
					# +1 Diplomazia SOLO comprando l'INTERA carta del venditore (es. tutti e 3
					# dalla Russia); comprandone meno giri comunque la carta ma niente Diplomazia.
					if from_seller >= card_qty:
						diplo_eligible = true
				# Potenza neutrale (2-3 giocatori): niente money/Diplomazia.
		# Le unità oltre la vendita del giocatore vengono dalla Riserva (base alleate).
		p.gain_resource(R, q, 0)
	# +1 Diplomazia (una sola, a prescindere dalle transazioni) se hai comprato l'intera
	# carta da almeno un GIOCATORE reale (pag. 13).
	if diplo_eligible:
		p.gain_resource("diplomacy", 1, 0)
	var sold_armies := _trade_armies
	_trade_sel = {}
	_trade_import_src = {}
	_trade_armies = 0
	_trade_mode = false
	_trade_active_res = ""
	_clear_choice_bar()
	if diplo_eligible:
		_status("Commercio completato (comprato da un altro giocatore: +1 Diplomazia).")
	elif sold_armies > 0:
		_status("Commercio completato (vendute %d Armate)." % sold_armies)
	else:
		_status("Commercio completato.")
	_refresh()
	_advance_play()


## Annulla il Commercio in corso (nessuna transazione applicata).
func _trade_cancel() -> void:
	_trade_sel = {}
	_trade_import_src = {}
	_trade_armies = 0
	_trade_mode = false
	_trade_active_res = ""
	_clear_choice_bar()
	# Annullare il Commercio NON consuma la giocata del turno né scarta la carta: la
	# carta resta in mano e puoi giocarne un'altra (_cancel_card, non _advance_play).
	_cancel_card()
	_status("Commercio annullato.")


## Imposta la transazione di R per RAGGIUNGERE la quantità target sulla resource
## track: verso 0 = VENDI (Export), verso 10 = COMPRA (Import). Rispetta i cap e il
## numero di transazioni della Trade Deals card. target == quantità attuale = annulla.
func _trade_set_target(R: String, target: int) -> void:
	var p := _active()
	var qty := int(p.resources.get(R, 0))
	var exp: Dictionary = _trade_sel["export"]
	var imp: Dictionary = _trade_sel["import"]
	exp.erase(R)
	imp.erase(R)
	var ex_max := int(_trade_deal(p.power).get("exports", 2))
	var im_max := int(_trade_deal(p.power).get("imports", 2))
	if target < qty:
		var sell := mini(qty - target, _trade_export_cap(p, R))
		if sell > 0 and _trade_export_used() < ex_max:
			exp[R] = sell
	elif target > qty:
		var buy := mini(target - qty, _trade_import_cap_sel(p, R))
		if buy > 0 and imp.size() < im_max:
			imp[R] = buy
	_trade_active_res = ""   # piazzato: deseleziona (si può ritoccare il prodotto)
	_trade_rerender()



func _pick_resource(prompt: String, cb: Callable) -> void:
	var items := []
	for rt in RES:
		items.append({"label": RES_LABEL[rt], "value": rt})
	_show_popup(prompt, items, cb)


# --- Produce: azione domestica multi-traccia con quantità a scelta ---

## Tipi producibili: tutti quelli con Produzione > 0 sul giocatore attivo.
func _producible_types(p: PlayerState) -> Array:
	var out := []
	for rt in RES:
		if int(p.production.get(rt, 0)) > 0:
			out.append(rt)
	return out


## Produce sulla PLANCIA (niente popup): tocchi le caselle valide sulla resource track
## per impostare quanto produrre (entro la tua Produzione); le Armate con ± nella barra.
func _open_produce_ui() -> void:
	_produce_sel = {}
	_produce_mode = true
	drawer_open = true
	drawer_power = _active().power
	_refresh()


func _produce_rerender() -> void:
	_refresh()


## Imposta quante unità di `rt` produrre (0..Produzione) toccando la casella sulla track.
func _produce_set(rt: String, q: int) -> void:
	var cap := int(_active().production.get(rt, 0))
	var nq := clampi(q, 0, cap)
	if nq <= 0:
		_produce_sel.erase(rt)
	else:
		_produce_sel[rt] = nq
	_produce_rerender()


## Armate da produrre (ognuna consuma 1 Materia Prima), regolate con ±.
func _produce_armies_adjust(delta: int) -> void:
	var p := _active()
	var cap := int(p.production.get("armies", 0))
	var nq := clampi(int(_produce_sel.get("armies", 0)) + delta, 0, cap)
	if nq <= 0:
		_produce_sel.erase("armies")
	else:
		_produce_sel["armies"] = nq
	_produce_rerender()


## Overlay Produce sulla resource track: per ogni risorsa con Produzione, caselle dal
## valore attuale fino a +Produzione (verso 10), col guadagno e l'eventuale costo.
func _add_produce_overlays(area: Control, p: PlayerState, _pw: float, ph: float) -> void:
	for rt in RES_TOKENS:
		var cap := int(p.production.get(rt, 0))
		if cap <= 0:
			continue
		var cur := int(p.resources.get(rt, 0))
		var hi := mini(10, cur + cap)
		var staged := cur + int(_produce_sel.get(rt, 0))
		var req: Dictionary = Actions.SECONDARY_REQ.get(rt, {})
		for i in range(cur, hi + 1):
			var slot := _resource_slot(i)
			var d := ph * 0.135
			var b := Button.new()
			b.anchor_left = slot.x; b.anchor_right = slot.x; b.anchor_top = slot.y; b.anchor_bottom = slot.y
			b.offset_left = -d * 0.78; b.offset_right = d * 0.78; b.offset_top = -d * 0.55; b.offset_bottom = d * 0.55
			b.add_theme_font_size_override("font_size", maxi(8, int(ph * 0.05)))
			var sb := StyleBoxFlat.new(); sb.set_corner_radius_all(3)
			var k := i - cur
			if i == cur:
				sb.bg_color = Color(0.30, 0.30, 0.36, 0.92); b.text = "-"
			else:
				sb.bg_color = Color(0.16, 0.5, 0.28, 0.92)
				b.text = "+%d" % k
				if not req.is_empty():
					var bits := []
					for ck in req:
						bits.append("-%d" % (int(req[ck]) * k))
					b.text += " " + ",".join(bits)
			if i == staged and i != cur:
				sb.set_border_width_all(2); sb.border_color = Color(0.95, 0.85, 0.4)
			b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sb); b.add_theme_stylebox_override("pressed", sb)
			b.pressed.connect(_produce_set.bind(rt, k))
			area.add_child(b)


## Controlli del Produce nella BARRA SCELTE in alto: riepilogo + Armate (±) + Conferma/Annulla.
func _show_produce_bar(p: PlayerState) -> void:
	_clear_choice_bar()
	var info := Label.new()
	info.text = "PRODUCE - tocca le caselle sulla track della plancia (entro la tua Produzione)"
	info.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(info)
	var arm_cap := int(p.production.get("armies", 0))
	if arm_cap > 0:
		var al := Label.new(); al.text = "Armate (-1 Materia cad.):"
		al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_flow.add_child(al)
		var minus := Button.new(); minus.text = "-"; minus.custom_minimum_size = Vector2(34, 0)
		minus.disabled = int(_produce_sel.get("armies", 0)) <= 0
		minus.pressed.connect(_produce_armies_adjust.bind(-1))
		choice_flow.add_child(minus)
		var cnt := Label.new(); cnt.text = "%d/%d" % [int(_produce_sel.get("armies", 0)), arm_cap]
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_flow.add_child(cnt)
		var plus := Button.new(); plus.text = "+"; plus.custom_minimum_size = Vector2(34, 0)
		plus.disabled = int(_produce_sel.get("armies", 0)) >= mini(arm_cap, int(p.resources.get("raw_materials", 0)))
		plus.pressed.connect(_produce_armies_adjust.bind(1))
		choice_flow.add_child(plus)
	var ok := Button.new(); ok.text = "Conferma"; ok.pressed.connect(_produce_confirm)
	choice_flow.add_child(ok)
	var cancel := Button.new(); cancel.text = "Annulla"; cancel.pressed.connect(_produce_cancel)
	choice_flow.add_child(cancel)
	choice_bar.visible = true


func _produce_cancel() -> void:
	_produce_sel = {}
	_produce_mode = false
	_clear_choice_bar()
	_status("Produzione annullata.")
	_cancel_card()


func _produce_confirm() -> void:
	var p := _active()
	var summary := []
	# Primarie prima (così le secondarie possono consumarle).
	for rt in Actions.PRIMARY:
		var q := int(_produce_sel.get(rt, 0))
		if q > 0:
			var made := Actions.execute_produce(p, rt, q)
			if made > 0: summary.append("%s +%d" % [RES_LABEL.get(rt, rt), made])
	# Secondarie (consumano le primarie).
	for rt in ["consumer_goods", "services", "diplomacy"]:
		var q := int(_produce_sel.get(rt, 0))
		if q > 0:
			var made := Actions.execute_produce(p, rt, q)
			if made > 0: summary.append("%s +%d" % [RES_LABEL.get(rt, rt), made])
	# Armate: consumano Materie Prime e vanno nella RISERVA (armies_available).
	var qa := int(_produce_sel.get("armies", 0))
	var made_a := 0
	for _i in qa:
		if int(p.resources.get("raw_materials", 0)) >= 1:
			p.resources["raw_materials"] = int(p.resources.get("raw_materials", 0)) - 1
			p.armies_available += 1
			made_a += 1
	if made_a > 0: summary.append("Armate +%d (riserva)" % made_a)
	_produce_sel = {}
	_produce_mode = false
	_clear_choice_bar()
	_status("Produzione: %s" % (", ".join(summary) if summary.size() > 0 else "niente"))
	_refresh()
	_advance_play()


func _pick_choice(options: Array, cb: Callable) -> void:
	var items := []
	for i in options.size():
		var opt = options[i]
		var lbl := ""
		var flat: Array = opt if opt is Array else [opt]
		for o in flat:
			lbl += String(o.get("op", "")) + " "
		items.append({"label": lbl.strip_edges(), "value": opt})
	_show_popup("Scegli un'opzione:", items, cb)


## Scelta a bottoni nella BARRA SCELTE in alto (niente più popup sopra la board):
## il prompt va nello stato, ogni opzione è un bottone chiaro, più "Annulla".
func _show_popup(prompt: String, items: Array, cb: Callable) -> void:
	_clear_choice_bar()
	_status(prompt)
	var pl := Label.new()
	pl.text = prompt
	pl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(pl)
	for it in items:
		var b := Button.new()
		b.text = String(it["label"])
		b.add_theme_font_size_override("font_size", _base_fs() + 1)
		b.pressed.connect(func():
			_clear_choice_bar()
			cb.call(it["value"]))
		choice_flow.add_child(b)
	var cancel := Button.new()
	cancel.text = "Annulla"
	cancel.pressed.connect(func():
		_clear_choice_bar()
		_cancel_card())
	choice_flow.add_child(cancel)
	choice_bar.visible = true
	_layout_ui()


## Svuota e nasconde la barra scelte (e ridà spazio alla mappa).
func _clear_choice_bar() -> void:
	if choice_flow:
		for c in choice_flow.get_children():
			choice_flow.remove_child(c)
			c.queue_free()
	if choice_bar:
		choice_bar.visible = false
	_layout_ui()


func _close_popup() -> void:
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_choice_bar()


func _cancel_card() -> void:
	playing_card = {}
	play_queue = []
	active_mods = {}
	awaiting = ""
	_move_ctx = {}
	_hide_move_bar()
	_status("Giocata annullata.")
	_after_change()


func _board_countries() -> Array:
	# i Country non ancora alleati di questo giocatore (semplificazione: tutti)
	return all_countries


## Country alleate idonee per l'op data (invest = tutte; build_base = con base).
func _eligible_allied(op_name: String) -> Array:
	var p := _active()
	if op_name == "build_base":
		return p.allied_countries.filter(func(c): return c.get("has_base_symbol", false) and p.power in c.get("base_allowed_powers", []))
	return p.allied_countries


# --- HUD persistente, cassetto (drawer) plancia, mano ---

## Barra superiore sottile sempre visibile: round/potenza, Money/VP/Prosperità,
## Fine turno e una riga di stato. Adatta in altezza al device (_layout_ui).
func _build_hud() -> void:
	top_hud = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.08, 0.11, 0.92)
	top_hud.add_theme_stylebox_override("panel", st)
	add_child(top_hud)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	top_hud.add_child(vb)
	hud_box = HBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 12)
	vb.add_child(hud_box)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	status_label.clip_text = true
	vb.add_child(status_label)
	# Barra delle SCELTE: subito sotto l'HUD, spinge giù la mappa (niente sovrapposizioni).
	choice_bar = Panel.new()
	var cst := StyleBoxFlat.new()
	cst.bg_color = Color(0.10, 0.13, 0.18, 0.98)
	cst.border_color = Color(0.95, 0.8, 0.3, 0.8); cst.set_border_width_all(0); cst.border_width_bottom = 2
	choice_bar.add_theme_stylebox_override("panel", cst)
	choice_bar.visible = false
	choice_bar.clip_contents = true             # niente trabocco sulla mappa/board
	choice_bar.theme = Theme.new()              # font dedicato (più piccolo) per la barra scelte
	add_child(choice_bar)
	var cmargin := MarginContainer.new()
	cmargin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cmargin.add_theme_constant_override("margin_left", 8); cmargin.add_theme_constant_override("margin_right", 8)
	cmargin.add_theme_constant_override("margin_top", 4); cmargin.add_theme_constant_override("margin_bottom", 4)
	choice_bar.add_child(cmargin)
	choice_flow = HFlowContainer.new()
	choice_flow.add_theme_constant_override("h_separation", 8)
	choice_flow.add_theme_constant_override("v_separation", 4)
	cmargin.add_child(choice_flow)


## Cassetto in basso: una scheda per ogni potenza in gioco. Aprendone una si vede
## TUTTA la sua plancia (produzione + alleati + mano) in un'unica vista scrollabile.
func _build_drawer() -> void:
	drawer = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.09, 0.98)
	st.set_corner_radius_all(10)
	drawer.add_theme_stylebox_override("panel", st)
	drawer.visible = false
	add_child(drawer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 10)
	drawer.add_child(margin)
	# Colonna: in alto la plancia+alleati (scrollabile), in basso la MANO fissa
	# (sempre visibile, non scrolla mai via).
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	drawer_content = VBoxContainer.new()
	drawer_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_theme_constant_override("separation", 8)
	scroll.add_child(drawer_content)
	# La MANO è un pannello a TUTTA LARGHEZZA in basso (sopra le linguette), creato a parte
	# (vedi sotto): aperta si SOVRAPPONE a mappa+board, così non comprime le carte della board.

	# Barra delle linguette (bandiere) con sfondo solido, così non si sovrappone
	# alla mappa: è una barra a sé in fondo.
	tab_bg = Panel.new()
	var tbst := StyleBoxFlat.new()
	tbst.bg_color = Color(0.04, 0.05, 0.08, 1.0)
	tab_bg.add_theme_stylebox_override("panel", tbst)
	add_child(tab_bg)
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	add_child(tab_bar)
	for pl in gs.players:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_power_tab.bind(pl.power))
		var fl := TextureRect.new()
		fl.texture = load("res://assets/flags/%s.png" % pl.power)
		fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fl.offset_left = 8; fl.offset_top = 5; fl.offset_right = -8; fl.offset_bottom = -5
		b.add_child(fl)
		# Marcatore "> a chi tocca" (mostrato/nascosto in _refresh_tab_bar).
		var mark := Label.new()
		mark.name = "TurnMark"
		mark.text = ">"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
		mark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		mark.add_theme_constant_override("outline_size", 3)
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		mark.offset_left = 3
		b.add_child(mark)
		tab_bar.add_child(b)
	drawer_power = _active().power

	# Tasto 'Fine turno' FISSO in basso a destra (più comodo dell'angolo in alto): sta
	# sopra tutto (z alto) e viene posizionato in _layout_ui.
	end_turn_btn = Button.new()
	end_turn_btn.text = "Fine turno"
	end_turn_btn.z_index = 50
	end_turn_btn.pressed.connect(_cmd_end_turn)
	add_child(end_turn_btn)

	# Pannello MANO a tutta larghezza, in basso (sopra le linguette). Si SOVRAPPONE sia
	# alla mappa sia alla board quando è aperto (overlay), così non comprime le carte.
	hand_panel = Panel.new()
	var hpst := StyleBoxFlat.new()
	hpst.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	hpst.set_corner_radius_all(8)
	hand_panel.add_theme_stylebox_override("panel", hpst)
	add_child(hand_panel)
	var hpm := MarginContainer.new()
	hpm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		hpm.add_theme_constant_override(m, 6)
	hand_panel.add_child(hpm)
	hand_pinned = VBoxContainer.new()
	hand_pinned.add_theme_constant_override("separation", 2)
	hpm.add_child(hand_pinned)

	# "Board mercato" (Research): un pannello che occupa l'area della MAPPA, così la board
	# del giocatore resta visibile a sinistra mentre compri al Market. Niente più popup.
	market_panel = Panel.new()
	var mkst := StyleBoxFlat.new()
	mkst.bg_color = Color(0.07, 0.09, 0.13, 0.99)
	mkst.set_corner_radius_all(10)
	market_panel.add_theme_stylebox_override("panel", mkst)
	market_panel.visible = false
	add_child(market_panel)
	var mkm := MarginContainer.new()
	mkm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mkm.add_theme_constant_override(m, 12)
	market_panel.add_child(mkm)
	var mkscroll := ScrollContainer.new()
	mkscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mkm.add_child(mkscroll)
	market_content = VBoxContainer.new()
	market_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_content.add_theme_constant_override("separation", 8)
	mkscroll.add_child(market_content)


## Scala font/altezze in base alla viewport reale (responsive). La mappa riempie
## lo schermo dietro; HUD in alto, schede in basso, cassetto nel mezzo.
func _layout_ui() -> void:
	if top_hud == null:
		return
	var w := size.x
	var h := size.y
	ui_theme.default_font_size = _base_fs()
	if status_label:
		status_label.add_theme_font_size_override("font_size", maxi(10, _base_fs() - 4))
	# Barra scelte: font DEDICATO più piccolo, così il testo si adatta alla larghezza.
	if choice_bar and choice_bar.theme:
		choice_bar.theme.default_font_size = _choice_fs()
	# HUD ad ALTEZZA FISSA: la riga (round/potenza/Fine turno) + la riga di stato SOLO
	# quando serve. Quando la barra scelte è visibile, la riga di stato si nasconde e
	# l'HUD si compatta (niente più spazio vuoto, niente doppione con la barra sotto).
	var status_vis: bool = status_label != null and not (choice_bar and choice_bar.visible)
	if status_label:
		status_label.visible = status_vis
	var hud_h := clampf((_base_fs() + 14.0) + (_base_fs() + 6.0 if status_vis else 0.0), 34, 92)
	top_hud.position = Vector2.ZERO
	top_hud.size = Vector2(w, hud_h)
	# Barra scelte SOTTO l'HUD: altezza FISSA per ~2 righe (clip_contents evita il trabocco).
	var choice_h := 0.0
	if choice_bar and choice_bar.visible:
		choice_h = clampf(_choice_fs() * 2.0 + 22.0, 40.0, 74.0)
		choice_bar.position = Vector2(0, hud_h)
		choice_bar.size = Vector2(w, choice_h)
	var tab_h := clampf(h * 0.08, 34, 64)
	tab_bg.position = Vector2(0, h - tab_h)
	tab_bg.size = Vector2(w, tab_h)
	# 'Fine turno' FISSO in basso a destra (comodo); le linguette occupano lo spazio a sinistra.
	var et_w := clampf(w * 0.15, 96.0, 180.0)
	if end_turn_btn:
		end_turn_btn.position = Vector2(w - et_w - 4, h - tab_h + 3)
		end_turn_btn.size = Vector2(et_w, tab_h - 6)
	tab_bar.position = Vector2(4, h - tab_h + 2)
	tab_bar.size = Vector2(w - et_w - 16, tab_h - 4)
	# NUOVO LAYOUT: pannello BOARD a SINISTRA, mappa a DESTRA (finestra separata, sempre
	# visibile). Così zoomando la mappa la board non si ingrandisce e non serve collassarla.
	# In basso si riserva una barra MANO (sopra le linguette); aperta, la mano si espande
	# verso l'alto SOVRAPPONENDOSI a mappa+board (overlay), senza comprimerle.
	var content_top := hud_h + choice_h
	var bar_h := _base_fs() * 2.4
	var content_h := maxf(1.0, h - content_top - tab_h - bar_h)
	var board_w := _board_w()
	drawer.visible = true
	drawer.position = Vector2(0, content_top)
	drawer.size = Vector2(board_w, content_h)
	map_viewport.position = Vector2(board_w, content_top)
	map_viewport.size = Vector2(maxf(1.0, w - board_w), content_h)
	# "Board mercato" (Research): occupa l'area della mappa; la board resta a sinistra.
	var in_research: bool = _ui_phase == "Research"
	if market_panel:
		market_panel.visible = in_research
		if in_research:
			market_panel.position = Vector2(board_w, content_top)
			market_panel.size = Vector2(maxf(1.0, w - board_w), h - content_top - tab_h)
	# Pannello MANO a tutta larghezza, ancorato in basso (sopra le linguette). Durante la
	# Research è nascosto (non si giocano carte: c'è la board mercato).
	if hand_panel:
		hand_panel.visible = not in_research
		var hand_open: bool = hand_box != null and is_instance_valid(hand_box)
		var hand_h := (_hand_card_height() + bar_h + 18.0) if hand_open else bar_h
		hand_h = clampf(hand_h, bar_h, h - content_top - tab_h)
		hand_panel.position = Vector2(0, h - tab_h - hand_h)
		hand_panel.size = Vector2(w, hand_h)
	# Finché l'utente non zooma/panna a mano, la mappa si ri-adatta (centrata) alla
	# viewport corrente ad ogni layout: così riempie sempre lo spazio disponibile.
	if not _user_adjusted and size.x > 0 and size.y > 0:
		_fit_map()
	else:
		_clamp_map()


## Dimensione font base proporzionale all'altezza del device.
func _base_fs() -> int:
	return clampi(int(size.y * 0.026), 11, 26)


## Font (più piccolo) della BARRA SCELTE: così testo e bottoni si adattano alla larghezza
## senza traboccare su più righe.
func _choice_fs() -> int:
	return clampi(int(size.y * 0.020), 10, 17)


## Larghezza della colonna BOARD (a sinistra). La mappa è "letterboxed": a parità d'altezza
## occupa solo board_native.x/board_native.y dello spazio orizzontale e lascia del "grigio"
## ai lati. Quel grigio lo RECUPERIAMO per la board (e le sue carte, che si adattano),
## tenendo la mappa grande e allineata a destra. Funzione PURA di `size`, così _layout_ui,
## _plancia_height e _build_allies_section restano sincronizzati.
func _board_w() -> float:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0 or board_native.y <= 0.0:
		return clampf(w * 0.42, 300.0, w * 0.56)
	# Altezza STABILE riservata alla mappa (ignora la barra scelte, che va e viene: così la
	# larghezza della board non "salta" quando la barra appare o sparisce).
	var hud_h := clampf((_base_fs() + 14.0) + (_base_fs() + 6.0), 34.0, 92.0)
	var tab_h := clampf(h * 0.08, 34.0, 64.0)
	var bar_h := _base_fs() * 2.4
	var map_h := maxf(1.0, h - hud_h - tab_h - bar_h)
	var map_natural_w := board_native.x * (map_h / board_native.y)
	return clampf(w - map_natural_w, w * 0.42, w * 0.56)


func _on_power_tab(power: String) -> void:
	# Il pannello board è SEMPRE visibile: la linguetta sceglie solo QUALE board mostrare.
	drawer_open = true
	drawer_power = power
	_refresh()


## Apertura/chiusura automatica: chiuso quando si deve toccare la mappa; aperto
## sulla propria plancia quando serve scegliere un Country alleato.
func _update_drawer_state() -> void:
	# NUOVO LAYOUT: il pannello board è SEMPRE visibile a fianco della mappa (non si
	# collassa più). Mostra la potenza scelta con le linguette, di default il giocatore
	# di turno; durante Commercio/Produce/sconto/Preparazione torna sul giocatore attivo.
	drawer_open = true
	if _aftermath_choice_p != null:
		drawer_power = _aftermath_choice_p.power
		return
	if _trade_mode or _produce_mode or not _exhaust_ctx.is_empty() \
			or (_ui_phase == "Preparazione" and _prep_idx < gs.players.size()) \
			or awaiting == "allied_country" or awaiting in AWAITING_MAP:
		drawer_power = _active().power


func _refresh() -> void:
	ui_theme.default_font_size = _base_fs()
	var p := _active()
	_update_drawer_state()
	_refresh_hud(p)
	_refresh_tab_bar()
	# La plancia (board_bg) viene ricreata con la texture giusta in _build_plancia_view
	# quando il cassetto è aperto; da chiuso non serve toccarla (il nodo è già liberato).
	_refresh_drawer_content()
	# Barre di scelta a contenuto DETERMINISTICO (dipendono solo dallo stato): Commercio
	# e Produce si (ri)costruiscono qui in alto. L'Aftermath e le sotto-scelte gestiscono
	# la propria barra a parte (per non sovrascrivere una sotto-scelta in corso).
	if _trade_mode:
		_show_trade_bar(p)
	elif _produce_mode:
		_show_produce_bar(p)
	_layout_ui()


func _refresh_hud(p: PlayerState) -> void:
	for c in hud_box.get_children():
		c.queue_free()
	var my_turn := (round_turn_count / gs.players.size()) + 1
	# Barra snella: round + fase + indicatore di TURNO (a chi tocca, nel suo colore) +
	# denaro + Fine turno. VP sui segnalini del tabellone; Prosperità sulla plancia.
	var rl := Label.new()
	rl.text = ("Round %d/6 - Azione %d/4" % [gs.round, mini(my_turn, 4)]) if _ui_phase == "Azione" else ("Round %d/6 - %s" % [gs.round, _ui_phase])
	rl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	hud_box.add_child(rl)
	# Indicatore di turno BEN VISIBILE: > + potenza nel suo colore.
	var turn := Label.new()
	turn.text = "> %s" % p.power.to_upper()
	turn.add_theme_font_size_override("font_size", _base_fs() + 3)
	turn.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	turn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	turn.add_theme_constant_override("outline_size", 3)
	hud_box.add_child(turn)
	hud_box.add_child(_money_widget(p.money))
	# Il tasto 'Fine turno' NON sta più nell'HUD (angolo alto-destra scomodo): è un tasto
	# fisso in BASSO a destra (vedi end_turn_btn in _layout_ui). Qui ne aggiorno lo stato.
	if end_turn_btn:
		end_turn_btn.disabled = game_over or not playing_card.is_empty() or _ui_phase != "Azione"


## Maniglie: una per potenza, colorate; > = a chi tocca, ▼ = cassetto aperto.
func _refresh_tab_bar() -> void:
	var map_lock: bool = awaiting in ["region", "board_country", "move", "convert_influence", "reset_influence"]
	for i in tab_bar.get_child_count():
		var b: Button = tab_bar.get_child(i)
		var pl: PlayerState = gs.players[i]
		var is_open: bool = drawer_open and drawer_power == pl.power
		var is_active: bool = pl.power == _active().power
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.12, 0.16, 1.0)
		sb.set_corner_radius_all(6)
		if is_open:
			sb.border_color = Color(1, 0.85, 0.3); sb.set_border_width_all(3)
		elif is_active:
			sb.border_color = POWER_COLORS.get(pl.power, Color.WHITE); sb.set_border_width_all(3)
		else:
			sb.border_color = Color(0.3, 0.3, 0.35); sb.set_border_width_all(1)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.disabled = map_lock
		var mark: Node = b.get_node_or_null("TurnMark")
		if mark:
			(mark as Label).visible = is_active


## Vista completa della plancia di una potenza: intestazione, Focus (solo per il
## giocatore di turno), produzioni/risorse, Prosperità, alleati e mano.
func _refresh_drawer_content() -> void:
	for c in drawer_content.get_children():
		c.queue_free()
	if hand_pinned:
		for c in hand_pinned.get_children():
			c.queue_free()
	if not drawer_open:
		return
	var p := gs.player_by_power(drawer_power)
	if p == null:
		return
	var is_active := (drawer_power == _active().power)
	# I controlli di Commercio/Produce NON stanno più sulla plancia: sono nella barra
	# scelte in alto (_show_trade_bar / _show_produce_bar). Qui resta solo la plancia
	# interattiva (track risorse) da toccare/trascinare.

	# Pannello board IN COLONNA (dall'alto): plancia · carta Commercio + carte prodotto ·
	# carte nazione alleate · carte crescita. La mano resta in basso (hand_pinned).
	var colv := VBoxContainer.new()
	colv.add_theme_constant_override("separation", 8)
	colv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_child(colv)
	# 1) Riga in alto: PLANCIA (sinistra) + carta COMMERCIO con le carte prodotto sotto
	#    (destra), allineate in alto.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	colv.add_child(top)
	top.add_child(_build_plancia_view(p, is_active))
	_build_commerce_section(p, is_active, top)
	# 2) Carte nazione alleate in FILA (almeno 6 per riga, le altre vanno a capo).
	_build_allies_section(p, is_active, colv)
	# 3) Carte crescita (riga ancora sotto, quando acquistate).
	_build_growth_section(p, is_active, colv)
	_build_ongoing_section(p, is_active)
	# La MANO (pannello full-width in basso) è SEMPRE quella del giocatore di turno,
	# indipendentemente da quale board si sta guardando con le linguette.
	_build_hand_section(_active(), true)


## Rapporto altezza/larghezza delle immagini plancia (~700x499).
const PLANCIA_RATIO := 0.713
## Passo orizzontale tra due caselle di un tracciato Produzione (normalizzato).
## Calibrato dai template utente (game/assets/calibration/plance/, 2026-06-21).
const PROD_PITCH := 0.0510
## [x della casella 1, y] normalizzati, MISURATI sui template di calibrazione
## sovrapposti alle plance reali. Le 4 plance condividono il layout: la lunghezza
## dei tracciati cambia ma le caselle partono dalle stesse coordinate, quindi:
## x = x0 + (livello-1)*passo. UNICA eccezione: il tracciato raw_materials parte da
## x diversa per potenza (vedi RAW_MATERIALS_X). NB: la riserva carri/Armate in alto
## (RESERVE_ARMY_POS) NON è qui e resta invariata; "armies" qui è la PRODUZIONE armate.
const PROD_TRACKS := {
	"energy": [0.0931, 0.1986],
	"raw_materials": [0.4435, 0.1986],
	"food": [0.7372, 0.1986],
	"consumer_goods": [0.0937, 0.5048],
	"services": [0.0937, 0.5925],
	"diplomacy": [0.4073, 0.5212],
	"armies": [0.7378, 0.5212],
}
## Il tracciato raw_materials è stampato in posizioni leggermente diverse per potenza:
## x della casella 1 misurata dai template (override di PROD_TRACKS["raw_materials"][0]).
const RAW_MATERIALS_X := {"usa": 0.4441, "russia": 0.4429, "china": 0.4039, "eu": 0.4054}
## Cerchi Focus (Domestic, Diplomatic, Military).
const FOCUS_POS := [[0.2846, 0.3171], [0.6012, 0.3171], [0.9299, 0.3171]]
## Tracciato Prosperità: livello 0 (cerchio iniziale) .. 5 (corone con i valori).
const PROSPERITY_POS := [[0.4810, 0.6227], [0.5734, 0.6227], [0.6677, 0.6227], [0.7601, 0.6227], [0.8514, 0.6227], [0.9444, 0.6227]]
## Colonne x della traccia RESOURCES (numeri 1..5 in alto, 6..10 in basso).
const RES_TRACK_X := [0.2332, 0.3985, 0.5662, 0.7305, 0.8985]
## Risorse che hanno un token-immagine (armies è un tracciato a parte).
const RES_TOKENS := ["energy", "raw_materials", "food", "consumer_goods", "services", "diplomacy"]


## Costruisce la vista plancia: immagine reale a piena visibilità + segnalini
## (Produzione per ogni risorsa, Risorse possedute, Prosperità).
## Aree cliccabili dei 3 Focus sulla plancia: [x0,x1] per colonna, y [y0,y1].
const FOCUS_ZONES := [[0.02, 0.33], [0.34, 0.66], [0.67, 0.99]]


## Altezza della plancia: condivide la riga in alto con la carta Commercio (a destra),
## quindi occupa ~64% della larghezza del pannello board; tetto proporzionale e assoluto.
func _plancia_height() -> float:
	var board_w := _board_w()
	return minf(minf((board_w * 0.64 - 16.0) * PLANCIA_RATIO, size.y * 0.40), 420.0)


func _build_plancia_view(p: PlayerState, is_active: bool) -> Control:
	# La plancia ha un TETTO ASSOLUTO in pixel (come le carte) così non diventa mai
	# gigante, qualunque sia la dimensione/densità della finestra; più i limiti
	# proporzionali (larghezza disponibile e frazione d'altezza).
	var ph := _plancia_height()
	var pw := ph / PLANCIA_RATIO
	var view := Control.new()
	view.custom_minimum_size = Vector2(pw, ph)
	view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Area interna a DIMENSIONE FISSA (pwxph) col rapporto reale dell'immagine: tutti
	# i segnalini si ancorano qui, così la plancia non si deforma mai anche se il
	# contenitore prova a stirarla.
	var area := Control.new()
	area.custom_minimum_size = Vector2(pw, ph)
	area.size = Vector2(pw, ph)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(area)
	board_bg = TextureRect.new()
	board_bg.texture = load("res://assets/player_boards/%s.jpg" % p.power)
	# Full-rect dell'area (pwxph, rapporto reale): segue l'area senza deformarsi.
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_bg.stretch_mode = TextureRect.STRETCH_SCALE
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(board_bg)
	# Zone Focus cliccabili (solo per il giocatore di turno): toccando la colonna si sposta
	# la pedina del Focus lì. In PREPARAZIONE le colonne sono EVIDENZIATE (bordo dorato):
	# è lì che si sceglie il Focus, cliccando direttamente sulla plancia.
	if is_active:
		var in_prep: bool = (_ui_phase == "Preparazione" and _prep_idx < gs.players.size())
		for f in FOCUS_ZONES.size():
			var fb := Button.new()
			fb.flat = not in_prep   # in preparazione NON flat, così l'evidenziazione si vede
			fb.anchor_left = FOCUS_ZONES[f][0]; fb.anchor_right = FOCUS_ZONES[f][1]
			fb.anchor_top = 0.27; fb.anchor_bottom = 0.67
			var fst := StyleBoxFlat.new()
			if in_prep:
				fst.bg_color = Color(0.95, 0.8, 0.2, 0.16)
				fst.set_border_width_all(maxi(2, int(ph * 0.012))); fst.border_color = Color(1.0, 0.85, 0.3, 0.95)
				fst.set_corner_radius_all(6)
				fb.tooltip_text = "Scegli Focus %s" % FOCUS_NAME[f]
			else:
				fst.bg_color = Color(0, 0, 0, 0)
			fb.add_theme_stylebox_override("normal", fst)
			var fhv := fst.duplicate(); fhv.bg_color = Color(0.95, 0.8, 0.2, 0.34) if in_prep else Color(1, 1, 1, 0.10)
			fb.add_theme_stylebox_override("hover", fhv); fb.add_theme_stylebox_override("pressed", fhv)
			fb.pressed.connect(_cmd_choose_focus.bind(f))
			area.add_child(fb)
	var col: Color = POWER_COLORS.get(p.power, Color.WHITE)
	# Cubi di Produzione: uno sul livello attuale di ogni tracciato.
	for res in PROD_TRACKS:
		var lvl := int(p.production.get(res, 0))
		if lvl >= 1:
			var t: Array = PROD_TRACKS[res]
			# raw_materials parte da x diversa per potenza (traccia stampata altrove).
			var x0: float = RAW_MATERIALS_X.get(p.power, t[0]) if res == "raw_materials" else t[0]
			_add_cube(area, x0 + (lvl - 1) * PROD_PITCH, t[1], pw, ph, col, false)
	# Marker Focus (sul cerchio della colonna scelta).
	if p.focus >= 0 and p.focus < FOCUS_POS.size():
		_add_cube(area, FOCUS_POS[p.focus][0], FOCUS_POS[p.focus][1], pw, ph, col, true)
	# Marker Prosperità.
	var pl := clampi(p.prosperity_level, 0, PROSPERITY_POS.size() - 1)
	_add_cube(area, PROSPERITY_POS[pl][0], PROSPERITY_POS[pl][1], pw, ph, Color(0.45, 0.95, 0.55), true)
	# Token risorsa (immagini reali) sulla traccia RESOURCES 0..10, alla quantità.
	# Durante il Commercio i prodotti commerciabili stanno alla posizione "staged"
	# (quantità ± transazione in corso), così vedi il token muoversi verso 0/10.
	var trading := is_active and _trade_mode
	var producing := is_active and _produce_mode
	var stack: Dictionary = {}
	for res in RES_TOKENS:
		# Durante il Commercio i prodotti commerciabili sono TOKEN CLICCABILI (li disegna
		# _add_trade_overlays): qui li salto per non disegnarli due volte.
		if trading and res in TRADE_RES:
			continue
		var amt := int(p.resources.get(res, 0))
		if producing:
			amt = mini(10, amt + int(_produce_sel.get(res, 0)))   # token mostrato alla quantità prodotta
		var slot := _resource_slot(amt)
		var n := int(stack.get(amt, 0))
		stack[amt] = n + 1
		_add_token(area, res, slot.x, slot.y, pw, ph, n)
	# Riserva Armate (pedine tank) in alto sulla plancia.
	_add_reserve_armies(area, p, ph)
	# Commercio / Produzione: overlay interattivo sulla resource track della plancia.
	if trading:
		_add_trade_overlays(area, p, pw, ph)
	elif producing:
		_add_produce_overlays(area, p, pw, ph)
	return view


## Seleziona il prodotto da commerciare (mostra le sue caselle valide sulla track).
func _trade_select_res(res: String) -> void:
	_trade_active_res = res
	_trade_rerender()


## Tocco sull'icona di una casella: SELEZIONA il prodotto (va in primo piano). Ri-toccando,
## se la casella ne contiene più d'uno passa al successivo; dopo l'ultimo DESELEZIONA.
func _trade_cycle_select(group: Array) -> void:
	if group.is_empty():
		return
	if _trade_active_res in group:
		var i: int = group.find(_trade_active_res)
		if i + 1 < group.size():
			_trade_active_res = String(group[i + 1])   # prossimo prodotto della casella
		else:
			_trade_active_res = ""                       # era l'ultimo -> deseleziona
	else:
		_trade_active_res = String(group[0])
	_trade_rerender()


# --- Drag&drop (iterazione 2, sopra al tap): trascini il token risorsa sulla
# track e lo rilasci su una casella valida. Usa il drag&drop nativo di Godot
# (set_drag_forwarding) - niente calcolo manuale del puntatore. ---

## Inizio trascinamento di un token risorsa: arma il prodotto (così compaiono le
## caselle valide come bersagli di rilascio) e mostra un'anteprima sotto il dito.
func _trade_drag_begin(_at_position: Vector2, res: String) -> Variant:
	_trade_active_res = res
	var prev := TextureRect.new()
	var d := board_native.y * 0.06
	prev.texture = load("res://assets/tokens/%s.png" % res)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.custom_minimum_size = Vector2(d, d); prev.size = Vector2(d, d)
	set_drag_preview(prev)
	_trade_rerender.call_deferred()   # ridisegna: appaiono le caselle valide (drop target)
	return {"trade_res": res}


## Si può rilasciare su una casella solo il token dello stesso prodotto.
func _trade_can_drop(_at_position: Vector2, data: Variant, R: String) -> bool:
	return data is Dictionary and String((data as Dictionary).get("trade_res", "")) == R


## Rilascio su una casella i: imposta la transazione per raggiungere quella quantità.
func _trade_do_drop(_at_position: Vector2, _data: Variant, R: String, i: int) -> void:
	_trade_set_target(R, i)


## Commercio sulla resource track: ogni prodotto è la sua ICONA (token) cliccabile -
## niente cerchi/anelli. Toccando l'icona la SELEZIONI (si illumina e va in primo piano);
## ri-toccando, se la casella ha più prodotti passi al successivo, altrimenti la deselezioni.
## Con un prodotto selezionato puoi TRASCINARLO o toccare una casella per spostarlo lì.
func _add_trade_overlays(area: Control, p: PlayerState, pw: float, ph: float) -> void:
	var exp: Dictionary = _trade_sel.get("export", {})
	var imp: Dictionary = _trade_sel.get("import", {})
	# Raggruppa i prodotti per CASELLA (stessa quantità "staged" -> stessa casella).
	var by_slot := {}   # amt -> [res...]
	for res in TRADE_RES:
		var amt := int(p.resources.get(res, 0)) - int(exp.get(res, 0)) + int(imp.get(res, 0))
		if not by_slot.has(amt):
			by_slot[amt] = []
		(by_slot[amt] as Array).append(res)
	var ts := ph * 0.12   # dimensione del token-icona
	for amt in by_slot:
		var group: Array = by_slot[amt]
		var slot := _resource_slot(int(amt))
		var front := String(_trade_active_res) if _trade_active_res in group else ""
		# Ordine di disegno: il prodotto in primo piano (selezionato) per ULTIMO = in cima.
		var ordered := []
		for res in group:
			if res != front:
				ordered.append(res)
		if front != "":
			ordered.append(front)
		for idx in ordered.size():
			var res := String(ordered[idx])
			var is_front := (res == front)
			var off := idx * ts * 0.5
			# Evidenziazione: un alone dorato DIETRO l'icona selezionata (solo l'icona).
			if is_front:
				var halo := Panel.new()
				halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
				halo.anchor_left = slot.x; halo.anchor_right = slot.x; halo.anchor_top = slot.y; halo.anchor_bottom = slot.y
				halo.offset_left = -ts * 0.62 + off; halo.offset_right = ts * 0.62 + off
				halo.offset_top = -ts * 0.62; halo.offset_bottom = ts * 0.62
				var hs := StyleBoxFlat.new(); hs.bg_color = Color(1.0, 0.85, 0.3, 0.30)
				hs.set_corner_radius_all(int(ts)); hs.set_border_width_all(maxi(2, int(ts * 0.12))); hs.border_color = Color(1.0, 0.85, 0.3, 0.95)
				halo.add_theme_stylebox_override("panel", hs)
				area.add_child(halo)
			var tok := TextureRect.new()
			tok.texture = load("res://assets/tokens/%s.png" % res)
			tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tok.anchor_left = slot.x; tok.anchor_right = slot.x; tok.anchor_top = slot.y; tok.anchor_bottom = slot.y
			tok.offset_left = -ts * 0.5 + off; tok.offset_right = ts * 0.5 + off
			tok.offset_top = -ts * 0.5; tok.offset_bottom = ts * 0.5
			if not is_front and front != "":
				tok.modulate = Color(0.6, 0.6, 0.65)   # le non in primo piano si oscurano
			area.add_child(tok)
		# Area cliccabile sopra la pila (trasparente): seleziona/cicla; se selezionata, trascina.
		var btn := Button.new()
		btn.flat = true
		btn.anchor_left = slot.x; btn.anchor_right = slot.x; btn.anchor_top = slot.y; btn.anchor_bottom = slot.y
		var w := ts * (0.5 + 0.5 * ordered.size())
		btn.offset_left = -ts * 0.5; btn.offset_right = w; btn.offset_top = -ts * 0.6; btn.offset_bottom = ts * 0.6
		var labels := []
		for res in group:
			labels.append(RES_LABEL.get(res, res))
		btn.tooltip_text = ", ".join(labels) + ("  (ri-tocca per cambiare prodotto)" if group.size() > 1 else "")
		btn.pressed.connect(_trade_cycle_select.bind(group.duplicate()))
		if front != "":
			btn.set_drag_forwarding(_trade_drag_begin.bind(front), Callable(), Callable())
		area.add_child(btn)
	# Con un prodotto selezionato: caselle valide col money (verso 0 vendi, verso 10 compra).
	if _trade_active_res == "":
		return
	var R := _trade_active_res
	var qty := int(p.resources.get(R, 0))
	var lo := maxi(0, qty - _trade_export_cap(p, R))
	var hi := mini(10, qty + _trade_import_cap_sel(p, R))
	var eff := qty - int(exp.get(R, 0)) + int(imp.get(R, 0))
	for i in range(lo, hi + 1):
		if i == eff:
			continue   # la casella corrente ha già il token in primo piano
		var slot := _resource_slot(i)
		var d := ph * 0.135
		var b := Button.new()
		b.anchor_left = slot.x; b.anchor_right = slot.x; b.anchor_top = slot.y; b.anchor_bottom = slot.y
		b.offset_left = -d * 0.78; b.offset_right = d * 0.78; b.offset_top = -d * 0.55; b.offset_bottom = d * 0.55
		b.add_theme_font_size_override("font_size", maxi(8, int(ph * 0.05)))
		var sb := StyleBoxFlat.new(); sb.set_corner_radius_all(3)
		if i < qty:
			sb.bg_color = Color(0.16, 0.5, 0.24, 0.92); b.text = "+%d" % (int(Actions.EXPORT_GAIN.get(R, 0)) * (qty - i))
		else:
			sb.bg_color = Color(0.55, 0.2, 0.2, 0.92); b.text = "-%d" % (int(Actions.IMPORT_COST.get(R, 0)) * (i - qty))
		b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sb); b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(_trade_set_target.bind(R, i))
		b.set_drag_forwarding(Callable(), _trade_can_drop.bind(R), _trade_do_drop.bind(R, i))
		area.add_child(b)


## Banner del Commercio (in cima al cassetto): saldo money, prodotto selezionato +
## sorgenti d'import (bandierine), Conferma/Annulla. Non è un popup.
## Controlli del Commercio NELLA BARRA SCELTE in alto (non più ancorati alla plancia):
## riepilogo, prodotto attivo + sorgenti (bandierine), Cambia prodotto/Conferma/Annulla,
## e la riga "Vendi Armate". Sotto resta la plancia per toccare/trascinare i token.
func _show_trade_bar(p: PlayerState) -> void:
	_clear_choice_bar()
	var td := _trade_deal(p.power)
	var info := Label.new()
	info.text = "COMMERCIO  -  saldo %+d money  -  Exp %d/%d Imp %d/%d" % [_trade_delta(),
		_trade_export_used(), int(td.get("exports", 2)),
		(_trade_sel.get("import", {}) as Dictionary).size(), int(td.get("imports", 2))]
	info.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(info)
	if _trade_active_res == "":
		# Selezione del prodotto SULLA CASELLA (si tocca/trascina il token sulla plancia;
		# se due prodotti stanno sulla stessa casella, ri-toccando si CICLA tra loro).
		var hint := Label.new()
		hint.text = "- tocca un prodotto sulla plancia, poi scegli da chi comprare"
		hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_flow.add_child(hint)
	else:
		var R := _trade_active_res
		var base := _trade_allied_import(p, R)
		var rl := Label.new()
		rl.text = "%s - importabili %d (alleate %d + venditore) - scegli da chi:" % [RES_LABEL.get(R, R), _trade_import_cap_sel(p, R), base]
		rl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_flow.add_child(rl)
		var srcs := _import_sources(p, R)
		if srcs.is_empty():
			var no := Label.new(); no.text = "(niente simboli Import né venditori: puoi solo VENDERE)"
			no.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
			no.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			choice_flow.add_child(no)
		else:
			var sel_src := _trade_selected_src(p, R)
			for s in srcs:
				choice_flow.add_child(_trade_src_flag_btn(R, s, String(s["src"]) == sel_src))
		var chg := Button.new(); chg.text = "Cambia prodotto"
		chg.pressed.connect(func(): _trade_active_res = ""; _trade_rerender())
		choice_flow.add_child(chg)
	var ok := Button.new(); ok.text = "Conferma"; ok.pressed.connect(_trade_confirm)
	choice_flow.add_child(ok)
	var cancel := Button.new(); cancel.text = "Annulla"; cancel.pressed.connect(_trade_cancel)
	choice_flow.add_child(cancel)
	# Riga "Vendi Armate" (#14): un blocco unico che il flow manda a capo se serve.
	if p.armies_available > 0 or _trade_armies > 0:
		choice_flow.add_child(_trade_armies_row(p, int(td.get("exports", 2))))
	choice_bar.visible = true


## Riga "Vendi Armate" del banner Commercio: ± per scegliere quante Armate vendere
## dalla riserva (20 money cad.). Occupa uno slot Export (#14).
func _trade_armies_row(p: PlayerState, ex_max: int) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl := Label.new()
	lbl.text = "Vendi Armate (riserva %d) - 20 money cad.:" % p.armies_available
	lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	row.add_child(lbl)
	var minus := Button.new(); minus.text = "-"; minus.custom_minimum_size = Vector2(30, 28)
	minus.disabled = _trade_armies <= 0
	minus.pressed.connect(_trade_armies_adjust.bind(-1))
	row.add_child(minus)
	var cnt := Label.new(); cnt.text = "%d" % _trade_armies
	cnt.custom_minimum_size = Vector2(28, 0); cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(cnt)
	# Aggiungere Armate richiede uno slot Export libero (se non ne stai già vendendo).
	var slot_full: bool = _trade_armies == 0 and (_trade_sel.get("export", {}) as Dictionary).size() >= ex_max
	var plus := Button.new(); plus.text = "+"; plus.custom_minimum_size = Vector2(30, 28)
	plus.disabled = _trade_armies >= p.armies_available or slot_full
	plus.pressed.connect(_trade_armies_adjust.bind(1))
	row.add_child(plus)
	if _trade_armies > 0:
		var g := Label.new(); g.text = "= +%d money" % (20 * _trade_armies)
		g.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		row.add_child(g)
	elif slot_full:
		var w := Label.new(); w.text = "(slot Export pieni)"
		w.add_theme_color_override("font_color", Color(0.75, 0.6, 0.6))
		row.add_child(w)
	return row


## Bottone di un VENDITORE d'import (Riserva o superpotenza) nel Commercio: indica DA CHI
## prendi le unità (la capacità viene dalle tue alleate, mostrata a parte). Bandiera alta
## quanto il testo; quello selezionato ha il bordo dorato.
func _trade_src_flag_btn(R: String, s: Dictionary, selected: bool) -> Button:
	var src := String(s["src"])
	var fb := Button.new()
	fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fh := _base_fs() + 8
	var base := _trade_allied_import(_active(), R)   # simboli Import alleate (base sempre presente)
	if src == "reserve":
		fb.tooltip_text = "Solo le tue alleate (Riserva): importi fino a %d, niente +1 Diplomazia" % int(s["n"])
	else:
		var inc := int(s["n"]) - base
		fb.tooltip_text = "%s vende %d -> totale importabile %d (%d alleate + %d %s), +1 Diplomazia" % [
			POWER_LABEL.get(src, src.to_upper()), inc, int(s["n"]), base, inc, POWER_LABEL.get(src, src.to_upper())]
	var fsb := StyleBoxFlat.new(); fsb.set_corner_radius_all(5); fsb.bg_color = Color(0.2, 0.22, 0.28)
	fsb.content_margin_left = 7; fsb.content_margin_right = 7
	fsb.content_margin_top = 3; fsb.content_margin_bottom = 3
	# Sorgente SELEZIONATA = sbloccata: bordo e sfondo dorati, ben evidenti.
	if selected:
		fsb.set_border_width_all(3); fsb.border_color = Color(1.0, 0.85, 0.3)
		fsb.bg_color = Color(0.42, 0.34, 0.12)
	else:
		fsb.set_border_width_all(1); fsb.border_color = Color(0.5, 0.6, 0.75, 0.75)
	for stn in ["normal", "hover", "pressed", "focus"]:
		fb.add_theme_stylebox_override(stn, fsb)
	fb.add_theme_font_size_override("font_size", _base_fs())
	if src == "reserve":
		fb.text = "Solo alleate x%d" % int(s["n"])
	else:
		# Bandiera (icona) + NOME della superpotenza + "+M" (quanto AGGIUNGE alla base): è
		# chiaro da quale giocatore compri e che la sua quantità si somma alle tue alleate.
		fb.icon = load("res://assets/flags/%s.png" % src)
		fb.expand_icon = true
		fb.add_theme_constant_override("icon_max_width", int(fh * 1.4))
		fb.text = "%s +%d (=%d)" % [POWER_LABEL.get(src, src.to_upper()), int(s["n"]) - base, int(s["n"])]
	fb.pressed.connect(_trade_pick_src.bind(R, src))
	return fb


## Posizione normalizzata dell'area Riserva Armate (in alto sulla plancia).
## DA CALIBRARE sul simbolo del carro della plancia reale.
const RESERVE_ARMY_POS := Vector2(0.40, 0.05)

## Pedine Armata della riserva del giocatore, impilate (sovrapposte) in alto sulla
## plancia, con "xN" del totale.
func _add_reserve_armies(view: Control, p: PlayerState, ph: float) -> void:
	var n := p.armies_available
	if n <= 0:
		return
	var th := ph * 0.085
	var tw := th * 2.0
	var step := tw * 0.42
	var shown: int = mini(n, 5)
	for i in shown:
		var tr := TextureRect.new()
		tr.texture = load("res://assets/armies/%s.png" % p.power)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.anchor_left = RESERVE_ARMY_POS.x; tr.anchor_right = RESERVE_ARMY_POS.x
		tr.anchor_top = RESERVE_ARMY_POS.y; tr.anchor_bottom = RESERVE_ARMY_POS.y
		tr.offset_left = i * step; tr.offset_right = i * step + tw
		tr.offset_top = -th * 0.5; tr.offset_bottom = th * 0.5
		view.add_child(tr)
	var lbl := Label.new()
	lbl.text = "x%d" % n
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	lbl.add_theme_font_size_override("font_size", maxi(11, int(ph * 0.05)))
	lbl.anchor_left = RESERVE_ARMY_POS.x; lbl.anchor_right = RESERVE_ARMY_POS.x
	lbl.anchor_top = RESERVE_ARMY_POS.y; lbl.anchor_bottom = RESERVE_ARMY_POS.y
	lbl.offset_left = shown * step + tw * 0.55; lbl.offset_top = -th * 0.5
	view.add_child(lbl)


## Posizione normalizzata della casella Risorse (0..10): "0" a sinistra, 1-5 in
## alto, 6-10 in basso.
func _resource_slot(amount: int) -> Vector2:
	var a := clampi(amount, 0, 10)
	if a == 0:
		return Vector2(0.0858, 0.8348)
	if a <= 5:
		return Vector2(RES_TRACK_X[a - 1], 0.7685)
	return Vector2(RES_TRACK_X[a - 6], 0.9036)


## Cubo/disco segnalino a coordinate normalizzate (circle=true -> disco prosperità/focus).
func _add_cube(parent: Control, nx: float, ny: float, pw: float, ph: float, col: Color, circle: bool) -> void:
	var d := ph * (0.082 if circle else 0.074)
	var s := Vector2(d, d)
	var m := Panel.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ancorato a (nx,ny) della plancia REALE: segue sempre l'immagine, anche se la
	# plancia si ridimensiona col device.
	m.anchor_left = nx; m.anchor_right = nx
	m.anchor_top = ny; m.anchor_bottom = ny
	m.offset_left = -s.x * 0.5; m.offset_right = s.x * 0.5
	m.offset_top = -s.y * 0.5; m.offset_bottom = s.y * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.92)
	sb.border_color = Color(0, 0, 0, 0.85)
	sb.set_border_width_all(maxi(1, int(ph * 0.005)))
	sb.set_corner_radius_all(int(s.y * 0.5) if circle else int(s.y * 0.18))
	m.add_theme_stylebox_override("panel", sb)
	parent.add_child(m)


## Token-immagine di una risorsa sulla traccia RESOURCES (impilati con offset se
## più risorse condividono lo stesso numero).
func _add_token(parent: Control, res: String, nx: float, ny: float, pw: float, ph: float, stack_index: int) -> void:
	var s := ph * 0.095
	var off := stack_index * s * 0.5
	var tr := TextureRect.new()
	tr.texture = load("res://assets/tokens/%s.png" % res)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.anchor_left = nx; tr.anchor_right = nx
	tr.anchor_top = ny; tr.anchor_bottom = ny
	tr.offset_left = -s * 0.5 + off; tr.offset_right = s * 0.5 + off
	tr.offset_top = -s * 0.5; tr.offset_bottom = s * 0.5
	parent.add_child(tr)


func _prosperity_strip(p: PlayerState) -> Control:
	var pb: Dictionary = DataLoader.load_player_boards()
	var steps: Array = pb.get("prosperity_track", {}).get("steps_partial", [])
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 4)
	for i in steps.size():
		var step: Dictionary = steps[i]
		var cell := Label.new()
		cell.text = "  %dCG->%dVP  " % [int(step.get("cost_consumer_goods", 0)), int(step.get("vp", 0))]
		var box := StyleBoxFlat.new()
		if i < p.prosperity_level:
			box.bg_color = Color(0.3, 0.7, 0.4, 0.9)
		elif i == p.prosperity_level:
			box.bg_color = Color(0.9, 0.8, 0.2, 0.95)
			cell.add_theme_color_override("font_color", Color.BLACK)
		else:
			box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		cell.add_theme_stylebox_override("normal", box)
		strip.add_child(cell)
	return strip


## Sezione alleati: le nazioni amiche come carte-immagine reali (cliccabili solo
## per il giocatore di turno: Invest/Build a Base). Le carte della STESSA nazione
## si impilano (sovrapposte, con badge xN): più carte = più simboli Export/Import,
## quindi più capacità di commercio con quella nazione. Accanto, la carta Trade
## Deals (Commercio) del giocatore.
func _build_allies_section(p: PlayerState, is_active: bool, parent: Control) -> void:
	if p.allied_countries.is_empty():
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(col)
	var elig: Array = _eligible_allied(String(awaiting_op.get("op", ""))) if (awaiting == "allied_country" and is_active) else []
	# Modalità SCONTO: le nazioni alleate della Regione si toccano per attivare lo sconto.
	var ex_active: bool = (not _exhaust_ctx.is_empty()) and is_active
	var ex_elig: Array = _exhaustable_allies(String(_exhaust_ctx.get("region", ""))) if ex_active else []
	# Raggruppa le carte per nazione (id) preservando l'ordine: ogni gruppo è una pila.
	var groups: Array = []
	var index := {}
	for cn in p.allied_countries:
		var key := String(cn.get("id", cn.get("display_name", "")))
		if index.has(key):
			(groups[index[key]]["cards"] as Array).append(cn)
		else:
			index[key] = groups.size()
			groups.append({"cards": [cn]})
	# Carte alleate in FILA a tutta larghezza del pannello: ne entrano almeno 7 per riga
	# (un po' più piccole di prima), le altre vanno a capo (HFlowContainer).
	var board_w := _board_w()
	var cw: float = clampf((board_w - 32.0) / 7.0 - 6.0, 46.0, 92.0)
	var ch: float = cw / 0.70
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_child(grid)
	for g in groups:
		var cards: Array = g["cards"]
		var cn: Dictionary = cards[0]
		var cid := String(cn.get("id", ""))
		var spent := bool(p.exhausted.get(cid, false))
		var ex_this: bool = ex_active and (cn in ex_elig)
		var highlight: bool = (is_active and awaiting == "allied_country" and (cn in elig)) \
			or (ex_this and bool(_exhaust_sel.get(cid, false)))
		var dim: bool = (is_active and awaiting == "allied_country" and not (cn in elig)) \
			or (ex_active and not ex_this)
		var on_press: Callable = _cmd_exhaust_ally.bind(cn) if ex_this else Callable()
		var clickable: bool = (is_active and not dim) or ex_this
		var sz := Vector2(cw, ch)
		var stack := _ally_stack(cn, cards.size(), sz, highlight, clickable, spent, on_press)
		_overlay_country_markers(stack, sz, cid in p.fdi_countries, cid in p.bases)
		grid.add_child(stack)


## Sovrappone i segnalini Base (in alto a sinistra) e FDI (in alto a destra) su una
## carta nazione alleata, se il giocatore li ha piazzati su quel Paese.
func _overlay_country_markers(card: Control, sz: Vector2, has_fdi: bool, has_base: bool) -> void:
	var s := minf(sz.x, sz.y) * 0.5
	if has_base:
		var b := TextureRect.new()
		b.texture = load("res://assets/markers/base.png")
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.position = Vector2(1, 1)
		b.size = Vector2(s, s)
		card.add_child(b)
	if has_fdi:
		var f := TextureRect.new()
		f.texture = load("res://assets/markers/fdi.png")
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.position = Vector2(sz.x - s - 1, 1)
		f.size = Vector2(s, s)
		card.add_child(f)


## Aspetto "esaurita" (tapped): carta grigia e leggermente ruotata.
func _apply_exhausted(card: Control, sz: Vector2) -> void:
	card.modulate = Color(0.55, 0.55, 0.6)
	card.pivot_offset = sz * 0.5
	card.rotation_degrees = 8.0


## Pila di carte della stessa nazione: le copie in più stanno dietro, leggermente
## sfalsate; un badge xN indica quante sono (più simboli = più Export/Import).
## exhausted=true -> la nazione è esaurita (grigia/ruotata).
func _ally_stack(cn: Dictionary, count: int, sz: Vector2, highlight: bool, clickable: bool, exhausted := false, on_press := Callable()) -> Control:
	var handler: Callable = on_press if on_press.is_valid() else _cmd_pick_allied_country.bind(cn)
	if count <= 1:
		var single := _country_card_button(cn, sz, highlight)
		single.disabled = not clickable
		if exhausted:
			_apply_exhausted(single, sz)
		if clickable:
			single.pressed.connect(handler)
		return single
	# La pila scende verso il BASSO: la carta in primo piano sta in ALTO (intera), le copie
	# dietro spuntano sotto mostrando la loro riga PRODUZIONE (in fondo alla carta). 'off_y'
	# ~ altezza di quella riga; un piccolo scostamento laterale dà profondità.
	var off_y := clampf(sz.y * 0.22, 14.0, 30.0)
	var off_x := minf(6.0, sz.x * 0.10)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(sz.x + off_x * (count - 1), sz.y + off_y * (count - 1))
	# Copie dietro: la più PROFONDA (più in basso) per prima, così le successive la coprono
	# in alto e ne lasciano visibile solo la produzione in fondo.
	for j in range(count - 1, 0, -1):
		var back := _country_card_button(cn, sz, false)
		back.disabled = true
		back.focus_mode = Control.FOCUS_NONE
		back.position = Vector2(off_x * j, off_y * j)
		if exhausted:
			back.modulate = Color(0.55, 0.55, 0.6)
		holder.add_child(back)
	# Carta in primo piano (in alto): cliccabile + flyover.
	var front := _country_card_button(cn, sz, highlight)
	front.position = Vector2(0, 0)
	front.disabled = not clickable
	if exhausted:
		_apply_exhausted(front, sz)
	if clickable:
		front.pressed.connect(handler)
	holder.add_child(front)
	# Badge xN.
	var badge := Label.new()
	badge.text = "x%d" % count
	badge.add_theme_font_size_override("font_size", maxi(12, _base_fs()))
	badge.add_theme_color_override("font_color", Color(1, 1, 1))
	var bst := StyleBoxFlat.new()
	bst.bg_color = Color(0.1, 0.5, 0.2, 0.92)
	bst.set_corner_radius_all(6); bst.set_content_margin_all(3)
	badge.add_theme_stylebox_override("normal", bst)
	badge.position = Vector2(0, 0)
	holder.add_child(badge)
	return holder


## Tag delle abilità continuative (ongoing) possedute dal giocatore (dalle Growth).
func _ongoing_tags(p: PlayerState) -> Array:
	var out := []
	for c in p.growth_cards:
		for op in c.get("effect_ops", []):
			if String(op.get("op", "")) == "ongoing":
				out.append(String(op.get("tag", "")))
	return out


func _ongoing_count(p: PlayerState, tag: String) -> int:
	return _ongoing_tags(p).count(tag)


func _ongoing_used(power: String, tag: String) -> bool:
	return tag in (_used_ongoing.get(power, []) as Array)


## Pannello "Abilità continuative": elenca le ongoing possedute; quelle once-per-round
## hanno un pulsante "Usa" (disabilitato se già usate nel round).
## Strategic Asset del giocatore (le 2 carte speciali tenute al setup): disponibili
## o già usate (grigie). Si attivano giocando una carta di mano a faccia in giù.
## Colonna Commercio: in alto la carta Trade Deals del giocatore, sotto le carte
## "prodotto" (Commerce card = le risorse che la potenza può vendere). Quelle già
## usate nel round sono girate (grigie/ruotate).
func _build_commerce_section(p: PlayerState, is_active: bool, parent: Control) -> void:
	var td := _trade_deal(p.power)
	if not td.has("art"):
		return
	# Carta Commercio in alto, carte prodotto SOTTO (in una riga larga quanto la carta).
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(col)
	var cardw: float = clampf(_plancia_height() * 0.56, 92.0, 150.0)
	var tdcard := _country_card_button({"art": td["art"], "display_name": "Trade Deals"}, Vector2(cardw, cardw * 0.71), false)
	tdcard.disabled = false
	tdcard.focus_mode = Control.FOCUS_NONE
	if is_active:
		tdcard.pressed.connect(_open_trade_ui)
	col.add_child(tdcard)
	# Carte prodotto (Commerce card): 2 (3 per la Russia), un po' più PICCOLE così la loro
	# riga è larga quanto la carta Commercio. Le carte usate sono girate/grigie.
	var cards := _commerce_cards(p.power)
	var art: String = trade_deals.get("commerce_card_art", {}).get(p.power, "")
	if cards.is_empty() or art == "":
		return
	var flipped: Array = _commerce_flipped.get(p.power, [])
	var n: int = cards.size()
	var sep := 3.0
	var pcw: float = (cardw - sep * float(maxi(n - 1, 0))) / float(maxi(n, 1))
	var pcsz := Vector2(pcw, pcw / 0.65)
	var prow := HBoxContainer.new(); prow.add_theme_constant_override("separation", int(sep))
	col.add_child(prow)
	for i in cards.size():
		var pcard := _country_card_button({"art": art, "display_name": "Commerce"}, pcsz, false)
		pcard.focus_mode = Control.FOCUS_NONE
		var used: bool = i in flipped
		if used:
			_apply_exhausted(pcard, pcsz)
		var prods := []
		for res in (cards[i] as Dictionary):
			var qy := int((cards[i] as Dictionary)[res])
			prods.append("%d %s" % [qy, RES_LABEL.get(res, res)] if qy > 1 else String(RES_LABEL.get(res, res)))
		# "una risorsa per carta": le risorse sulla stessa carta sono alternative (O).
		pcard.tooltip_text = "Commerce %d/%d%s - vende: %s" % [i + 1, cards.size(), "  (usata)" if used else "", " o ".join(prods)]
		prow.add_child(pcard)


## Colonna Growth: le Growth card acquisite dal giocatore, mostrate come carte
## (stessa arte wide_aux del mazzo) impilate, accanto agli Strategic Asset.
func _build_growth_section(p: PlayerState, is_active: bool, parent: Control) -> void:
	if p.growth_cards.is_empty():
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(col)
	var cw: float = clampf(_plancia_height() * 0.78, 120.0, 200.0)
	for g in p.growth_cards:
		var card := _country_card_button(g, Vector2(cw, cw / 2.4), false)
		card.disabled = true
		card.tooltip_text = "%s (Growth Lv%d)\n%s" % [g.get("display_name", ""), int(g.get("level", 0)), g.get("ability_text", "")]
		col.add_child(card)


func _build_ongoing_section(p: PlayerState, is_active: bool) -> void:
	var tags := _ongoing_tags(p)
	if tags.is_empty():
		return
	drawer_content.add_child(_section("Abilità continuative"))
	for tag in tags:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = "- " + String(ONGOING_DESC.get(tag, tag))
		lbl.add_theme_font_size_override("font_size", maxi(11, _base_fs() - 2))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(260, 0)
		row.add_child(lbl)
		if is_active and tag.begins_with("once_per_round:"):
			var b := Button.new()
			b.text = "Usata" if _ongoing_used(p.power, tag) else "Usa"
			b.disabled = _ongoing_used(p.power, tag) or not playing_card.is_empty()
			b.pressed.connect(_cmd_use_ongoing.bind(tag))
			row.add_child(b)
		drawer_content.add_child(row)


## Attiva un'abilità once-per-round e la marca usata per il round.
func _use_ongoing(tag: String) -> void:
	var p := _active()
	if _ongoing_used(p.power, tag):
		return
	if not _used_ongoing.has(p.power):
		_used_ongoing[p.power] = []
	(_used_ongoing[p.power] as Array).append(tag)
	match tag:
		"once_per_round:convert_influence":
			awaiting = "convert_influence"
			_status("Tocca una Regione dove hai Influenza temporanea per convertirla.")
			_after_change()
		"once_per_round:draw_then_trash":
			p.draw_cards(1)
			_pick_hand_card("Scarta una carta (trash):", func(card):
				p.hand.erase(card)
				_status("Pescata 1, scartata %s." % card.get("display_name", "?"))
				_refresh())
		"once_per_round:draw_highest_value_then_discard":
			_draw_highest_value(p)
			_pick_hand_card("Scarta una carta:", func(card):
				p.hand.erase(card); p.discard.append(card)
				_status("Pescata la migliore, scartata %s." % card.get("display_name", "?"))
				_refresh())
		"once_per_round:improve_again_plus1":
			_play_card({"display_name": "Diplomatic Opening", "effect_ops": [{"op": "improve_relations"}], "effect_modifiers": ["improve_discount:1"]})
		_:
			_refresh()


## Pesca dal mazzo la carta col valore più alto (per "Knowledge Transfer").
func _draw_highest_value(p: PlayerState) -> void:
	if p.deck.is_empty():
		p.draw_cards(1)
		return
	var best := 0
	for i in p.deck.size():
		if int(p.deck[i].get("value", 0)) > int(p.deck[best].get("value", 0)):
			best = i
	p.hand.append(p.deck[best])
	p.deck.remove_at(best)


## Popup per scegliere una carta della mano (trash/discard).
func _pick_hand_card(prompt: String, cb: Callable) -> void:
	var items := []
	for c in _active().hand:
		items.append({"label": String(c.get("display_name", "?")), "value": c})
	if items.is_empty():
		_refresh()
		return
	_show_popup(prompt, items, cb)


## Scarta n carte dalla mano (una alla volta), poi esegue gli op "then".
func _do_discard(n: int, then_ops: Array) -> void:
	var p := _active()
	if n <= 0 or p.hand.is_empty():
		for i in range(then_ops.size() - 1, -1, -1):
			play_queue.push_front(then_ops[i])
		_advance_play()
		return
	_pick_hand_card("Scarta una carta (%d rimaste):" % n, func(card):
		p.hand.erase(card); p.discard.append(card)
		_status("Scartata: %s." % card.get("display_name", "?"))
		_do_discard(n - 1, then_ops))


## Avanza la Prosperità di 1 spazio con uno sconto in Beni di consumo.
func _increase_prosperity_discounted(p: PlayerState, discount: int) -> bool:
	var pb: Dictionary = DataLoader.load_player_boards()
	var steps: Array = pb.get("prosperity_track", {}).get("steps_partial", [])
	if p.prosperity_level >= steps.size():
		return false
	var step: Dictionary = steps[p.prosperity_level]
	var cost: int = maxi(0, int(step.get("cost_consumer_goods", 999)) - discount)
	if int(p.resources.get("consumer_goods", 0)) < cost:
		return false
	p.resources["consumer_goods"] = int(p.resources.get("consumer_goods", 0)) - cost
	p.prosperity_level += 1
	p.victory_points += int(step.get("vp", 0))
	p.money += int(step.get("money", 0))
	return true


## Sezione mano: carte scoperte solo per il giocatore di turno; per gli altri
## (hot-seat) si mostra solo il numero, senza svelare le carte.
func _build_hand_section(p: PlayerState, is_active: bool) -> void:
	# La mano è SEMPRE in basso nel cassetto (hand_pinned), così non scorre mai via.
	if not is_active:
		hand_pinned.add_child(_section("Mano avversario: %d carte (coperte)" % p.hand.size()))
		hand_box = null
		return
	# Durante una SCELTA (dopo aver giocato una carta: nazione alleata, ecc.) o durante
	# il Commercio, la mano si COLLASSA da sola così non copre la plancia/le scelte.
	# Per le scelte sulla MAPPA è già tutta la plancia a chiudersi (_update_drawer_state).
	var auto_hide: bool = awaiting != "" or _trade_mode or _produce_mode or not _exhaust_ctx.is_empty() or _aftermath_choice_p != null or _ui_phase == "Preparazione"
	var bar := Button.new()
	bar.flat = true
	bar.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	if auto_hide:
		bar.text = "Mano nascosta durante la scelta - %d carte" % p.hand.size()
		bar.disabled = true
		hand_pinned.add_child(bar)
		hand_box = null
		return
	# Barra con toggle per collassare la mano (così non copre mai la plancia).
	var plays_txt := "" if _plays_left == 1 else "  -  %d giocate" % _plays_left if _plays_left > 0 else "  -  turno esaurito"
	bar.text = "%s  La tua mano (%d)%s" % ["[+]" if hand_collapsed else "[-]", p.hand.size(), plays_txt]
	bar.pressed.connect(func(): hand_collapsed = not hand_collapsed; _refresh())
	hand_pinned.add_child(bar)
	if hand_collapsed:
		hand_box = null
		return
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, _hand_card_height() + 14)
	scroll.add_child(hand_box)
	hand_pinned.add_child(scroll)
	_render_hand()


func _card_height() -> int:
	# Carte alleati (riferimento): un po' più grandi, comunque col flyover per i dettagli.
	return int(clampf(size.y * 0.19, 96, 168))


## Carte della MANO (giocabili): più alte e leggibili, sempre verticali.
func _hand_card_height() -> int:
	return int(clampf(size.y * 0.22, 130, 210))


func _kv(k: String, v: int) -> Label:
	var l := Label.new(); l.text = "%s %d" % [k, v]; return l


## Tagli delle monete reali del gioco (asset TTS).
const COIN_DENOMS := [20, 10, 5, 1]

## Denaro come monete vere: scomposizione greedy del totale nei tagli 20/10/5/1,
## rese come immagini sovrapposte, seguite dalla cifra totale. Se servono troppe
## monete, mostra un taglio per denominazione con "xN".
func _money_widget(amount: int) -> Control:
	var fs := _base_fs()
	var cs := fs + 6   # lato moneta ~ altezza del testo
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	# Conta quante monete per taglio (greedy).
	var counts := {}
	var rem := maxi(amount, 0)
	for d in COIN_DENOMS:
		counts[d] = rem / d
		rem = rem % d
	var total_coins := 0
	for d in COIN_DENOMS:
		total_coins += int(counts[d])
	var compact := total_coins > 8   # troppe monete: una per taglio con xN
	var stack := HBoxContainer.new()
	stack.add_theme_constant_override("separation", -int(cs * 0.45))  # leggera sovrapposizione
	for d in COIN_DENOMS:
		var n := int(counts[d])
		if n == 0:
			continue
		var shown := 1 if compact else n
		for _i in shown:
			var ic := TextureRect.new()
			ic.texture = load("res://assets/money/coin_%d.png" % d)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.custom_minimum_size = Vector2(cs, cs)
			ic.tooltip_text = "Moneta da %d" % d
			stack.add_child(ic)
		if compact and n > 1:
			var x := Label.new()
			x.text = "x%d" % n
			x.add_theme_font_size_override("font_size", maxi(10, fs - 3))
			stack.add_child(x)
	box.add_child(stack)
	var tot := Label.new()
	tot.text = "$%d" % maxi(amount, 0)
	tot.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	box.add_child(tot)
	return box


func _kv2(t: String) -> Label:
	var l := Label.new(); l.text = t; return l


## --- Command bus (Step A) -------------------------------------------------
## UNICO punto d'ingresso per gli input di GIOCO instradati finora: choose_focus,
## play_card, end_turn. Gli altri input (trade, produce, sotto-scelte, aftermath)
## verranno aggiunti qui man mano (vedi docs/multiplayer-design.md). In hot-seat
## è chiamato localmente; in rete lo chiamerà SOLO l'host sui comandi ricevuti.
## Ritorna true se il comando è stato accettato e applicato.
func apply_command(cmd: Dictionary) -> bool:
	if not GameCommands.valid_shape(cmd):
		push_warning("Comando malformato ignorato: %s" % cmd)
		return false
	# GATING: il comando deve venire dal seggio che PUÒ agire ora (vedi _acting_seat):
	# Azione/Preparazione/Research -> giocatore di turno; Aftermath -> giocatore Aftermath.
	var acting := _acting_seat()
	if int(cmd["seat"]) != acting:
		push_warning("Comando fuori turno (seat %d, attivo %d): ignorato" % [int(cmd["seat"]), acting])
		return false
	var a: Dictionary = cmd["args"]
	match String(cmd["type"]):
		"choose_focus":
			_do_focus(int(a["focus"]))
		"play_card":
			var p := _active()
			var idx := int(a["hand_index"])
			if idx < 0 or idx >= p.hand.size():
				push_warning("play_card: indice mano fuori range (%d/%d)" % [idx, p.hand.size()])
				return false
			_play_card(p.hand[idx])
		"end_turn":
			_end_turn()
		"use_ongoing":
			_use_ongoing(String(a["tag"]))
		"increase_production":
			# Passo "Increase Production" della Preparazione: type vuoto = salta.
			if _ui_phase != "Preparazione":
				return false
			var t := String(a["type"])
			if t != "":
				_status(_apply_increase_production(_active(), t))
			_clear_choice_bar()
			_prep_advance()
		"pick_region":
			_on_region_pressed(String(a["region"]))
		"pick_influence_cell":
			_on_influence_cell(String(a["region"]), String(a["slot"]))
		"pick_allied_country":
			var cn := _ally_by_id(String(a["country_id"]))
			if cn.is_empty():
				return false
			_on_allied_pressed(cn)
		"exhaust_ally":
			var cn2 := _ally_by_id(String(a["country_id"]))
			if cn2.is_empty():
				return false
			_on_exhaust_toggle(cn2)
		"buy_growth":
			var gc := _growth_by_id(String(a["card_id"]))
			if gc.is_empty():
				return false
			_buy_growth_action(gc, _next_growth_level(_active()))
		"buy_market":
			var mc := _market_by_id(String(a["card_id"]))
			if mc.is_empty():
				return false
			_buy_market(mc)
		"aftermath_token":
			if _aftermath_choice_p == null:
				return false
			if String(a["kind"]) == "money":
				_aftermath_token_money(_aftermath_choice_p, String(a["region"]))
			else:
				_aftermath_token_defense(_aftermath_choice_p, String(a["region"]))
		"aftermath_prosperity":
			if _aftermath_choice_p == null:
				return false
			_aftermath_prosperity(_aftermath_choice_p)
		"aftermath_continue":
			if _aftermath_choice_p == null:
				return false
			_aftermath_continue()
		_:
			return false
	_command_log.append(cmd)
	return true


## Seggio che può agire ORA. In Aftermath è il giocatore in scelta
## (_aftermath_choice_p); altrove (Azione/Preparazione/Research) è active_seat,
## che il flusso tiene già aggiornato sul giocatore corrente.
func _acting_seat() -> int:
	if _aftermath_choice_p != null:
		return gs.players.find(_aftermath_choice_p)
	return active_seat


## Risolutori per ID (i comandi riferiscono carte per id stabile).
func _growth_by_id(id: String) -> Dictionary:
	for c in _available_growth(_active()):
		if String((c as Dictionary).get("id", "")) == id:
			return c
	return {}


func _market_by_id(id: String) -> Dictionary:
	for c in market_display:
		if String((c as Dictionary).get("id", "")) == id:
			return c
	return {}


## Risolve un country_id nella carta nazione alleata del giocatore attivo (i comandi
## riferiscono i Paesi per id stabile, non per riferimento all'oggetto).
func _ally_by_id(id: String) -> Dictionary:
	for c in _active().allied_countries:
		if String((c as Dictionary).get("id", "")) == id:
			return c
	return {}


func _next_seq() -> int:
	_cmd_seq += 1
	return _cmd_seq


## Wrapper che traducono l'input della Vista in un COMANDO e lo passano al bus.
## (I bottoni/click si collegano a questi, non più direttamente agli handler.)
func _cmd_choose_focus(f: int) -> void:
	apply_command(GameCommands.choose_focus(active_seat, _next_seq(), f))


func _cmd_end_turn() -> void:
	apply_command(GameCommands.end_turn(active_seat, _next_seq()))


func _cmd_play_card(card: Dictionary) -> void:
	var idx := _active().hand.find(card)
	if idx < 0:
		return
	apply_command(GameCommands.play_card(active_seat, _next_seq(), idx))


func _cmd_use_ongoing(tag: String) -> void:
	apply_command(GameCommands.use_ongoing(active_seat, _next_seq(), tag))


func _cmd_increase_production(type: String) -> void:
	apply_command(GameCommands.increase_production(active_seat, _next_seq(), type))


func _cmd_pick_region(region: String) -> void:
	apply_command(GameCommands.pick_region(active_seat, _next_seq(), region))


func _cmd_pick_influence_cell(region: String, slot: String) -> void:
	apply_command(GameCommands.pick_influence_cell(active_seat, _next_seq(), region, slot))


func _cmd_pick_allied_country(cn: Dictionary) -> void:
	apply_command(GameCommands.pick_allied_country(active_seat, _next_seq(), String(cn.get("id", ""))))


func _cmd_exhaust_ally(cn: Dictionary) -> void:
	apply_command(GameCommands.exhaust_ally(active_seat, _next_seq(), String(cn.get("id", ""))))


func _cmd_buy_growth(card: Dictionary, _nl: int) -> void:
	apply_command(GameCommands.buy_growth(active_seat, _next_seq(), String(card.get("id", ""))))


func _cmd_buy_market(card: Dictionary) -> void:
	apply_command(GameCommands.buy_market(active_seat, _next_seq(), String(card.get("id", ""))))


func _cmd_aftermath_token_money(p: PlayerState, region: String) -> void:
	apply_command(GameCommands.aftermath_token(gs.players.find(p), _next_seq(), region, "money"))


func _cmd_aftermath_token_defense(p: PlayerState, region: String) -> void:
	apply_command(GameCommands.aftermath_token(gs.players.find(p), _next_seq(), region, "defense"))


func _cmd_aftermath_prosperity(p: PlayerState) -> void:
	apply_command(GameCommands.aftermath_prosperity(gs.players.find(p), _next_seq()))


func _cmd_aftermath_continue() -> void:
	apply_command(GameCommands.aftermath_continue(_acting_seat(), _next_seq()))


func _end_turn() -> void:
	if not playing_card.is_empty() or game_over:
		return
	if _ui_phase == "Preparazione":
		return  # in Preparazione si sceglie il Focus, non si chiude il turno
	if popup_layer.get_child_count() > 0:
		return  # un popup (Research/riepilogo) e' aperto
	_selected_hand_card = {}
	round_turn_count += 1
	if round_turn_count >= 4 * gs.players.size():
		_begin_research()
		return
	active_seat = gs.turn_order[round_turn_count % gs.players.size()]
	_reset_plays()
	_status(_turn_hint())
	_after_change()


## Prompt chiaro di inizio turno: a chi tocca e cosa può fare (indicatore guidato).
func _turn_hint() -> String:
	var p := _active()
	if _plays_left <= 0:
		return "%s: turno esaurito - premi 'Fine turno'." % p.power.to_upper()
	return "Tocca a %s: gioca una carta dalla mano, poi 'Fine turno'." % p.power.to_upper()


## Carte giocabili nel turno: 1 di base, +1 al primo turno del round con
## l'abilità "extra_play_first_turn".
func _reset_plays() -> void:
	_plays_left = 1
	if round_turn_count < gs.players.size():
		_plays_left += _ongoing_count(_active(), "extra_play_first_turn")


## Azione Focus: sposta la pedina Focus sulla colonna scelta e prepara (ready) le
## Country card esaurite - 2 di base, +1 per ogni "ready_extra_on_focus". Consuma
## l'azione del turno (come giocare una carta).
func _do_focus(f: int) -> void:
	if not playing_card.is_empty():
		return
	if _prep_awaiting_increase:
		return  # Focus già scelto: si attende la scelta di aumento Produzione
	# In PREPARAZIONE la scelta del Focus si fa toccando una colonna sulla plancia: applica
	# le azioni del Focus (ready + produce), poi OFFRE l'aumento Produzione opzionale e
	# infine passa al giocatore successivo.
	if _ui_phase == "Preparazione" and _prep_idx < gs.players.size():
		_status(_apply_focus(_active(), f))
		_prep_offer_increase()
		return
	var p := _active()
	# Choose Focus è un passo della PREPARATION: è GRATIS (non costa un'azione) e
	# si fa una volta per round. Dopo, ri-cliccare sposta solo il marker.
	if int(_focus_round.get(p.power, -1)) == gs.round:
		p.focus = f
		_after_change()
		return
	# Fallback (Focus non ancora scelto nel round): applica ready + produce.
	_status(_apply_focus(p, f))
	_after_change()


## Applica gli effetti del Focus `f` a `p` (passo della PREPARATION): segna il Focus
## scelto nel round, prepara (ready) le Country card esaurite e produce i tipi del
## Focus (le secondarie consumano le primarie; le Armate vanno in riserva). Ritorna
## un messaggio di riepilogo per la barra di stato.
func _apply_focus(p: PlayerState, f: int) -> String:
	_focus_round[p.power] = gs.round
	p.focus = f
	var key: String = ["domestic", "diplomatic", "military"][f]
	var fb: Dictionary = focus_bonuses.get(key, {})
	# 1) Ready: quante Country card prepara questo Focus (+ abilità ongoing).
	var to_ready := int(fb.get("ready_country_cards", 1)) + _ongoing_count(p, "ready_extra_on_focus")
	var readied := 0
	for cid in p.exhausted:
		if to_ready <= 0:
			break
		if bool(p.exhausted[cid]):
			p.exhausted[cid] = false
			readied += 1
			to_ready -= 1
	# 2) Produce: i tipi specifici di questo Focus.
	var produced := []
	var produced_types := []
	for rt in (fb.get("produce", []) as Array):
		var made := 0
		if String(rt) == "armies":
			for _i in int(p.production.get("armies", 0)):
				if int(p.resources.get("raw_materials", 0)) >= 1:
					p.resources["raw_materials"] = int(p.resources.get("raw_materials", 0)) - 1
					p.armies_available += 1
					made += 1
		else:
			made = Actions.execute_produce(p, String(rt))
		if made > 0:
			produced.append("%s +%d" % [RES_LABEL.get(rt, rt), made])
			produced_types.append(String(rt))
	# Commerce: produrre un tipo elencato sulle carte prodotto le rigira a faccia in su
	# (risorse in surplus disponibili per il Trade) - regolamento Choose Focus.
	_flip_commerce_faceup_on_produce(p.power, produced_types)
	var msg := "Focus %s" % FOCUS_NAME[f]
	if readied > 0:
		msg += " - preparate %d Country card" % readied
	if produced.size() > 0:
		msg += " - Prodotto: %s" % ", ".join(produced)
	return msg + "."


## Tipi di Produzione aumentabili dal Focus corrente di `p` + il costo (Choose Focus,
## passo "Increase Production"): Diplomatic -> Diplomazia, Military -> Armate, Domestic
## -> una primaria (Energia/Materie/Cibo). Ritorna [{type, cost}].
func _increase_prod_options(p: PlayerState) -> Array:
	var key: String = ["domestic", "diplomatic", "military"][p.focus]
	var fb: Dictionary = focus_bonuses.get(key, {})
	var cost := int(fb.get("increase_production_cost", 8))
	var types: Array = [String(fb["increase_production"])] if fb.has("increase_production") \
		else ["energy", "raw_materials", "food"]
	var out := []
	for t in types:
		out.append({"type": String(t), "cost": cost})
	return out


## Applica l'aumento di una Produzione: paga il costo, sposta il cubo di 1; se la
## risorsa è PRIMARIA si guadagna subito 1 di quella risorsa (e si rigirano le carte
## Commerce relative). Ritorna un messaggio, o "" se non applicabile.
func _apply_increase_production(p: PlayerState, type: String) -> String:
	var cost := -1
	for o in _increase_prod_options(p):
		if String(o["type"]) == type:
			cost = int(o["cost"])
	if cost < 0 or p.money < cost:
		return ""
	p.money -= cost
	p.production[type] = int(p.production.get(type, 0)) + 1
	var msg := "Produzione %s +1 (-%d money)" % [RES_LABEL.get(type, type), cost]
	if type in ["energy", "raw_materials", "food"]:
		p.resources[type] = int(p.resources.get(type, 0)) + 1   # primaria: +1 subito
		_flip_commerce_faceup_on_produce(p.power, [type])
		msg += ", +1 %s subito" % RES_LABEL.get(type, type)
	return msg + "."


## Offre (barra in alto) l'aumento Produzione opzionale del Focus; se nessuna opzione è
## abbordabile, passa direttamente al giocatore successivo della Preparazione.
func _prep_offer_increase() -> void:
	var p := _active()
	var opts: Array = _increase_prod_options(p).filter(func(o): return p.money >= int(o["cost"]))
	if opts.is_empty():
		_prep_advance()
		return
	_prep_awaiting_increase = true
	_clear_choice_bar()
	var head := Label.new()
	head.text = "Aumento Produzione (opzionale) - %s:" % p.power.to_upper()
	head.add_theme_font_size_override("font_size", _base_fs() + 1)
	head.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(head)
	for o in opts:
		var b := Button.new()
		b.text = "+1 %s (-%d money)" % [RES_LABEL.get(o["type"], o["type"]), int(o["cost"])]
		b.add_theme_font_size_override("font_size", _base_fs() + 1)
		b.pressed.connect(_cmd_increase_production.bind(String(o["type"])))
		choice_flow.add_child(b)
	var skip := Button.new()
	skip.text = "Salta"
	skip.add_theme_font_size_override("font_size", _base_fs() + 1)
	skip.pressed.connect(_cmd_increase_production.bind(""))
	choice_flow.add_child(skip)
	choice_bar.visible = true
	_layout_ui()


## Rigira a faccia in su le carte Commerce di `power` che elencano uno dei tipi prodotti
## (surplus disponibile per il Trade) - regolamento Choose Focus.
func _flip_commerce_faceup_on_produce(power: String, types: Array) -> void:
	var flipped: Array = _commerce_flipped.get(power, [])
	if flipped.is_empty() or types.is_empty():
		return
	var cards := _commerce_cards(power)
	for t in types:
		for i in range(cards.size()):
			if i in flipped and int((cards[i] as Dictionary).get(t, 0)) > 0:
				flipped.erase(i)
	_commerce_flipped[power] = flipped


# --- Fase PREPARATION guidata: ogni giocatore SCEGLIE il Focus e le azioni legate
# (ready Country card, Produzione del Focus e l'opzionale aumento Produzione). ---

## Avvia la PREPARATION guidata del round (reveal/turn order/produzione primaria/pesca
## sono già stati fatti): scelta del Focus, un giocatore alla volta in ordine di turno.
func _begin_preparation() -> void:
	# Round 1: NIENTE preparazione guidata - tutti partono con Focus Domestic.
	if gs.round <= 1:
		for pp in gs.players:
			pp.focus = WO.Focus.DOMESTIC
		_begin_action_phase()
		return
	gs.phase = WO.Phase.PREPARATION
	_ui_phase = "Preparazione"
	_prep_idx = 0
	_prep_step()


## Passo della PREPARATION: il giocatore sceglie il Focus CLICCANDO una colonna sulla
## sua plancia (evidenziata); finiti tutti i giocatori, inizia la fase Azione.
func _prep_step() -> void:
	if _prep_idx >= gs.players.size():
		_begin_action_phase()
		return
	active_seat = gs.turn_order[_prep_idx]
	drawer_open = true
	drawer_power = _active().power
	_after_change()
	_prep_bar()


## Barra in alto della PREPARATION: solo l'istruzione (NIENTE bottoni - la scelta del
## Focus si fa toccando una colonna sulla plancia).
func _prep_bar() -> void:
	_clear_choice_bar()
	var p := _active()
	var head := Label.new()
	head.text = "Preparazione - %s: scegli il Focus toccando una colonna evidenziata sulla plancia" % p.power.to_upper()
	head.add_theme_font_size_override("font_size", _base_fs() + 1)
	head.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(head)
	choice_bar.visible = true
	_layout_ui()


## Passa al giocatore successivo della PREPARATION.
func _prep_advance() -> void:
	_prep_awaiting_increase = false
	_prep_idx += 1
	_clear_choice_bar()
	_prep_step()


## Inizia la fase AZIONE al termine della PREPARATION.
func _begin_action_phase() -> void:
	gs.phase = WO.Phase.ACTION
	_ui_phase = "Azione"
	_clear_choice_bar()
	round_turn_count = 0
	active_seat = gs.turn_order[0]
	_reset_plays()
	_status("Round %d - Azione. %s" % [gs.round, _turn_hint()])
	_after_change()


# --- Fase Research / Market (fine round, prima dell'Aftermath) ---

func _refill_market() -> void:
	while market_display.size() < MARKET_SLOTS and not market_deck.is_empty():
		market_display.append(market_deck.pop_back())


## Rimuove `card` dal Market e rivela una nuova carta nella posizione più a SINISTRA
## (le altre scorrono a destra), come da regolamento (pag. 17).
func _market_take(card: Dictionary) -> void:
	market_display.erase(card)
	if not market_deck.is_empty():
		market_display.push_front(market_deck.pop_back())


## Scarta le N carte più a DESTRA del Market e rivela N nuove a sinistra (pag. 17).
func _market_discard_rightmost(n: int) -> void:
	for _i in n:
		if market_display.is_empty():
			break
		market_display.pop_back()
		if not market_deck.is_empty():
			market_display.push_front(market_deck.pop_back())


## Carte scartate dal Market a fine Research (pag. 17): 2 in 2 giocatori, 1 in 3,
## nessuna in 4.
func _market_end_discard_count() -> int:
	match gs.players.size():
		2: return 2
		3: return 1
		_: return 0


func _begin_research() -> void:
	_ui_phase = "Research"
	_research_idx = 0
	_research_next()


## Passa alla Research del prossimo giocatore (in ordine di turno); poi Aftermath.
func _research_next() -> void:
	if _research_idx >= gs.turn_order.size():
		# Fine Research: scarta le carte Market più a destra (in base ai giocatori).
		_market_discard_rightmost(_market_end_discard_count())
		_run_aftermath()
		return
	active_seat = gs.turn_order[_research_idx]
	var p := _active()
	# Reveal della mano residua: top bonus + punti Research (+2 se Domestic).
	_research_points = GamePhases.research_step(p, p.hand, p.focus == WO.Focus.DOMESTIC)
	_after_change()
	_show_research()


## Prossima Growth card acquistabile dal giocatore (livello = possedute + 1).
func _next_growth_level(p: PlayerState) -> int:
	return p.growth_cards.size() + 1


func _available_growth(p: PlayerState) -> Array:
	var nl := _next_growth_level(p)
	var owned := p.growth_cards.map(func(c): return c.get("id", ""))
	return growth_pool.filter(func(c): return int(c.get("level", 0)) == nl and not (c.get("id", "") in owned))


## "Board mercato" (Research): popola il pannello a destra (al posto della mappa), con la
## board del giocatore visibile a sinistra. Non è più un popup che copre tutto.
func _show_research() -> void:
	var p := _active()
	# Assicura che il pannello mercato sia visibile e dimensionato (siamo in fase Research).
	_layout_ui()
	for c in market_content.get_children():
		c.queue_free()
	var vb := market_content
	var board_w := clampf(size.x * 0.40, 300.0, size.x * 0.52)
	var content_w: float = maxf(200.0, (size.x - board_w) - 56.0)   # larghezza utile area mercato

	var head := Label.new()
	head.text = "Research - %s   -   Research disponibili: %d" % [p.power.to_upper(), _research_points]
	head.add_theme_font_size_override("font_size", _base_fs() + 2)
	head.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	vb.add_child(head)

	# --- Market: carte a RITRATTO dimensionate per stare tutte in una riga ---
	vb.add_child(_section("Market (spendi Research; la nuova carta compare a sinistra):"))
	var mrow := _card_row()
	vb.add_child(mrow)
	var nm: int = maxi(market_display.size(), 1)
	var mcard_w: float = clampf((content_w - 8.0 * (nm - 1)) / nm, 56.0, 104.0)
	var mcard_h: float = mcard_w / 0.72
	for card in market_display:
		var cost := int(card.get("market_cost", 0))
		mrow.add_child(_market_card_sized(card, "costo %d R" % cost, _research_points < cost, mcard_w, mcard_h, _cmd_buy_market.bind(card)))

	# Opzione (pag. 17): -2 Research per scartare le 3 carte più a destra.
	if not market_display.is_empty():
		var reshuffle := Button.new()
		reshuffle.text = "Cambia Market: -2 Research -> scarta le 3 a destra"
		reshuffle.disabled = _research_points < 2
		reshuffle.pressed.connect(_market_reshuffle_3)
		vb.add_child(reshuffle)

	# --- #12: esaurisci Country alleate per aggiungere il loro valore al Research ---
	# Mostrate come CARTE reali (immagine + "+N R" sotto), come nel Market.
	var allies := _research_ready_allies(p)
	if not allies.is_empty():
		vb.add_child(_section("Esaurisci una Country alleata per +Research (= suo valore):"))
		var aflow := HFlowContainer.new()
		aflow.add_theme_constant_override("h_separation", 6)
		aflow.add_theme_constant_override("v_separation", 6)
		vb.add_child(aflow)
		var na: int = maxi(allies.size(), 1)
		var acard_w: float = clampf((content_w - 6.0 * (na - 1)) / na, 64.0, 104.0)
		var acard_h: float = acard_w / 0.71
		for c in allies:
			aflow.add_child(_market_card_sized(c, "+%d R" % int(c.get("value", 0)), false, acard_w, acard_h, _research_exhaust_ally.bind(c)))

	# Niente Growth qui: le Growth card si comprano con l'azione "Get a Growth Card"
	# durante la fase di Azione, non nel passo Research.

	var done := Button.new()
	done.text = "Continua"
	done.pressed.connect(func():
		_research_idx += 1
		_research_next())
	vb.add_child(done)


func _buy_market(card: Dictionary) -> void:
	var spent := GamePhases.buy_market_card(_active(), card, _research_points)
	if spent >= 0:
		_research_points -= spent
		_market_take(card)
		_status("Comprata dal Market: %s (-%d Research)." % [card.get("display_name", ""), spent])
		_after_change()
		_show_research()


## Country alleate ancora READY: esaurendole nel Research aggiungono il loro valore
## ai punti Research (pag. 17; il valore = quello usato per Improve Relations/Engage).
func _research_ready_allies(p: PlayerState) -> Array:
	var out := []
	var seen := {}
	for c in p.allied_countries:
		var id := String(c.get("id", ""))
		if id == "" or id in seen or bool(p.exhausted.get(id, false)):
			continue
		seen[id] = true
		out.append(c)
	return out


## Esaurisce una Country alleata per aggiungere il suo valore ai punti Research (#12).
func _research_exhaust_ally(country: Dictionary) -> void:
	var p := _active()
	var id := String(country.get("id", ""))
	if id == "" or bool(p.exhausted.get(id, false)):
		return
	p.exhausted[id] = true
	_research_points += int(country.get("value", 0))
	_status("Esaurita %s: +%d Research." % [country.get("display_name", "?"), int(country.get("value", 0))])
	_after_change()
	_show_research()


## Opzione del Research (pag. 17): spendi 2 Research per scartare le 3 carte più a
## destra del Market e rivelarne 3 nuove. Ripetibile finché hai Research.
func _market_reshuffle_3() -> void:
	if _research_points < 2:
		return
	_research_points -= 2
	_market_discard_rightmost(3)
	_status("Market: scartate le 3 carte più a destra (-2 Research).")
	_after_change()
	_show_research()


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	return l


func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		var label: String = "money" if k == "money" else String(RES_LABEL.get(k, k))
		parts.append("%d %s" % [int(cost[k]), label])
	return ", ".join(parts) if parts.size() > 0 else "gratis"


## Aftermath del round: Increase Prosperity (auto se possibile), Resolve THREAT,
## Scoring delle Regioni (round 3 e 6). Mostra un riepilogo.
## Add Auto-Influence: con meno di 4 giocatori, le potenze NEUTRALI piazzano
## Influenza/Armate da una carta Auto-Influence (così contano per scoring e
## maggioranze). Aggiunge le righe al riepilogo e ritorna l'art della carta.
func _apply_auto_influence(lines: Array) -> String:
	var player_powers := []
	for p in gs.players:
		player_powers.append(p.power)
	if player_powers.size() >= 4:
		return ""   # tutte le potenze sono controllate da giocatori
	lines.append("- Auto-Influence (potenze neutrali) -")
	var first_art := ""
	# Si applicano DUE carte Auto-Influence per round (pag. 18), una alla volta.
	for _i in 2:
		if _auto_inf_deck.is_empty():
			_auto_inf_deck = DataLoader.load_auto_influence().duplicate()
			_auto_inf_deck.shuffle()
		if _auto_inf_deck.is_empty():
			break
		var card: Dictionary = _auto_inf_deck.pop_back()
		if first_art == "":
			first_art = String(card.get("art", ""))
		var trade_players: Array = GamePhases.add_auto_influence(gs, card, player_powers)
		var rows: Dictionary = card.get("rows", {})
		for power in rows:
			if power in player_powers:
				continue
			var row: Dictionary = rows[power]
			var txt := "%s: +Influenza in %s" % [power.to_upper(), String(row.get("region", "")).replace("_", " ")]
			if bool(row.get("army", false)):
				txt += " - +1 Armata"
			lines.append(txt)
		# Money del commercio (pag. 18): solo se il giocatore ha una Commerce card a
		# faccia in su, che viene girata; altrimenti niente.
		for tw in trade_players:
			if _commerce_flip_any(String(tw)):
				var tp := gs.player_by_power(String(tw))
				if tp:
					tp.money += 10
				lines.append("%s: +10 money (Commerce card girata)" % String(tw).to_upper())
			else:
				lines.append("%s: nessun money (Commerce card tutte girate)" % String(tw).to_upper())
	return first_art


## Numero di Country alleate del giocatore nella Regione (per i bonus da Engage token).
func _allied_count_in_region(p: PlayerState, region: String) -> int:
	var n := 0
	for c in p.allied_countries:
		if String(c.get("region", "")) == region:
			n += 1
	return n


func _run_aftermath() -> void:
	gs.phase = WO.Phase.AFTERMATH
	_ui_phase = "Aftermath"
	_aftermath_lines = ["- Aftermath round %d -" % gs.round]
	_threat_defense = {}
	# Auto-Influence delle potenze neutrali PRIMA di THREAT/Scoring (così contano).
	_aftermath_ai_art = _apply_auto_influence(_aftermath_lines)
	# Return on Investments - quota FDI (automatica): 2 money per FDI x valore del Paese.
	# Lo scarto degli Engage token (5 money/Country) è una SCELTA, gestita nei popup.
	for p in gs.players:
		var roi := Aftermath.return_on_investments(p, p.fdi_values, [])
		if roi > 0:
			_aftermath_lines.append("%s: +%d money (FDI)" % [p.power.to_upper(), roi])
	# Fase di SCELTE per giocatore (scarto Engage token + Increase Prosperity).
	_aftermath_idx = 0
	_aftermath_player_step()


## Avanza la fase scelte dell'Aftermath: un popup per giocatore, poi risolve.
func _aftermath_player_step() -> void:
	if _aftermath_idx >= gs.players.size():
		_aftermath_resolve()
		return
	_show_aftermath_choices(gs.players[_aftermath_idx])


## Scelte di Aftermath del giocatore, TUTTE sulla mappa/plancia (niente popup):
## - scartare un Engage token: si TOCCA il token sulla mappa -> money o Difesa;
## - Increase Prosperity: si TOCCA la prossima corona sulla traccia Prosperità;
## - "Continua" nella barra in alto passa al giocatore successivo.
func _show_aftermath_choices(p: PlayerState) -> void:
	_aftermath_choice_p = p
	# Board CHIUSA: serve la mappa piena per cliccare gli Engage token da scartare.
	# La Prosperità non è più una corona sulla plancia ma un BOTTONE nella barra.
	drawer_open = false
	_after_change()          # ridisegna mappa (token Engage cliccabili)
	_aftermath_bar(p)


## Barra in alto dell'Aftermath: intestazione, eventuale "Aumenta Prosperità" e "Continua".
func _aftermath_bar(p: PlayerState) -> void:
	_clear_choice_bar()
	var head := Label.new()
	head.text = "Aftermath - %s  -  round %d" % [p.power.to_upper(), gs.round]
	head.add_theme_font_size_override("font_size", _base_fs() + 2)
	head.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(head)
	if not p.engage_tokens.is_empty():
		var hint := Label.new()
		hint.text = "- tocca un Engage token sulla mappa per scartarlo (-> money o Difesa)"
		hint.add_theme_color_override("font_color", Color(0.8, 0.85, 0.6))
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_flow.add_child(hint)
	# Aumenta Prosperità: BOTTONE chiaro (niente più corona da cercare sulla plancia).
	var steps: Array = DataLoader.load_player_boards().get("prosperity_track", {}).get("steps_partial", [])
	if p.prosperity_level < steps.size():
		var step: Dictionary = steps[p.prosperity_level]
		var cost := int(step.get("cost_consumer_goods", 999))
		if int(p.resources.get("consumer_goods", 0)) >= cost:
			var bpr := Button.new()
			bpr.text = "Aumenta Prosperità (-%d CG -> +%d VP, +%d money)" % [cost, int(step.get("vp", 0)), int(step.get("money", 0))]
			bpr.add_theme_font_size_override("font_size", _base_fs() + 1)
			bpr.pressed.connect(_cmd_aftermath_prosperity.bind(p))
			choice_flow.add_child(bpr)
	var done := Button.new()
	done.text = "Continua"
	done.add_theme_font_size_override("font_size", _base_fs() + 1)
	done.pressed.connect(_cmd_aftermath_continue)
	choice_flow.add_child(done)
	choice_bar.visible = true
	_layout_ui()


## "Continua": chiude le scelte del giocatore corrente e passa al successivo.
func _aftermath_continue() -> void:
	_aftermath_choice_p = null
	_clear_choice_bar()
	_aftermath_idx += 1
	_aftermath_player_step()


## Tocco su un Engage token in Aftermath: sotto-scelta money vs Difesa nella barra.
func _on_aftermath_token(p: PlayerState, region: String) -> void:
	if _aftermath_choice_p != p or region not in p.engage_tokens:
		return
	_clear_choice_bar()
	var n := _allied_count_in_region(p, region)
	var lab := Label.new()
	lab.text = "Engage in %s - scarta per:" % String(region).replace("_", " ")
	lab.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_flow.add_child(lab)
	var bmoney := Button.new()
	bmoney.text = "+%d money (ROI)" % (5 * n)
	bmoney.add_theme_font_size_override("font_size", _base_fs() + 1)
	bmoney.pressed.connect(_cmd_aftermath_token_money.bind(p, region))
	choice_flow.add_child(bmoney)
	var bdef := Button.new()
	bdef.text = "+%d Difesa (THREAT)" % (2 * n)
	bdef.add_theme_font_size_override("font_size", _base_fs() + 1)
	bdef.pressed.connect(_cmd_aftermath_token_defense.bind(p, region))
	choice_flow.add_child(bdef)
	var cancel := Button.new()
	cancel.text = "Annulla"
	cancel.add_theme_font_size_override("font_size", _base_fs() + 1)
	cancel.pressed.connect(_aftermath_bar.bind(p))
	choice_flow.add_child(cancel)
	choice_bar.visible = true
	_layout_ui()


## Scarta un Engage token per money (5 x Country alleate della Regione) - ROI (#6).
func _aftermath_token_money(p: PlayerState, region: String) -> void:
	if region not in p.engage_tokens:
		return
	p.engage_tokens.erase(region)
	var n := _allied_count_in_region(p, region)
	p.money += 5 * n
	_aftermath_lines.append("%s: scarta Engage in %s -> +%d money" % [p.power.to_upper(), region.replace("_", " "), 5 * n])
	_layout_engage_tokens()
	_show_aftermath_choices(p)


## Scarta un Engage token per +2 Difesa/Country nella Regione, applicata al THREAT (#5).
func _aftermath_token_defense(p: PlayerState, region: String) -> void:
	if region not in p.engage_tokens:
		return
	p.engage_tokens.erase(region)
	var n := _allied_count_in_region(p, region)
	if not _threat_defense.has(region):
		_threat_defense[region] = {}
	_threat_defense[region][p.power] = int(_threat_defense[region].get(p.power, 0)) + 2 * n
	_aftermath_lines.append("%s: scarta Engage in %s -> +%d Difesa (THREAT)" % [p.power.to_upper(), region.replace("_", " "), 2 * n])
	_layout_engage_tokens()
	_show_aftermath_choices(p)


## Increase Prosperity (opzionale, #7): avanza di 1 spendendo i Consumer Goods.
func _aftermath_prosperity(p: PlayerState) -> void:
	var steps: Array = DataLoader.load_player_boards().get("prosperity_track", {}).get("steps_partial", [])
	if GamePhases.increase_prosperity(p, steps):
		_aftermath_lines.append("%s: Prosperità -> liv. %d" % [p.power.to_upper(), p.prosperity_level])
	_show_aftermath_choices(p)


## Risolve THREAT (con le Difese da Engage token scartati) e lo Scoring, poi riepiloga.
func _aftermath_resolve() -> void:
	var mil_focus := {}
	var player_powers := []
	for p in gs.players:
		mil_focus[p.power] = (p.focus == WO.Focus.MILITARY)
		player_powers.append(p.power)
	# NATO (USA/EU) solo se entrambe le potenze sono in gioco (pag. 19).
	var nato := Threat.nato_pairs(player_powers)
	for rid in gs.regions:
		var rd: Dictionary = gs.regions[rid]
		var loss := Threat.resolve_region(rd.get("zone", []), rd.get("armies", {}), mil_focus, _threat_defense.get(rid, {}), nato)
		for power in loss:
			gs.add_vp(power, -int(loss[power]))
			_aftermath_lines.append("%s: -%d VP (THREAT in %s)" % [power.to_upper(), int(loss[power]), rid.replace("_", " ")])

	# Scoring delle Regioni nei round 3 e 6.
	if gs.is_scoring_round():
		var rs := GameRunner.score_all_regions(gs)
		for power in rs:
			gs.add_vp(power, int(rs[power]))
		_aftermath_lines.append("Scoring Regioni: " + _vp_summary(rs))
		# Abilità speciali di scoring: USA (Global Superpower Status), Russia (Secured Sphere).
		var sp := GameRunner.apply_power_special_scoring(gs)
		if not sp.is_empty():
			_aftermath_lines.append("Abilità speciali: " + _vp_summary(sp))

	_show_summary(_aftermath_lines, func(): _next_round(), _aftermath_ai_art)


## Reveal Country Cards (Preparation): in ogni Regione ruota una carta - la più
## vecchia disponibile torna in fondo al mazzo e ne compare una nuova.
func _reveal_country_cards() -> void:
	for rid in region_countries:
		var rc: Dictionary = region_countries[rid]
		var avail: Array = rc.get("available", [])
		var deck: Array = rc.get("deck", [])
		if deck.is_empty() or avail.is_empty():
			continue
		deck.push_front(avail.pop_front())   # la più vecchia in fondo al mazzo (left deck)
		avail.append(deck.pop_back())        # rivela la nuova (top del right deck)


func _next_round() -> void:
	if gs.round >= GameState.TOTAL_ROUNDS:
		_game_end()
		return
	gs.round += 1
	gs.phase = WO.Phase.PREPARATION
	_reveal_country_cards()                    # Preparation: ruota le carte Country delle Regioni
	GamePhases.determine_turn_order(gs)
	GamePhases.produce_primary_resources(gs)
	# nuova mano: scarti = mano+giocate, poi pesca 6 (+1 per ogni "extra_draw_per_round").
	for p in gs.players:
		p.discard.append_array(p.hand); p.discard.append_array(p.played)
		p.hand.clear(); p.played.clear()
		p.draw_cards(6 + _ongoing_count(p, "extra_draw_per_round"))
	_used_ongoing = {}   # abilità once-per-round di nuovo disponibili
	_commerce_flipped = {}  # Commerce card di nuovo disponibili
	_status("Round %d - Preparazione: ogni potenza sceglie il Focus." % gs.round)
	_begin_preparation()   # scelta GUIDATA del Focus (niente più automatismo)


func _game_end() -> void:
	game_over = true
	var mt := GameRunner.score_majority_tokens(gs)
	for power in mt:
		gs.add_vp(power, int(mt[power]))
	# Bonus di fine partita: China FDI, +2/Strategic Asset e +3/Executive Order non usati.
	var eb := GameRunner.apply_game_end_bonuses(gs)
	var ranking := gs.players.duplicate()
	ranking.sort_custom(func(a, b): return a.victory_points > b.victory_points)
	var lines: Array[String] = ["- FINE PARTITA -", "Token Maggioranza: " + _vp_summary(mt)]
	if not eb.is_empty():
		lines.append("Bonus fine partita: " + _vp_summary(eb))
	lines.append("")
	for i in ranking.size():
		lines.append("%d) %s - %d VP" % [i + 1, ranking[i].power.to_upper(), ranking[i].victory_points])
	lines.append("")
	# Spareggi del regolamento (pag. 21); vittoria eventualmente condivisa.
	var champs := GameRunner.winners(gs)
	var champs_up := []
	for w in champs:
		champs_up.append(String(w).to_upper())
	lines.append(("Vittoria condivisa: %s" % ", ".join(champs_up)) if champs.size() > 1
		else "Vincitore: %s" % (champs_up[0] if champs_up.size() > 0 else "-"))
	_show_summary(lines, func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_after_change()


func _vp_summary(d: Dictionary) -> String:
	var parts := []
	for k in d:
		if int(d[k]) != 0:
			parts.append("%s %+d" % [k.to_upper(), int(d[k])])
	return ", ".join(parts) if parts.size() > 0 else "-"


## Popup di riepilogo con un pulsante Continua.
## Riepilogo (fine round / fine partita): pannello ANCORATO A DESTRA che NON copre la
## mappa (velo leggero, board visibile a sinistra). Scrollabile; "Continua" chiude.
func _show_summary(lines: Array, cb: Callable, art := "") -> void:
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.22)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(veil)
	var pw := minf(size.x * 0.46, 470.0)
	var panel := PanelContainer.new()
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.07, 0.09, 0.13, 0.99)
	pst.set_corner_radius_all(10); pst.set_content_margin_all(14)
	pst.set_border_width_all(2); pst.border_color = Color(0.5, 0.7, 1.0, 0.6)
	panel.add_theme_stylebox_override("panel", pst)
	panel.position = Vector2(size.x - pw - 12, size.y * 0.07)
	panel.size = Vector2(pw, 0)
	popup_layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(pw - 30, minf(size.y * 0.84, 600.0))
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(pw - 30, 0)
	vb.add_theme_constant_override("separation", 4)
	scroll.add_child(vb)
	# Carta (es. Auto-Influence) mostrata in cima al riepilogo.
	if art != "":
		var tex: Texture2D = load("res://assets/cards/%s" % art)
		if tex:
			var cc := CenterContainer.new()
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var iw := minf(pw * 0.78, 320.0)
			img.custom_minimum_size = Vector2(iw, iw * 0.42)
			cc.add_child(img)
			vb.add_child(cc)
	for line in lines:
		var l := Label.new()
		l.text = String(line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	var ok := Button.new()
	ok.text = "Continua"
	ok.add_theme_font_size_override("font_size", _base_fs() + 1)
	ok.pressed.connect(func():
		_close_popup()
		cb.call())
	vb.add_child(ok)


func _after_change() -> void:
	_layout_overlays()
	_refresh()


## Disegna le carte della mano nel contenitore della scheda "Mano".
func _render_hand() -> void:
	if hand_box == null or not is_instance_valid(hand_box):
		return
	for c in hand_box.get_children():
		c.queue_free()
	var p := _active()
	var ch := _hand_card_height()
	var busy: bool = not playing_card.is_empty() or _plays_left <= 0
	var has_sel: bool = not _selected_hand_card.is_empty()
	# Carte della mano: 1° tap evidenzia (bordo verde + le altre si oscurano), ri-tap gioca.
	for card in p.hand:
		var sel: bool = card == _selected_hand_card
		var btn := _country_card_button(card, Vector2(int(ch * 0.71), ch), sel, false)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.disabled = busy
		# Con una carta selezionata, le NON selezionate si oscurano: la scelta è evidente.
		if has_sel and not sel:
			btn.modulate = Color(0.5, 0.5, 0.55)
		btn.tooltip_text = "%s\n%s\n(tocca per selezionare - ri-tocca per giocare)" % [card.get("display_name", ""), card.get("effect_text", "")]
		btn.pressed.connect(_on_hand_card_tap.bind(card))
		hand_box.add_child(btn)
	# Separatore tra le carte e i "modi alternativi di giocare la carta selezionata".
	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	hand_box.add_child(sep)
	# Gettone 💰10 (faccia in giù -> +10 money): consuma la carta selezionata.
	hand_box.add_child(_hand_money_token(ch, busy, has_sel))
	# Carte Strategiche: consumano la carta selezionata per attivarsi.
	for asset in p.strategic_assets:
		hand_box.add_child(_hand_strategic_token(asset, ch, busy, has_sel))


## Gettone Moneta da 10 nella mano: immagine della moneta + "+10"; attivo solo se c'è
## una carta selezionata (e non si sta già risolvendo qualcosa).
func _hand_money_token(ch: int, busy: bool, has_sel: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := Button.new()
	var d := int(ch * 0.62)
	b.custom_minimum_size = Vector2(d, d)
	b.flat = true
	b.disabled = busy
	b.tooltip_text = "Scarta la carta selezionata (faccia in giù) per +10 money"
	if not has_sel:
		b.modulate = Color(0.55, 0.55, 0.6)
	b.pressed.connect(_on_play_money_token)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/money/coin_10.png")
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(ic)
	box.add_child(b)
	var lab := Label.new()
	lab.text = "+10"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	box.add_child(lab)
	return box


## Carta Strategica nella mano: immagine reale GRANDE (alta quanto le carte, arte
## ~1.4:1), senza etichetta. Attiva solo con una carta selezionata: toccandola, la
## carta selezionata è il costo. È l'UNICO posto dove appaiono (niente più doppione
## sulla board).
func _hand_strategic_token(asset: Dictionary, ch: int, busy: bool, has_sel: bool) -> Control:
	var w := int(ch * 1.40)   # arte strategica landscape ~1.4:1: alta quanto le carte di mano
	var card := _country_card_button(asset, Vector2(w, ch), false, false)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.disabled = busy
	card.tooltip_text = "Strategic Asset: %s\n%s\n(seleziona una carta, poi tocca qui per attivarlo)" % [asset.get("display_name", ""), asset.get("effect_text", "")]
	if not has_sel:
		card.modulate = Color(0.6, 0.6, 0.65)
	card.pressed.connect(_on_play_strategic_token.bind(asset))
	return card


## Riga orizzontale scrollabile di carte (Market/Growth) come la mano.
func _card_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	return row


## Carta Market/Growth come IMMAGINE reale (dimensione wxh data dal chiamante, così
## sta nella riga senza accavallarsi) + etichetta costo sotto, cliccabile.
func _market_card_sized(card: Dictionary, cost_text: String, disabled: bool, w: float, h: float, on_press: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.flat = true
	b.disabled = disabled
	b.tooltip_text = "%s\n%s" % [card.get("display_name", ""), card.get("effect_text", "")]
	if not disabled:
		b.pressed.connect(on_press)
	else:
		b.modulate = Color(0.5, 0.5, 0.55)
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # ignora la dimensione nativa enorme dell'arte
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art: String = card.get("art", "")
	if art != "":
		var tex := load("res://assets/cards/" + art)
		if tex: tr.texture = tex
	b.add_child(tr)
	box.add_child(b)
	var lab := Label.new()
	lab.text = cost_text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.custom_minimum_size = Vector2(w, 0)
	lab.add_theme_font_size_override("font_size", maxi(10, _base_fs() - 3))
	lab.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6) if not disabled else Color(0.6, 0.5, 0.5))
	box.add_child(lab)
	return box


func _status(t: String) -> void:
	if status_label:
		status_label.text = t
