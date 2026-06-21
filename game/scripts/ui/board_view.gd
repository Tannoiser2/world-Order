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
var drawer: Panel                   # foglio in basso, mostrato a richiesta
var drawer_veil: ColorRect
var drawer_content: VBoxContainer
var hand_pinned: VBoxContainer   # mano del giocatore, fissa in basso nel cassetto
var hand_collapsed := false      # mano collassabile (per non coprire la plancia)
var card_preview: TextureRect    # anteprima ingrandita della carta (flyover)
var tab_bar: HBoxContainer          # una scheda per ogni potenza in gioco
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
var _exhaust_sel: Dictionary = {}       # id nazione -> true: alleati scelti per lo sconto
var _produce_sel: Dictionary = {}       # rtype -> quantità da produrre (azione Produce)
var _trade_exported: Dictionary = {}    # risorse esportate nell'ultimo Trade (per i bonus condizionali)
var _playing_asset := false             # true se stiamo risolvendo un Strategic Asset (non una carta di mano)
var _focus_round: Dictionary = {}       # power -> round in cui ha già scelto il Focus (gratis 1×/round)
var _research_idx := 0                  # indice nel turn_order durante la Research
var _research_points := 0               # Research disponibili al giocatore corrente
const MARKET_SLOTS := 5
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
const AWAITING_MAP := ["region", "move", "convert_influence", "reset_influence", "board_country"]
var _move_ctx: Dictionary = {}   # stato dello spostamento Armate multi-Regione
var _used_ongoing: Dictionary = {}   # power -> [tag] abilità once-per-round già usate nel round
var _commerce_flipped: Dictionary = {}  # venditore(power) -> [risorse] Commerce card già usate nel round
var _plays_left := 1                  # carte ancora giocabili nel turno corrente (1 base)

## Abilità continuative (Growth): descrizione e se sono attivabili una volta/round.
const ONGOING_DESC := {
	"extra_draw_per_round": "Pesca 1 carta in più ogni round.",
	"extra_play_first_turn": "Primo turno del round: puoi giocare 1 carta in più.",
	"ready_extra_on_focus": "Quando fai Focus, prepari 1 Country card in più.",
	"once_per_round:draw_then_trash": "1×/round: pesca 1 carta, poi scartane 1.",
	"once_per_round:draw_highest_value_then_discard": "1×/round: pesca la carta di valore più alto del mazzo, poi scartane 1.",
	"once_per_round:improve_again_plus1": "1×/round: fai di nuovo Improve Relations (con +1).",
	"once_per_round:convert_influence": "1×/round: converti 1 Influenza temporanea in permanente.",
}
# Gestione round/turni:
var round_turn_count := 0   # turni totali presi nel round corrente
var game_over := false


func _ready() -> void:
	ui_theme = Theme.new()
	theme = ui_theme   # ereditato da tutta la scena: font scalati in _layout_ui
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
	_layout_overlays()
	_refresh()


func _on_resized() -> void:
	_layout_ui()
	_layout_overlays()


func _active() -> PlayerState:
	return gs.players[active_seat]


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
		_place_slot_cubes(track.perm, conf.get("permanent", []), s)
		_place_slot_cubes(track.temp, conf.get("temporary", []), s)


func _place_slot_cubes(owners: Array, coords: Array, s: float) -> void:
	for i in owners.size():
		var owner: Variant = owners[i]
		if owner == null or i >= coords.size():
			continue
		var pos: Array = coords[i]
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
## perimetrale: 0 in alto-sinistra, oraria. Top 0→30, destra 30→50, basso 50→80,
## sinistra 80→100. DA CALIBRARE al pixel se serve.
func _vp_to_pos(vp: int) -> Vector2:
	var v := ((vp % 100) + 100) % 100
	if v <= 30:
		return Vector2(0.022 + (v / 30.0) * 0.955, 0.022)        # top L→R
	elif v <= 50:
		return Vector2(0.978, 0.022 + ((v - 30) / 20.0) * 0.953) # destra T→B
	elif v <= 80:
		return Vector2(0.975 - ((v - 50) / 30.0) * 0.953, 0.975) # basso R→L
	else:
		return Vector2(0.022, 0.975 - ((v - 80) / 20.0) * 0.953) # sinistra B→T


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
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
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
	elif event is InputEventMouseMotion and _mouse_dragging:
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
	map_content.position = (mv - board_native * fit) * 0.5


## Tiene almeno una parte della mappa visibile dopo pan/zoom.
func _clamp_map() -> void:
	if map_content == null:
		return
	var sc: float = map_content.scale.x
	var bw := board_native.x * sc
	var bh := board_native.y * sc
	var mv := map_viewport.size
	var margin := 80.0
	var pos := map_content.position
	pos.x = clampf(pos.x, mv.x - bw - margin, margin)
	pos.y = clampf(pos.y, mv.y - bh - margin, margin)
	map_content.position = pos


func _make_region_button(region: String) -> Button:
	var awaiting_region := (awaiting in AWAITING_REGION)
	var btn := Button.new()
	btn.flat = true
	# Le Regioni catturano il mouse SOLO quando devi sceglierne una; altrimenti
	# lasciano passare il drag così puoi trascinare/pannare la mappa anche da zoomata.
	btn.mouse_filter = Control.MOUSE_FILTER_STOP if awaiting_region else Control.MOUSE_FILTER_IGNORE
	btn.pressed.connect(_on_region_pressed.bind(region))
	# Zona Regione: invisibile di default (il tabellone mostra già nome ed Eng);
	# si evidenzia solo quando devi SCEGLIERE una Regione. Durante un Move il colore
	# indica il ruolo: verde = sorgente possibile, giallo = sorgente scelta, blu = destinazione.
	var st := StyleBoxFlat.new()
	var role := _move_role(region) if awaiting == "move" else ("pick" if awaiting_region else "")
	if role != "":
		match role:
			"source": st.bg_color = Color(0.3, 0.85, 0.4, 0.28); st.border_color = Color(0.4, 1, 0.5, 0.95)
			"selected": st.bg_color = Color(0.95, 0.8, 0.2, 0.34); st.border_color = Color(1, 0.9, 0.3, 0.98)
			"dest": st.bg_color = Color(0.2, 0.6, 0.95, 0.28); st.border_color = Color(0.4, 0.9, 1, 0.95)
			_: st.bg_color = Color(0.2, 0.6, 0.95, 0.28); st.border_color = Color(0.4, 0.9, 1, 0.95)
		st.set_border_width_all(4)
		st.set_corner_radius_all(6)
	else:
		st.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate(); hv.bg_color = Color(0.3, 0.6, 0.95, 0.16)
	btn.add_theme_stylebox_override("hover", hv)

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
			tank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tank.position = Vector2(x, y)
			tank.size = Vector2(bw, h)
			overlay.add_child(tank)
			if cnt > 1:
				var lbl := Label.new()
				lbl.text = "×%d" % cnt
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
func _layout_engage_tokens() -> void:
	var slots: Dictionary = layout.get("influence_slots", {})
	var h := board_native.y * 0.030
	var w := h * 1.47
	for region in gs.regions:
		var conf: Dictionary = slots.get(region, {})
		if conf.is_empty():
			continue
		var temp: Array = conf.get("temporary", [])
		if temp.is_empty():
			continue
		# Punto di posa: sotto-sinistra della traccia temporanea (zona "handshake").
		var bx := float(temp[0][0]) * board_native.x - w * 0.5
		var by := (float(temp[0][1]) + 0.052) * board_native.y
		var n := 0
		for p in gs.players:
			if region in p.engage_tokens:
				var tok := TextureRect.new()
				tok.texture = load("res://assets/markers/engage_%s.png" % p.power)
				tok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tok.position = Vector2(bx + n * w * 0.62, by)
				tok.size = Vector2(w, h)
				overlay.add_child(tok)
				n += 1


## Posa le carte nazione disponibili (immagini originali) nelle aree designate
## del tabellone (card_slots, calibrate dal salvataggio TTS).
func _layout_card_slots() -> void:
	for c in card_layer.get_children():
		c.queue_free()
	var slots: Dictionary = layout.get("card_slots", {})
	for region in slots:
		if region.begins_with("_"):
			continue
		var r: Array = slots[region]
		var x0: float = r[0] * board_native.x
		var y0: float = r[1] * board_native.y
		var sw: float = (r[2] - r[0]) * board_native.x
		var sh: float = (r[3] - r[1]) * board_native.y
		var avail: Array = region_countries.get(region, {}).get("available", [])
		var n: int = maxi(1, avail.size())
		var gap: float = sw * 0.04
		var cw: float = (sw - gap * (n - 1)) / n
		for i in avail.size():
			var card := _country_card_button(avail[i], Vector2(cw, sh), awaiting == "board_country")
			card.pressed.connect(_on_country_pressed.bind(avail[i], region))
			card.position = Vector2(x0 + i * (cw + gap), y0)
			card_layer.add_child(card)


## Carta nazione come immagine originale (campo `art`), senza handler: chi la usa
## collega il proprio (_on_country_pressed sul tabellone, _on_allied_pressed tra gli alleati).
func _country_card_button(cn: Dictionary, sz: Vector2, highlight: bool) -> Button:
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
	_attach_preview(b, img.texture)
	return b


## Flyover: passando il mouse su una carta ne mostra una versione ingrandita
## al centro dello schermo; uscendo, la nasconde.
func _attach_preview(btn: Control, tex: Texture2D) -> void:
	if tex == null or card_preview == null:
		return
	btn.mouse_entered.connect(func():
		var h: float = minf(size.y * 0.7, 520.0)
		var w: float = h * 0.71
		card_preview.texture = tex
		card_preview.size = Vector2(w, h)
		card_preview.position = Vector2((size.x - w) * 0.5, (size.y - h) * 0.5)
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
		_status("%s: Improve Relations con %s (−%d Dip%s)." % [
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
		elif name == "build_base":
			if Actions.execute_build_base(gs, p.power, country, 1, slot) < 0:
				_status("Impossibile costruire una Base in %s (money o requisiti)." % country.get("display_name", "?"))
		_after_change()
		_advance_play())


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

## Tocco su una carta della mano: scegli se giocarla a faccia su (la sua azione)
## o a faccia in giù per +10 money, oppure per attivare un tuo Strategic Asset.
func _on_hand_card(card: Dictionary) -> void:
	if not playing_card.is_empty() or _plays_left <= 0:
		return
	var p := _active()
	var items := [
		{"label": "Gioca: %s" % card.get("display_name", "carta"), "value": {"t": "play"}},
		{"label": "Faccia in giù: +10 money", "value": {"t": "money"}},
	]
	for asset in p.strategic_assets:
		items.append({"label": "Strategic Asset: %s" % asset.get("display_name", "?"), "value": {"t": "asset", "asset": asset}})
	_show_popup("Come giochi «%s»?" % card.get("display_name", "carta"), items, func(choice):
		var t := String(choice.get("t", ""))
		if t == "play":
			_play_card(card)
		elif t == "money":
			_play_facedown_money(card)
		elif t == "asset":
			_play_strategic_asset(card, choice["asset"]))


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
		_status("Hai già giocato in questo turno. Premi «Fine turno».")
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
		bits.append("Improve −%d Dip" % Modifiers.improve_discount(mods))
	if mods.has("engage_discount_per_army"): bits.append("Engage −1/Armata")
	if mods.has("engage_discount_per_allied"): bits.append("Engage −1/alleato")
	if mods.has("engage_discount_1_in"): bits.append("Engage −1 in alcune Regioni")
	if Modifiers.money_for_services(mods) > 0:
		bits.append("paga %d money per Servizio" % Modifiers.money_for_services(mods))
	return "  ·  [" + ", ".join(bits) + "]" if bits.size() > 0 else ""


func _advance_play() -> void:
	if play_queue.is_empty():
		_finish_card()
		return
	var op: Dictionary = play_queue.pop_front()
	var name := String(op.get("op", ""))
	match name:
		"engage", "add_influence", "place_armies":
			# Bonus Influenza condizionale: salta l'add_influence se la condizione
			# (aver esportato certe risorse nel Trade della carta) non è soddisfatta.
			if name == "add_influence" and _has_cond_influence() and not _cond_influence_ok():
				_status("Nessun bonus Influenza: condizione di Export non soddisfatta.")
				_advance_play()
				return
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
				_status("Prosperità → livello %d." % pr3.prosperity_level)
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
	if name == "add_influence":
		# Se la carta forza il permanente lo usa; altrimenti il giocatore sceglie.
		if bool(op.get("permanent", false)):
			gs.regions[region]["track"].add(p.power, "permanent")
			_status("Influenza permanente su %s." % region.replace("_", " "))
			_layout_overlays(); _advance_play()
		else:
			_pick_slot(region, func(slot):
				gs.regions[region]["track"].add(p.power, slot)
				_status("Influenza (%s) su %s." % [slot, region.replace("_", " ")])
				_layout_overlays(); _advance_play())
		return
	match name:
		"place_armies":
			var a: Dictionary = gs.regions[region]["armies"]
			a[p.power] = int(a.get(p.power, 0)) + int(op.get("n", 1))
	_status("%s su %s." % [name, region.replace("_", " ")])
	_layout_overlays()
	_advance_play()


## Slot dove mettere l'Influenza: se c'è un permanente libero il giocatore SCEGLIE
## (regolamento: "you can choose which of the available types of slots to use"),
## altrimenti va in temporaneo. cb riceve "permanent" o "temporary".
func _pick_slot(region: String, cb: Callable) -> void:
	var track: InfluenceTrack = gs.regions[region]["track"]
	var perm_val := -1
	for i in track.perm.size():
		if track.perm[i] == null:
			perm_val = track.perm_values[i]; break
	if perm_val < 0:
		cb.call("temporary")     # nessuno slot permanente libero
		return
	var temp_val := 0
	for i in track.temp.size():
		if track.temp[i] == null:
			temp_val = track.temp_values[i]; break
	_show_popup("Influenza in %s: quale slot?" % region.replace("_", " "), [
		{"label": "Permanente  (+%d VP, resta)" % perm_val, "value": "permanent"},
		{"label": "Temporanea  (+%d VP)" % temp_val, "value": "temporary"},
	], cb)


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
		_status("%s: Engage in %s (−%d Dip, +%d VP%s)." % [
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
func _pick_exhaust_discount(region: String, title: String, cb: Callable) -> void:
	var elig := _exhaustable_allies(region)
	if elig.is_empty():
		cb.call([])
		return
	_exhaust_sel = {}
	_render_exhaust_ui(region, elig, title, cb)


func _render_exhaust_ui(region: String, elig: Array, title: String, cb: Callable) -> void:
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(center)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.08, 0.10, 0.14, 0.99); st.set_corner_radius_all(10); st.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); vb.custom_minimum_size = Vector2(340, 0)
	panel.add_child(vb)
	var discount := 0
	for c in elig:
		if bool(_exhaust_sel.get(c.get("id", ""), false)):
			discount += int(c.get("value", 0))
	var head := Label.new()
	head.text = "%s\nEsaurisci alleati della Regione per scontare:  −%d Dip" % [title, discount]
	head.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	vb.add_child(head)
	for c in elig:
		var id := String(c.get("id", ""))
		var on := bool(_exhaust_sel.get(id, false))
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = on
		b.text = "%s %s (valore %d)" % ["[x]" if on else "[  ]", c.get("display_name", "?"), int(c.get("value", 0))]
		b.pressed.connect(func():
			_exhaust_sel[id] = not bool(_exhaust_sel.get(id, false))
			_render_exhaust_ui(region, elig, title, cb))
		vb.add_child(b)
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 10)
	vb.add_child(btns)
	var ok := Button.new(); ok.text = "Conferma"
	ok.pressed.connect(func():
		var chosen := []
		for c in elig:
			if bool(_exhaust_sel.get(c.get("id", ""), false)):
				chosen.append(c)
		_exhaust_sel = {}
		_close_popup()
		cb.call(chosen))
	btns.add_child(ok)
	var skip := Button.new(); skip.text = "Salta (nessuno sconto)"
	skip.pressed.connect(func():
		_exhaust_sel = {}
		_close_popup()
		cb.call([]))
	btns.add_child(skip)


# --- Move: spostamento libero delle Armate (riserva → Regione e tra Regioni) ---

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


## Ruolo di una Regione durante un Move (per evidenziarla): sorgente possibile,
## destinazione valida, o sorgente già scelta.
func _move_role(region: String) -> String:
	var c := _move_ctx
	if c.get("source", null) == null:
		return "source" if int((gs.regions[region]["armies"] as Dictionary).get(_active().power, 0)) > 0 else ""
	if region == c["source"]:
		return "selected"
	return "dest" if _move_valid_dest(region) else ""


func _move_pick_reserve() -> void:
	if _active().armies_available <= 0:
		_status("Riserva vuota.")
		return
	_move_ctx["source"] = "_reserve"
	_refresh_move_ui()


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
			_status("Nessuna tua Armata qui. Scegli una Regione con tue Armate o «Riserva».")
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
	var from_txt := "Riserva" if String(src) == "_reserve" else String(src).replace("_", " ")
	_status("Armata: %s → %s%s." % [from_txt, dest.replace("_", " "), "" if bool(c["free"]) else "  (−%d money)" % Actions.MOVE_COST])
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


## Ridisegna mappa, barra Move e messaggio di stato in base allo stato corrente.
func _refresh_move_ui() -> void:
	_layout_overlays()
	_refresh_move_bar()
	var c := _move_ctx
	if c.get("source", null) == null:
		_status("Sposta Armate (%d/%d): scegli la SORGENTE — «Riserva» o una Regione con tue Armate." % [int(c["moved"]), int(c["max"])])
	else:
		var s: Variant = c["source"]
		var sname := "Riserva" if String(s) == "_reserve" else String(s).replace("_", " ")
		_status("Sorgente: %s. Tocca la Regione di DESTINAZIONE (o ri-tocca la sorgente per annullare)." % sname)


## Barra flottante del Move: pulsante Riserva (sorgente) + Fine spostamento.
func _refresh_move_bar() -> void:
	_hide_move_bar()
	var p := _active()
	var c := _move_ctx
	var bar := HBoxContainer.new()
	bar.name = "MoveBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 8)
	bar.position = Vector2(size.x * 0.5 - 170, size.y * 0.15)
	var res := Button.new()
	res.text = "Riserva (%d)%s" % [p.armies_available, "  (scelta)" if c.get("source", null) == "_reserve" else ""]
	res.disabled = p.armies_available <= 0
	res.add_theme_font_size_override("font_size", _base_fs() + 1)
	res.pressed.connect(_move_pick_reserve)
	bar.add_child(res)
	var done := Button.new()
	done.text = "Fine spostamento"
	done.add_theme_font_size_override("font_size", _base_fs() + 1)
	done.pressed.connect(_finish_move)
	bar.add_child(done)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(bar)


func _hide_move_bar() -> void:
	for ch in popup_layer.get_children():
		if ch.name == "MoveBar" or ch.name == "MoveDoneBtn":
			ch.queue_free()


func _finish_card() -> void:
	var p := _active()
	if not _playing_asset:
		# Carta normale: va negli scarti. Un Strategic Asset NON entra nel mazzo.
		p.hand.erase(playing_card)
		p.played.append(playing_card)
	_playing_asset = false
	playing_card = {}
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
	head.text = "Get a Growth Card — livello %d" % nl
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
			card.pressed.connect(_buy_growth_action.bind(c, nl))
		cell.add_child(card)
		var info := Label.new()
		info.text = "%s  (+%d VP)" % [_cost_text(c.get("cost", {})), int(c.get("victory_points", 0))]
		info.add_theme_font_size_override("font_size", maxi(10, _base_fs() - 3))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.custom_minimum_size = Vector2(cw, 0)
		cell.add_child(info)
		row.add_child(cell)
	var skip := Button.new(); skip.text = "— Salta —"
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


## Sorgenti d'importazione di R, in ordine: prima il mercato (nazioni amiche),
## poi le Commerce card degli altri giocatori non ancora girate in questo round.
## Ritorna [{src:"bank"|power, n:int}] per attribuire ogni unità importata.
func _import_sources(p: PlayerState, R: String) -> Array:
	var out := []
	var bank := _trade_allied_import(p, R)
	if bank > 0:
		out.append({"src": "bank", "n": bank})
	var td := _trade_deal(p.power)
	for other in (td.get("import_from", {}) as Dictionary):
		if R in (_commerce_flipped.get(other, []) as Array):
			continue   # quella Commerce card è già stata usata questo round
		if gs.player_by_power(other) == null:
			continue   # quella potenza non è in partita: niente commercio reale
		var n := (td["import_from"][other] as Array).count(R)
		if n > 0:
			out.append({"src": other, "n": n})
	return out


## Quante unità di R puoi importare: simboli Import sulle amiche + offerte dagli
## altri giocatori (Commerce card non ancora girate).
func _trade_import_cap(p: PlayerState, R: String) -> int:
	var n := 0
	for s in _import_sources(p, R):
		n += int(s["n"])
	return n


func _trade_delta() -> int:
	var d := 0
	for R in (_trade_sel.get("export", {}) as Dictionary):
		d += int(Actions.EXPORT_GAIN.get(R, 0)) * int(_trade_sel["export"][R])
	for R in (_trade_sel.get("import", {}) as Dictionary):
		d -= int(Actions.IMPORT_COST.get(R, 0)) * int(_trade_sel["import"][R])
	return d


func _open_trade_ui() -> void:
	_trade_sel = {"export": {}, "import": {}}
	_render_trade_ui()


func _trade_adjust(R: String, kind: String, delta: int) -> void:
	var p := _active()
	var sel: Dictionary = _trade_sel[kind]
	var other: Dictionary = _trade_sel["import" if kind == "export" else "export"]
	var maxT := int(_trade_deal(p.power).get(kind + "s", 2))
	var cap := _trade_export_cap(p, R) if kind == "export" else _trade_import_cap(p, R)
	var newq := clampi(int(sel.get(R, 0)) + delta, 0, cap)
	if newq > 0 and other.has(R):
		return  # una risorsa in una sola transazione (export O import)
	if newq > 0 and not sel.has(R) and sel.size() >= maxT:
		return  # superato il numero di transazioni della Trade Deals card
	if newq == 0:
		sel.erase(R)
	else:
		sel[R] = newq
	_render_trade_ui()


func _trade_confirm() -> void:
	var p := _active()
	_trade_exported = (_trade_sel["export"] as Dictionary).duplicate()  # per i bonus condizionali post-Trade
	for R in (_trade_sel["export"] as Dictionary):
		var q := int(_trade_sel["export"][R])
		p.resources[R] = int(p.resources.get(R, 0)) - q
		p.money += int(Actions.EXPORT_GAIN.get(R, 0)) * q
	var imported := false
	var from_players := 0
	for R in (_trade_sel["import"] as Dictionary):
		var q := int(_trade_sel["import"][R])
		var cost := int(Actions.IMPORT_COST.get(R, 0))
		# Attribuisci le unità alle sorgenti: prima la banca, poi gli altri giocatori.
		var remaining := q
		for s in _import_sources(p, R):
			if remaining <= 0:
				break
			var take: int = mini(remaining, int(s["n"]))
			p.money -= cost * take
			if String(s["src"]) != "bank":
				# Commercio reale: paghi il venditore, che incassa il money e prende
				# +1 Servizio (bonus di vendita); la sua Commerce card si gira (1×/round).
				var seller := gs.player_by_power(String(s["src"]))
				if seller != null:
					seller.money += cost * take
					seller.gain_resource("services", 1, 0)
					if not _commerce_flipped.has(s["src"]):
						_commerce_flipped[s["src"]] = []
					(_commerce_flipped[s["src"]] as Array).append(R)
					from_players += take
			remaining -= take
		p.gain_resource(R, q, 0)
		imported = true
	if imported:
		p.gain_resource("diplomacy", 1, 0)   # +1 Diplomazia comprando dagli altri
	_close_popup()
	_trade_sel = {}
	if from_players > 0:
		_status("Trade completato (%d unità comprate da altri giocatori)." % from_players)
	else:
		_status("Trade completato.")
	_refresh()
	_advance_play()


## Costruisce/aggiorna il popup di Trade.
func _render_trade_ui() -> void:
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := _active()
	var td := _trade_deal(p.power)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(center)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.08, 0.10, 0.14, 0.99); st.set_corner_radius_all(10); st.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var head := Label.new()
	head.text = "TRADE — Export max %d · Import max %d   ·   Δ money: %+d" % [int(td.get("exports", 2)), int(td.get("imports", 2)), _trade_delta()]
	head.add_theme_font_size_override("font_size", _base_fs() + 2)
	head.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	vb.add_child(head)
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	for R in TRADE_RES:
		var name := Label.new()
		name.text = "%s (hai %d)" % [RES_LABEL.get(R, R), int(p.resources.get(R, 0))]
		name.custom_minimum_size = Vector2(150, 0)
		grid.add_child(name)
		grid.add_child(_trade_stepper(R, "export", _trade_export_cap(p, R)))
		grid.add_child(_trade_stepper(R, "import", _trade_import_cap(p, R)))
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 10)
	vb.add_child(btns)
	var ok := Button.new(); ok.text = "Conferma Trade"; ok.pressed.connect(_trade_confirm)
	btns.add_child(ok)
	var cancel := Button.new(); cancel.text = "Annulla"
	cancel.pressed.connect(func(): _close_popup(); _trade_sel = {}; _advance_play())
	btns.add_child(cancel)


func _trade_stepper(R: String, kind: String, cap: int) -> Control:
	var box := HBoxContainer.new(); box.add_theme_constant_override("separation", 4)
	var minus := Button.new(); minus.text = "−"; minus.custom_minimum_size = Vector2(30, 0)
	minus.disabled = cap == 0
	minus.pressed.connect(_trade_adjust.bind(R, kind, -1))
	box.add_child(minus)
	var q := int((_trade_sel.get(kind, {}) as Dictionary).get(R, 0))
	var lab := Label.new()
	var unit := int(Actions.EXPORT_GAIN.get(R, 0)) if kind == "export" else int(Actions.IMPORT_COST.get(R, 0))
	lab.text = "%s %d/%d (%s%d/u)" % ["Exp" if kind == "export" else "Imp", q, cap, "+" if kind == "export" else "−", unit]
	lab.custom_minimum_size = Vector2(118, 0)
	box.add_child(lab)
	var plus := Button.new(); plus.text = "+"; plus.custom_minimum_size = Vector2(30, 0)
	plus.disabled = cap == 0 or q >= cap
	plus.pressed.connect(_trade_adjust.bind(R, kind, 1))
	box.add_child(plus)
	return box


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


func _open_produce_ui() -> void:
	_produce_sel = {}
	_render_produce_ui()


func _produce_adjust(rt: String, delta: int) -> void:
	var p := _active()
	var cap := int(p.production.get(rt, 0))
	var q := clampi(int(_produce_sel.get(rt, 0)) + delta, 0, cap)
	if q == 0:
		_produce_sel.erase(rt)
	else:
		_produce_sel[rt] = q
	_render_produce_ui()


## Breve testo dei requisiti primari di una risorsa secondaria (per unità).
func _secondary_req_text(rt: String) -> String:
	var req: Dictionary = Actions.SECONDARY_REQ.get(rt, {})
	if req.is_empty():
		return ""
	var bits := []
	for k in req:
		bits.append("−%d %s" % [int(req[k]), RES_LABEL.get(k, k)])
	return "  (%s /u)" % " ".join(bits)


func _render_produce_ui() -> void:
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := _active()
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
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var head := Label.new()
	head.text = "PRODUCE — scegli quante risorse generare da ogni traccia"
	head.add_theme_font_size_override("font_size", _base_fs() + 2)
	head.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	vb.add_child(head)
	var note := Label.new()
	note.text = "Primarie: gratis. Secondarie: consumano le primarie (prodotte prima)."
	note.add_theme_font_size_override("font_size", maxi(10, _base_fs() - 3))
	note.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	vb.add_child(note)
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	for rt in _producible_types(p):
		var lab := Label.new()
		lab.text = "%s (hai %d · prod %d)%s" % [RES_LABEL.get(rt, rt), int(p.resources.get(rt, 0) if rt != "armies" else p.armies_available), int(p.production.get(rt, 0)), _secondary_req_text(rt)]
		lab.custom_minimum_size = Vector2(230, 0)
		grid.add_child(lab)
		grid.add_child(_produce_stepper(rt, int(p.production.get(rt, 0))))
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 10)
	vb.add_child(btns)
	var ok := Button.new(); ok.text = "Conferma Produzione"; ok.pressed.connect(_produce_confirm)
	btns.add_child(ok)
	var cancel := Button.new(); cancel.text = "Annulla"
	cancel.pressed.connect(func(): _close_popup(); _produce_sel = {}; _advance_play())
	btns.add_child(cancel)


func _produce_stepper(rt: String, cap: int) -> Control:
	var box := HBoxContainer.new(); box.add_theme_constant_override("separation", 4)
	var minus := Button.new(); minus.text = "−"; minus.custom_minimum_size = Vector2(30, 0)
	minus.pressed.connect(_produce_adjust.bind(rt, -1))
	box.add_child(minus)
	var q := int(_produce_sel.get(rt, 0))
	var lab := Label.new(); lab.text = "%d/%d" % [q, cap]; lab.custom_minimum_size = Vector2(46, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lab)
	var plus := Button.new(); plus.text = "+"; plus.custom_minimum_size = Vector2(30, 0)
	plus.disabled = q >= cap
	plus.pressed.connect(_produce_adjust.bind(rt, 1))
	box.add_child(plus)
	return box


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
	_close_popup()
	_produce_sel = {}
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


func _show_popup(prompt: String, items: Array, cb: Callable) -> void:
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(360, 0)
	panel.add_child(vb)
	var lab := Label.new()
	lab.text = prompt
	vb.add_child(lab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 280)
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	for it in items:
		var b := Button.new()
		b.text = it["label"]
		b.pressed.connect(func():
			_close_popup()
			cb.call(it["value"]))
		list.add_child(b)
	var cancel := Button.new()
	cancel.text = "Annulla"
	cancel.pressed.connect(func():
		_close_popup()
		_cancel_card())
	vb.add_child(cancel)


func _close_popup() -> void:
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	hand_pinned = VBoxContainer.new()
	hand_pinned.add_theme_constant_override("separation", 2)
	col.add_child(hand_pinned)

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
		tab_bar.add_child(b)
	drawer_power = _active().power


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
	var hud_h := clampf(h * 0.11, 40, 86)
	top_hud.position = Vector2.ZERO
	top_hud.size = Vector2(w, hud_h)
	var tab_h := clampf(h * 0.08, 34, 64)
	tab_bg.position = Vector2(0, h - tab_h)
	tab_bg.size = Vector2(w, tab_h)
	tab_bar.position = Vector2(4, h - tab_h + 2)
	tab_bar.size = Vector2(w - 8, tab_h - 4)
	# La mappa occupa SOLO lo spazio tra HUD (in alto) e barra linguette (in basso).
	map_viewport.position = Vector2(0, hud_h)
	map_viewport.size = Vector2(w, maxf(1.0, h - hud_h - tab_h))
	var dy := h * 0.30   # il cassetto copre ~62% dello schermo: ci sta tutto
	drawer.visible = drawer_open
	drawer.position = Vector2(0, dy)
	drawer.size = Vector2(w, maxf(80, h - tab_h - dy - 4))
	# Finché l'utente non zooma/panna a mano, la mappa si ri-adatta (centrata) alla
	# viewport corrente ad ogni layout: così riempie sempre lo spazio disponibile.
	if not _user_adjusted and size.x > 0 and size.y > 0:
		_fit_map()
	else:
		_clamp_map()


## Dimensione font base proporzionale all'altezza del device.
func _base_fs() -> int:
	return clampi(int(size.y * 0.026), 11, 26)


func _on_power_tab(power: String) -> void:
	if awaiting in AWAITING_MAP:
		return   # interazione con la mappa: il cassetto resta chiuso
	if drawer_open and drawer_power == power:
		drawer_open = false
	else:
		drawer_open = true
		drawer_power = power
	_refresh()


## Apertura/chiusura automatica: chiuso quando si deve toccare la mappa; aperto
## sulla propria plancia quando serve scegliere un Country alleato.
func _update_drawer_state() -> void:
	if not drawer_open:
		drawer_power = _active().power
	if awaiting in AWAITING_MAP:
		drawer_open = false   # serve toccare la mappa: chiudi la plancia
	elif awaiting == "allied_country":
		drawer_open = true
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
	_layout_ui()


func _refresh_hud(p: PlayerState) -> void:
	for c in hud_box.get_children():
		c.queue_free()
	var my_turn := (round_turn_count / gs.players.size()) + 1
	# Barra snella: turno/round + denaro + Fine turno. VP sono sui segnalini del
	# tabellone; la Prosperità è sulla plancia (così la barra non copre la mappa).
	var who := Label.new()
	who.text = "Round %d/6 · %s · turno %d/4" % [gs.round, p.power.to_upper(), mini(my_turn, 4)]
	who.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	hud_box.add_child(who)
	hud_box.add_child(_money_widget(p.money))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_box.add_child(spacer)
	var endt := Button.new()
	endt.text = "Fine turno"
	endt.disabled = game_over or not playing_card.is_empty()
	endt.pressed.connect(_end_turn)
	hud_box.add_child(endt)


## Maniglie: una per potenza, colorate; ▶ = a chi tocca, ▼ = cassetto aperto.
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

	# Riga in colonne: plancia · nazioni amiche · commercio · strategic asset.
	# Niente più etichette di testo: le sezioni si riconoscono dalle carte stesse.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	drawer_content.add_child(top)
	top.add_child(_build_plancia_view(p, is_active))
	_build_allies_section(p, is_active, top)
	_build_commerce_section(p, is_active, top)
	_build_strategic_section(p, is_active, top)
	_build_growth_section(p, is_active, top)
	_build_ongoing_section(p, is_active)
	_build_hand_section(p, is_active)


## Rapporto altezza/larghezza delle immagini plancia (~700x499).
const PLANCIA_RATIO := 0.713
## Passo orizzontale tra due caselle di un tracciato Produzione (normalizzato).
const PROD_PITCH := 0.050
## [x della casella 1, y] normalizzati, MISURATI sull'immagine reale della plancia.
## Le 4 plance condividono il layout; la lunghezza dei tracciati cambia ma le
## caselle partono sempre dalle stesse coordinate, quindi: x = x0 + (livello-1)*passo.
const PROD_TRACKS := {
	"energy": [0.115, 0.205],
	"raw_materials": [0.44, 0.205],
	"food": [0.73, 0.205],
	"consumer_goods": [0.115, 0.527],
	"services": [0.115, 0.606],
	"diplomacy": [0.44, 0.540],
	"armies": [0.73, 0.540],
}
## Cerchi Focus (Domestic, Diplomatic, Military).
const FOCUS_POS := [[0.307, 0.311], [0.600, 0.311], [0.921, 0.311]]
## Tracciato Prosperità: livello 0 (cerchio iniziale) .. 5.
const PROSPERITY_POS := [[0.520, 0.645], [0.600, 0.645], [0.670, 0.645], [0.740, 0.645], [0.810, 0.645], [0.880, 0.645]]
## Colonne x della traccia RESOURCES (numeri 1..5 in alto, 6..10 in basso).
const RES_TRACK_X := [0.23, 0.40, 0.565, 0.735, 0.905]
## Risorse che hanno un token-immagine (armies è un tracciato a parte).
const RES_TOKENS := ["energy", "raw_materials", "food", "consumer_goods", "services", "diplomacy"]


## Costruisce la vista plancia: immagine reale a piena visibilità + segnalini
## (Produzione per ogni risorsa, Risorse possedute, Prosperità).
## Aree cliccabili dei 3 Focus sulla plancia: [x0,x1] per colonna, y [y0,y1].
const FOCUS_ZONES := [[0.02, 0.33], [0.34, 0.66], [0.67, 0.99]]


## Altezza della plancia: limiti proporzionali + tetto assoluto (no plancia gigante).
func _plancia_height() -> float:
	return minf(minf((size.x - 24.0) * PLANCIA_RATIO, size.y * 0.36), 340.0)


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
	# Area interna a DIMENSIONE FISSA (pw×ph) col rapporto reale dell'immagine: tutti
	# i segnalini si ancorano qui, così la plancia non si deforma mai anche se il
	# contenitore prova a stirarla.
	var area := Control.new()
	area.custom_minimum_size = Vector2(pw, ph)
	area.size = Vector2(pw, ph)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(area)
	board_bg = TextureRect.new()
	board_bg.texture = load("res://assets/player_boards/%s.jpg" % p.power)
	# Full-rect dell'area (pw×ph, rapporto reale): segue l'area senza deformarsi.
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_bg.stretch_mode = TextureRect.STRETCH_SCALE
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(board_bg)
	# Zone Focus cliccabili (solo per il giocatore di turno): toccando la colonna
	# si sposta la pedina del Focus lì. Niente più bottoni di testo sotto.
	if is_active:
		for f in FOCUS_ZONES.size():
			var fb := Button.new()
			fb.flat = true
			fb.anchor_left = FOCUS_ZONES[f][0]; fb.anchor_right = FOCUS_ZONES[f][1]
			fb.anchor_top = 0.27; fb.anchor_bottom = 0.67
			var fst := StyleBoxFlat.new(); fst.bg_color = Color(0, 0, 0, 0)
			fb.add_theme_stylebox_override("normal", fst)
			var fhv := StyleBoxFlat.new(); fhv.bg_color = Color(1, 1, 1, 0.08)
			fb.add_theme_stylebox_override("hover", fhv)
			fb.pressed.connect(_do_focus.bind(f))
			area.add_child(fb)
	var col: Color = POWER_COLORS.get(p.power, Color.WHITE)
	# Cubi di Produzione: uno sul livello attuale di ogni tracciato.
	for res in PROD_TRACKS:
		var lvl := int(p.production.get(res, 0))
		if lvl >= 1:
			var t: Array = PROD_TRACKS[res]
			_add_cube(area, t[0] + (lvl - 1) * PROD_PITCH, t[1], pw, ph, col, false)
	# Marker Focus (sul cerchio della colonna scelta).
	if p.focus >= 0 and p.focus < FOCUS_POS.size():
		_add_cube(area, FOCUS_POS[p.focus][0], FOCUS_POS[p.focus][1], pw, ph, col, true)
	# Marker Prosperità.
	var pl := clampi(p.prosperity_level, 0, PROSPERITY_POS.size() - 1)
	_add_cube(area, PROSPERITY_POS[pl][0], PROSPERITY_POS[pl][1], pw, ph, Color(0.45, 0.95, 0.55), true)
	# Token risorsa (immagini reali) sulla traccia RESOURCES 0..10, alla quantità.
	var stack: Dictionary = {}
	for res in RES_TOKENS:
		var amt := int(p.resources.get(res, 0))
		var slot := _resource_slot(amt)
		var n := int(stack.get(amt, 0))
		stack[amt] = n + 1
		_add_token(area, res, slot.x, slot.y, pw, ph, n)
	# Riserva Armate (pedine tank) in alto sulla plancia.
	_add_reserve_armies(area, p, ph)
	return view


## Posizione normalizzata dell'area Riserva Armate (in alto sulla plancia).
## DA CALIBRARE sul simbolo del carro della plancia reale.
const RESERVE_ARMY_POS := Vector2(0.40, 0.05)

## Pedine Armata della riserva del giocatore, impilate (sovrapposte) in alto sulla
## plancia, con "×N" del totale.
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
	lbl.text = "×%d" % n
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
		return Vector2(0.075, 0.83)
	if a <= 5:
		return Vector2(RES_TRACK_X[a - 1], 0.81)
	return Vector2(RES_TRACK_X[a - 6], 0.912)


## Cubo/disco segnalino a coordinate normalizzate (circle=true → disco prosperità/focus).
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
		cell.text = "  %dCG→%dVP  " % [int(step.get("cost_consumer_goods", 0)), int(step.get("vp", 0))]
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
## si impilano (sovrapposte, con badge ×N): più carte = più simboli Export/Import,
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
	var rows: int = int(ceil(groups.size() / 2.0))
	var ch: float = clampf(_plancia_height() / maxf(rows, 1) - 8.0, 52.0, 130.0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_child(grid)
	for g in groups:
		var cards: Array = g["cards"]
		var cn: Dictionary = cards[0]
		var spent := bool(p.exhausted.get(String(cn.get("id", "")), false))
		var highlight: bool = is_active and awaiting == "allied_country" and (cn in elig)
		var dim: bool = is_active and awaiting == "allied_country" and not (cn in elig)
		var sz := Vector2(ch * 0.70, ch)
		var stack := _ally_stack(cn, cards.size(), sz, highlight, is_active and not dim, spent)
		var cid := String(cn.get("id", ""))
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
## sfalsate; un badge ×N indica quante sono (più simboli = più Export/Import).
## exhausted=true → la nazione è esaurita (grigia/ruotata).
func _ally_stack(cn: Dictionary, count: int, sz: Vector2, highlight: bool, clickable: bool, exhausted := false) -> Control:
	if count <= 1:
		var single := _country_card_button(cn, sz, highlight)
		single.disabled = not clickable
		if exhausted:
			_apply_exhausted(single, sz)
		if clickable:
			single.pressed.connect(_on_allied_pressed.bind(cn))
		return single
	var off := minf(10.0, sz.x * 0.18)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(sz.x + off * (count - 1), sz.y + off * (count - 1))
	# Copie dietro (semplici immagini sfalsate).
	for i in range(count - 1):
		var back := _country_card_button(cn, sz, false)
		back.disabled = true
		back.focus_mode = Control.FOCUS_NONE
		back.position = Vector2(off * i, off * i)
		if exhausted:
			back.modulate = Color(0.55, 0.55, 0.6)
		holder.add_child(back)
	# Carta in primo piano: cliccabile + flyover.
	var front := _country_card_button(cn, sz, highlight)
	front.position = Vector2(off * (count - 1), off * (count - 1))
	front.disabled = not clickable
	if exhausted:
		_apply_exhausted(front, sz)
	if clickable:
		front.pressed.connect(_on_allied_pressed.bind(cn))
	holder.add_child(front)
	# Badge ×N.
	var badge := Label.new()
	badge.text = "×%d" % count
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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(col)
	var cardw: float = clampf(_plancia_height() * 0.62, 96.0, 150.0)
	var tdcard := _country_card_button({"art": td["art"], "display_name": "Trade Deals"}, Vector2(cardw, cardw * 0.71), false)
	tdcard.disabled = false
	tdcard.focus_mode = Control.FOCUS_NONE
	if is_active:
		tdcard.pressed.connect(_open_trade_ui)
	col.add_child(tdcard)
	# Carta prodotto (Commerce card) della potenza: arte ufficiale che mostra le
	# risorse vendibili (es. USA = valigetta/Servizi, Russia = barile + roccia).
	var offered: Array = trade_deals.get("commerce_offered", {}).get(p.power, [])
	var art: String = trade_deals.get("commerce_card_art", {}).get(p.power, "")
	if offered.is_empty() or art == "":
		return
	var flipped: Array = _commerce_flipped.get(p.power, [])
	var pcw: float = cardw * 0.66
	var pcard := _country_card_button({"art": art, "display_name": "Commerce"}, Vector2(pcw, pcw / 0.65), false)
	pcard.focus_mode = Control.FOCUS_NONE
	# Stato "usata": carta grigia se TUTTE le risorse offerte sono già state
	# vendute nel round (la singola disponibilità è applicata dalla UI di Commercio).
	var all_used := not offered.is_empty()
	var names := []
	for res in offered:
		var u: bool = String(res) in flipped
		if not u:
			all_used = false
		names.append("%s%s" % [RES_LABEL.get(res, res), " (usata)" if u else ""])
	if all_used:
		pcard.modulate = Color(0.5, 0.5, 0.55)
	pcard.tooltip_text = "Prodotti vendibili: " + ", ".join(names)
	col.add_child(pcard)


## Strategic Asset del giocatore: colonna a DESTRA, carte impilate una sopra l'altra.
## Le carte già usate sono grigie. Informativi: si attivano dal menu della mano.
func _build_strategic_section(p: PlayerState, is_active: bool, parent: Control) -> void:
	var assets: Array = (p.strategic_assets as Array).duplicate()
	assets.append_array(p.used_strategic_assets)
	if assets.is_empty():
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(col)
	var cw: float = clampf(_plancia_height() * 0.78, 120.0, 200.0)
	for a in assets:
		var used: bool = a in p.used_strategic_assets
		var card := _country_card_button(a, Vector2(cw, cw / 2.4), false)
		card.disabled = true
		card.tooltip_text = "%s%s\n%s" % [a.get("display_name", ""), "  (usato)" if used else "", a.get("effect_text", "")]
		if used:
			card.modulate = Color(0.5, 0.5, 0.55)
		col.add_child(card)


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
		lbl.text = "• " + String(ONGOING_DESC.get(tag, tag))
		lbl.add_theme_font_size_override("font_size", maxi(11, _base_fs() - 2))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(260, 0)
		row.add_child(lbl)
		if is_active and tag.begins_with("once_per_round:"):
			var b := Button.new()
			b.text = "Usata" if _ongoing_used(p.power, tag) else "Usa"
			b.disabled = _ongoing_used(p.power, tag) or not playing_card.is_empty()
			b.pressed.connect(_use_ongoing.bind(tag))
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
	# Barra con toggle per collassare la mano (così non copre mai la plancia).
	var bar := Button.new()
	bar.flat = true
	var plays_txt := "" if _plays_left == 1 else "  ·  %d giocate" % _plays_left if _plays_left > 0 else "  ·  turno esaurito"
	bar.text = "%s  La tua mano (%d)%s" % ["[+]" if hand_collapsed else "[–]", p.hand.size(), plays_txt]
	bar.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
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
## monete, mostra un taglio per denominazione con "×N".
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
	var compact := total_coins > 8   # troppe monete: una per taglio con ×N
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
			x.text = "×%d" % n
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


func _end_turn() -> void:
	if not playing_card.is_empty() or game_over:
		return
	if popup_layer.get_child_count() > 0:
		return  # un popup (Research/riepilogo) e' aperto
	round_turn_count += 1
	if round_turn_count >= 4 * gs.players.size():
		_begin_research()
		return
	active_seat = gs.turn_order[round_turn_count % gs.players.size()]
	_reset_plays()
	_status("Turno di %s." % _active().power.to_upper())
	_after_change()


## Carte giocabili nel turno: 1 di base, +1 al primo turno del round con
## l'abilità "extra_play_first_turn".
func _reset_plays() -> void:
	_plays_left = 1
	if round_turn_count < gs.players.size():
		_plays_left += _ongoing_count(_active(), "extra_play_first_turn")


## Azione Focus: sposta la pedina Focus sulla colonna scelta e prepara (ready) le
## Country card esaurite — 2 di base, +1 per ogni "ready_extra_on_focus". Consuma
## l'azione del turno (come giocare una carta).
func _do_focus(f: int) -> void:
	if not playing_card.is_empty():
		return
	var p := _active()
	# Choose Focus è un passo della PREPARATION: è GRATIS (non costa un'azione) e
	# si fa una volta per round. Dopo, ri-cliccare sposta solo il marker.
	if int(_focus_round.get(p.power, -1)) == gs.round:
		p.focus = f
		_after_change()
		return
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
	# 2) Produce: i tipi specifici di questo Focus (secondarie consumano le primarie;
	#    le Armate vanno nella riserva).
	var produced := []
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
	var msg := "Focus %s" % FOCUS_NAME[f]
	if readied > 0:
		msg += " — preparate %d Country card" % readied
	if produced.size() > 0:
		msg += " · Prodotto: %s" % ", ".join(produced)
	_status(msg + ".")
	_after_change()


# --- Fase Research / Market (fine round, prima dell'Aftermath) ---

func _refill_market() -> void:
	while market_display.size() < MARKET_SLOTS and not market_deck.is_empty():
		market_display.append(market_deck.pop_back())


func _begin_research() -> void:
	_research_idx = 0
	_research_next()


## Passa alla Research del prossimo giocatore (in ordine di turno); poi Aftermath.
func _research_next() -> void:
	if _research_idx >= gs.turn_order.size():
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


func _show_research() -> void:
	var p := _active()
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(480, 0)
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var head := Label.new()
	head.text = "Research — %s   ·   Research disponibili: %d" % [p.power.to_upper(), _research_points]
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	vb.add_child(head)

	vb.add_child(_section("Market (spendi Research):"))
	var mrow := _card_row()
	vb.add_child(mrow)
	for card in market_display:
		var cost := int(card.get("market_cost", 0))
		mrow.add_child(_market_card(card, "costo %d R" % cost, _research_points < cost, _buy_market.bind(card)))

	vb.add_child(_section("Growth (livello %d, spendi risorse):" % _next_growth_level(p)))
	var ag := _available_growth(p)
	if ag.is_empty():
		var none := Label.new()
		none.text = "  (nessuna Growth di questo livello)"
		vb.add_child(none)
	else:
		var grow := _card_row()
		vb.add_child(grow)
		for card in ag:
			grow.add_child(_market_card(card, "%s  +%d VP" % [_cost_text(card.get("cost", {})), int(card.get("victory_points", 0))], not p.has_resources(card.get("cost", {})), _buy_growth.bind(card)))

	var done := Button.new()
	done.text = "Continua"
	done.pressed.connect(func():
		_research_idx += 1
		_close_popup()
		_research_next())
	vb.add_child(done)


func _buy_market(card: Dictionary) -> void:
	var spent := GamePhases.buy_market_card(_active(), card, _research_points)
	if spent >= 0:
		_research_points -= spent
		market_display.erase(card)
		_refill_market()
		_status("Comprata dal Market: %s (−%d Research)." % [card.get("display_name", ""), spent])
		_after_change()
		_show_research()


func _buy_growth(card: Dictionary) -> void:
	var p := _active()
	if Actions.execute_get_growth(p, card, _next_growth_level(p)):
		_status("Get a Growth Card: %s (+%d VP)." % [card.get("display_name", ""), int(card.get("victory_points", 0))])
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
	if _auto_inf_deck.is_empty():
		_auto_inf_deck = DataLoader.load_auto_influence().duplicate()
		_auto_inf_deck.shuffle()
	if _auto_inf_deck.is_empty():
		return ""
	var card: Dictionary = _auto_inf_deck.pop_back()
	GamePhases.add_auto_influence(gs, card, player_powers)
	lines.append("— Auto-Influence (potenze neutrali) —")
	var rows: Dictionary = card.get("rows", {})
	for power in rows:
		if power in player_powers:
			continue
		var row: Dictionary = rows[power]
		var txt := "%s: +Influenza in %s" % [power.to_upper(), String(row.get("region", "")).replace("_", " ")]
		if bool(row.get("army", false)):
			txt += " · +1 Armata"
		lines.append(txt)
	for power in rows:
		var tw: Variant = rows[power].get("trade_with", null)
		if tw != null and String(tw) in player_powers:
			lines.append("%s: +10 money (commercio con %s)" % [String(tw).to_upper(), String(power).to_upper()])
	return String(card.get("art", ""))


func _run_aftermath() -> void:
	gs.phase = WO.Phase.AFTERMATH
	var lines: Array[String] = ["— Aftermath round %d —" % gs.round]
	# Auto-Influence delle potenze neutrali PRIMA di THREAT/Scoring (così contano).
	var ai_art := _apply_auto_influence(lines)

	# Return on Investments: 2 money per ogni FDI × valore del Paese (1° passo Aftermath).
	for p in gs.players:
		var roi := Aftermath.return_on_investments(p, p.fdi_values, [])
		if roi > 0:
			lines.append("%s: +%d money (Return on Investments)" % [p.power.to_upper(), roi])

	# Increase Prosperity (auto, se il giocatore ha abbastanza Consumer Goods).
	var pb: Dictionary = DataLoader.load_player_boards()
	var steps: Array = pb.get("prosperity_track", {}).get("steps_partial", [])
	for p in gs.players:
		if GamePhases.increase_prosperity(p, steps):
			lines.append("%s: Prosperità → liv. %d" % [p.power.to_upper(), p.prosperity_level])

	# Resolve THREAT in ogni Regione.
	var mil_focus := {}
	for p in gs.players:
		mil_focus[p.power] = (p.focus == WO.Focus.MILITARY)
	var nato := [["usa", "eu"]]
	for rid in gs.regions:
		var rd: Dictionary = gs.regions[rid]
		var loss := Threat.resolve_region(rd.get("zone", []), rd.get("armies", {}), mil_focus, {}, nato)
		for power in loss:
			gs.add_vp(power, -int(loss[power]))
			lines.append("%s: −%d VP (THREAT in %s)" % [power.to_upper(), int(loss[power]), rid.replace("_", " ")])

	# Scoring delle Regioni nei round 3 e 6.
	if gs.is_scoring_round():
		var rs := GameRunner.score_all_regions(gs)
		for power in rs:
			gs.add_vp(power, int(rs[power]))
		lines.append("Scoring Regioni: " + _vp_summary(rs))

	_show_summary(lines, func(): _next_round(), ai_art)


## Reveal Country Cards (Preparation): in ogni Regione ruota una carta — la più
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
	round_turn_count = 0
	active_seat = gs.turn_order[0]
	_reset_plays()
	_status("Round %d — Preparazione completata. Turno di %s." % [gs.round, _active().power.to_upper()])
	_after_change()


func _game_end() -> void:
	game_over = true
	var mt := GameRunner.score_majority_tokens(gs)
	for power in mt:
		gs.add_vp(power, int(mt[power]))
	var ranking := gs.players.duplicate()
	ranking.sort_custom(func(a, b): return a.victory_points > b.victory_points)
	var lines: Array[String] = ["— FINE PARTITA —", "Token Maggioranza: " + _vp_summary(mt), ""]
	for i in ranking.size():
		lines.append("%d) %s — %d VP" % [i + 1, ranking[i].power.to_upper(), ranking[i].victory_points])
	lines.append("")
	lines.append("Vincitore: %s" % GameRunner.winner(gs).to_upper())
	_show_summary(lines, func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_after_change()


func _vp_summary(d: Dictionary) -> String:
	var parts := []
	for k in d:
		if int(d[k]) != 0:
			parts.append("%s %+d" % [k.to_upper(), int(d[k])])
	return ", ".join(parts) if parts.size() > 0 else "—"


## Popup di riepilogo con un pulsante Continua.
func _show_summary(lines: Array, cb: Callable, art := "") -> void:
	for c in popup_layer.get_children():
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(420, 0)
	panel.add_child(vb)
	# Carta (es. Auto-Influence) mostrata in cima al riepilogo, con flyover.
	if art != "":
		var tex: Texture2D = load("res://assets/cards/%s" % art)
		if tex:
			var cc := CenterContainer.new()
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var iw := minf(size.x * 0.5, 360.0)
			img.custom_minimum_size = Vector2(iw, iw * 0.42)
			cc.add_child(img)
			vb.add_child(cc)
	for line in lines:
		var l := Label.new()
		l.text = String(line)
		vb.add_child(l)
	var ok := Button.new()
	ok.text = "Continua"
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
	var ch := _hand_card_height()
	for card in _active().hand:
		var btn := _country_card_button(card, Vector2(int(ch * 0.71), ch), false)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.disabled = not playing_card.is_empty() or _plays_left <= 0
		btn.tooltip_text = "%s\n%s" % [card.get("display_name", ""), card.get("effect_text", "")]
		btn.pressed.connect(_on_hand_card.bind(card))
		hand_box.add_child(btn)


## Riga orizzontale scrollabile di carte (Market/Growth) come la mano.
func _card_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	return row


## Carta Market/Growth come IMMAGINE reale + etichetta costo sotto, cliccabile.
func _market_card(card: Dictionary, cost_text: String, disabled: bool, on_press: Callable) -> Control:
	var ch := int(clampf(size.y * 0.22, 88, 180))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var b := Button.new()
	b.custom_minimum_size = Vector2(int(ch * 0.70), ch)
	b.flat = true
	b.disabled = disabled
	b.tooltip_text = "%s\n%s" % [card.get("display_name", ""), card.get("effect_text", "")]
	b.pressed.connect(on_press)
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	lab.add_theme_font_size_override("font_size", maxi(10, _base_fs() - 3))
	lab.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6) if not disabled else Color(0.6, 0.5, 0.5))
	box.add_child(lab)
	return box


func _status(t: String) -> void:
	if status_label:
		status_label.text = t
