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
	"ready_country", "trash", "sell_armies", "spend_for_gain", "spend_then", "repeat"]

var gs: GameState
var active_seat := 0
var board_rect: TextureRect
var overlay: Control
var card_layer: Control            # carte nazione nelle aree designate
var map_viewport: Control          # finestra che ritaglia la mappa
var map_content: Control           # nodo pannato/zoomato (mappa + Regioni)
var board_native: Vector2 = Vector2(2200, 1964)
var _min_zoom := 0.1
var _map_ready := false
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
var card_preview: TextureRect    # anteprima ingrandita della carta (flyover)
var tab_bar: HBoxContainer          # una scheda per ogni potenza in gioco
var drawer_open := false
var drawer_power := ""              # potenza la cui plancia è mostrata nel cassetto
var ui_theme: Theme                 # font/scala globale proporzionale alla viewport

var all_countries: Array = []
var region_countries: Dictionary = {}   # rid -> { available:[c,c], deck:[...] }
var market_deck: Array = []             # mazzo Market mescolato
var market_display: Array = []          # carte Market scoperte (acquistabili)
var growth_pool: Array = []             # tutte le Growth card (per livello)
var _research_idx := 0                  # indice nel turn_order durante la Research
var _research_points := 0               # Research disponibili al giocatore corrente
const MARKET_SLOTS := 5
# Stato del gioco di una carta:
var playing_card: Dictionary = {}
var play_queue: Array = []
var active_mods: Dictionary = {}   # effect_modifiers della carta in gioco (parse)
var awaiting := ""          # "" | "region" | "board_country" | "allied_country"
var awaiting_op: Dictionary = {}
# Gestione round/turni:
var round_turn_count := 0   # turni totali presi nel round corrente
var game_over := false


func _ready() -> void:
	ui_theme = Theme.new()
	theme = ui_theme   # ereditato da tutta la scena: font scalati in _layout_ui
	var powers: Array = GameConfig.powers if GameConfig.powers.size() >= 2 else GameConfig.powers_for_count_n(2)
	gs = GameSetup.new_game(powers)
	for p in gs.players:
		p.draw_cards(6)
		p.money = 30   # denaro iniziale (valore esatto per potenza da rifinire)
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_layout.json"))
	all_countries = DataLoader.load_countries()
	_setup_country_decks()
	market_deck = DataLoader.load_market().duplicate()
	market_deck.shuffle()
	growth_pool = DataLoader.load_growth()
	_refill_market()

	# La mappa vive dentro un nodo pannabile/zoomabile (pinch + trascinamento).
	map_viewport = Control.new()
	map_viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	map_content.position += delta
	_clamp_map()


## Zoom attorno a un punto-schermo mantenendolo fermo.
func _zoom_at(factor: float, focal: Vector2) -> void:
	if map_content == null:
		return
	var s0: float = map_content.scale.x
	var s1: float = clampf(s0 * factor, _min_zoom, _min_zoom * 6.0)
	if is_equal_approx(s0, s1):
		return
	var local := (focal - map_content.position) / s0
	map_content.scale = Vector2(s1, s1)
	map_content.position = focal - local * s1
	_clamp_map()


## Adatta la mappa alla viewport (intera visibile) e centra. Una volta sola.
func _fit_map() -> void:
	if map_content == null or board_native.x <= 0:
		return
	var fit := minf(size.x / board_native.x, size.y / board_native.y)
	_min_zoom = fit
	map_content.scale = Vector2(fit, fit)
	map_content.position = (size - board_native * fit) * 0.5


## Tiene almeno una parte della mappa visibile dopo pan/zoom.
func _clamp_map() -> void:
	if map_content == null:
		return
	var sc: float = map_content.scale.x
	var bw := board_native.x * sc
	var bh := board_native.y * sc
	var margin := 80.0
	var pos := map_content.position
	pos.x = clampf(pos.x, size.x - bw - margin, margin)
	pos.y = clampf(pos.y, size.y - bh - margin, margin)
	map_content.position = pos


func _make_region_button(region: String) -> Button:
	var awaiting_region := (awaiting == "region")
	var btn := Button.new()
	btn.flat = true
	btn.pressed.connect(_on_region_pressed.bind(region))
	# Zona Regione: invisibile di default (il tabellone mostra già nome ed Eng);
	# si evidenzia solo quando devi SCEGLIERE una Regione.
	var st := StyleBoxFlat.new()
	if awaiting_region:
		st.bg_color = Color(0.2, 0.6, 0.95, 0.28)
		st.border_color = Color(0.4, 0.9, 1, 0.95)
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
	# Influenza presente nella Regione (stato di gioco, non stampato sul tabellone).
	var rd: Dictionary = gs.regions.get(region, {})
	var track: InfluenceTrack = rd.get("track")
	if track and track.owners().size() > 0:
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", int(board_native.x * 0.006))
		vb.add_child(hb)
		for owner in track.owners():
			var lbl := Label.new()
			lbl.text = "●%d" % track.count(owner)
			lbl.add_theme_color_override("font_color", POWER_COLORS.get(owner, Color.WHITE))
			lbl.add_theme_font_size_override("font_size", int(board_native.y * 0.013))
			hb.add_child(lbl)
	return btn


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


## Click su una Country disponibile sul board: target di Improve Relations
## (durante una carta) oppure azione diretta.
func _on_country_pressed(country: Dictionary, region: String) -> void:
	if awaiting == "board_country":
		awaiting = ""
		_do_improve_relations(country, region)
		_advance_play()
		return
	if playing_card.is_empty():
		_do_improve_relations(country, region)


func _do_improve_relations(country: Dictionary, region: String) -> void:
	var p := _active()
	var disc := Modifiers.improve_discount(active_mods)
	var cost := Actions.improve_relations_cost(int(country.get("value", 0)), [], disc)
	if p.resources.get("diplomacy", 0) < cost:
		_status("Diplomazia insufficiente per Improve Relations con %s (serve %d)." % [country.get("display_name", ""), cost])
		return
	if Actions.execute_improve_relations(gs, p.power, country, [], disc):
		# rimuovi dalle disponibili e rifornisci
		region_countries.get(region, {}).get("available", []).erase(country)
		_refill_available(region)
		_status("%s: Improve Relations con %s (−%d Dip)." % [p.power.to_upper(), country.get("display_name", ""), cost])
		_after_change()


## Click su una Country alleata (davanti al giocatore): target di Invest/Build a
## Base (durante una carta) oppure menu d'azione diretto.
func _on_allied_pressed(country: Dictionary) -> void:
	var p := _active()
	if awaiting == "allied_country":
		var name := String(awaiting_op.get("op", ""))
		awaiting = ""
		if name == "invest":
			Actions.execute_invest(gs, p.power, country, "temporary")
		elif name == "build_base":
			Actions.execute_build_base(gs, p.power, country, 1, "temporary")
		_after_change()
		_advance_play()
		return
	if playing_card.is_empty():
		_allied_menu(country)


func _allied_menu(country: Dictionary) -> void:
	var p := _active()
	var items := [
		{"label": "Invest (%d money)" % int(country.get("invest_cost", 0)), "value": "invest"},
	]
	if country.get("has_base_symbol", false) and p.power in country.get("base_allowed_powers", []):
		items.append({"label": "Build a Base", "value": "build_base"})
	_show_popup("%s — azione:" % country.get("display_name", ""), items, func(act):
		if act == "invest":
			Actions.execute_invest(gs, p.power, country, "temporary")
		elif act == "build_base":
			Actions.execute_build_base(gs, p.power, country, 1, "temporary")
		_after_change())


func _on_region_pressed(region: String) -> void:
	if awaiting == "region":
		_resolve_region_op(region)
		return
	if awaiting != "":
		return  # in attesa di una Country, non fare Engage rapido
	# nessuna carta in gioco: Engage rapido (demo)
	_do_engage(region)


func _do_engage(region: String) -> void:
	var p := _active()
	var rd: Dictionary = gs.regions[region]
	var cost := Actions.engage_cost(int(rd["engage_cost"]), [], p.focus == WO.Focus.DIPLOMATIC)
	if p.resources.get("diplomacy", 0) < cost:
		_status("Diplomazia insufficiente per Engage in %s (serve %d)." % [region.replace("_", " "), cost])
		return
	var vp := Actions.execute_engage(gs, p.power, region, [], p.focus == WO.Focus.DIPLOMATIC, "temporary")
	_status("%s: Engage in %s (−%d Dip, +%d VP)." % [p.power.to_upper(), region.replace("_", " "), cost, vp])
	_after_change()


# --- Gioco di una carta ---

func _play_card(card: Dictionary) -> void:
	if not playing_card.is_empty():
		return  # gia' in risoluzione
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
		"engage", "move", "add_influence", "place_armies", "move_free", "move_to_regions":
			awaiting = "region"
			awaiting_op = op
			_status("Tocca una Regione sulla mappa per: %s" % name)
			_after_change()   # chiude il cassetto: serve la mappa
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
				_pick_resource("Scegli risorsa da Produrre:", func(rt):
					Actions.execute_produce(_active(), rt)
					_advance_play())
		"choice", "choose_n":
			_pick_choice(op.get("options", []), func(sub):
				# antepone i sotto-op scelti alla coda
				var subs: Array = sub if sub is Array else [sub]
				for i in range(subs.size() - 1, -1, -1):
					play_queue.push_front(subs[i])
				_advance_play())
		"get_growth":
			# semplificazione: prende la prima Growth di livello idoneo
			_status("Get a Growth Card (selezione automatica nel demo).")
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
	match name:
		"engage":
			var ed := Modifiers.engage_discount(active_mods, gs, p.power, region)
			Actions.execute_engage(gs, p.power, region, [], p.focus == WO.Focus.DIPLOMATIC, "temporary", ed)
		"move", "move_free", "move_to_regions":
			if p.armies_available > 0:
				Actions.execute_move(gs, p.power, [{"region": region}]) if name == "move" else _free_move(region)
		"add_influence", "place_armies":
			var slot := "permanent" if bool(op.get("permanent", false)) else "temporary"
			gs.regions[region]["track"].add(p.power, slot)
			if name == "place_armies":
				var a: Dictionary = gs.regions[region]["armies"]
				a[p.power] = int(a.get(p.power, 0)) + int(op.get("n", 1))
	_status("%s su %s." % [name, region.replace("_", " ")])
	_layout_overlays()
	_advance_play()


func _free_move(region: String) -> void:
	var p := _active()
	if p.armies_available > 0:
		p.armies_available -= 1
		var a: Dictionary = gs.regions[region]["armies"]
		a[p.power] = int(a.get(p.power, 0)) + 1


func _finish_card() -> void:
	var p := _active()
	p.hand.erase(playing_card)
	p.played.append(playing_card)
	playing_card = {}
	active_mods = {}
	awaiting = ""
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


func _pick_resource(prompt: String, cb: Callable) -> void:
	var items := []
	for rt in RES:
		items.append({"label": RES_LABEL[rt], "value": rt})
	_show_popup(prompt, items, cb)


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
	col.add_child(scroll)
	drawer_content = VBoxContainer.new()
	drawer_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_theme_constant_override("separation", 8)
	scroll.add_child(drawer_content)
	hand_pinned = VBoxContainer.new()
	hand_pinned.add_theme_constant_override("separation", 2)
	col.add_child(hand_pinned)

	# Una maniglia per ogni potenza in gioco (i "cassetti dei paesi").
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	add_child(tab_bar)
	for pl in gs.players:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(_on_power_tab.bind(pl.power))
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
	tab_bar.position = Vector2(0, h - tab_h)
	tab_bar.size = Vector2(w, tab_h)
	var dy := h * 0.30   # il cassetto copre ~62% dello schermo: ci sta tutto
	drawer.visible = drawer_open
	drawer.position = Vector2(0, dy)
	drawer.size = Vector2(w, maxf(80, h - tab_h - dy - 4))
	if not _map_ready and size.x > 0 and size.y > 0:
		_fit_map()
		_map_ready = true
	else:
		_clamp_map()


## Dimensione font base proporzionale all'altezza del device.
func _base_fs() -> int:
	return clampi(int(size.y * 0.026), 11, 26)


func _on_power_tab(power: String) -> void:
	if awaiting in ["region", "board_country"]:
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
	if awaiting in ["region", "board_country"]:
		drawer_open = false
	elif awaiting == "allied_country":
		drawer_open = true
		drawer_power = _active().power


func _refresh() -> void:
	ui_theme.default_font_size = _base_fs()
	var p := _active()
	_update_drawer_state()
	_refresh_hud(p)
	_refresh_tab_bar()
	if board_bg:
		var tex := load("res://assets/player_boards/%s.jpg" % drawer_power)
		if tex:
			board_bg.texture = tex
	_refresh_drawer_content()
	_layout_ui()


func _refresh_hud(p: PlayerState) -> void:
	for c in hud_box.get_children():
		c.queue_free()
	var my_turn := (round_turn_count / gs.players.size()) + 1
	var who := Label.new()
	who.text = "R%d · %s · t%d/4" % [gs.round, p.power.to_upper(), mini(my_turn, 4)]
	who.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	hud_box.add_child(who)
	hud_box.add_child(_kv("$", p.money))
	hud_box.add_child(_kv("VP", p.victory_points))
	hud_box.add_child(_kv("Prosp", p.prosperity_level))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_box.add_child(spacer)
	var endt := Button.new()
	endt.text = "Fine turno ▶"
	endt.disabled = game_over or not playing_card.is_empty()
	endt.pressed.connect(_end_turn)
	hud_box.add_child(endt)


## Maniglie: una per potenza, colorate; ▶ = a chi tocca, ▼ = cassetto aperto.
func _refresh_tab_bar() -> void:
	var map_lock: bool = awaiting in ["region", "board_country"]
	for i in tab_bar.get_child_count():
		var b: Button = tab_bar.get_child(i)
		var pl: PlayerState = gs.players[i]
		var mark := ""
		if drawer_open and drawer_power == pl.power:
			mark = "▼ "
		elif pl.power == _active().power:
			mark = "▶ "
		b.text = "%s%s" % [mark, pl.power.to_upper()]
		b.disabled = map_lock
		b.add_theme_color_override("font_color", POWER_COLORS.get(pl.power, Color.WHITE))


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

	# (Niente intestazione testuale: VP/$/Prosperità sono già nella barra in alto.)
	# Immagine reale della plancia con i segnalini sopra. Il Focus si sposta
	# toccando direttamente la colonna giusta sulla plancia (giocatore di turno).
	# (Risorse/Produzione/Prosperità non servono come testo: sono i cubi/token.)
	drawer_content.add_child(_build_plancia_view(p, is_active))

	_build_allies_section(p, is_active)
	_build_hand_section(p, is_active)


## Rapporto altezza/larghezza delle immagini plancia (~700x499).
const PLANCIA_RATIO := 0.713
## Passo orizzontale tra due caselle di un tracciato Produzione (normalizzato).
const PROD_PITCH := 0.050
## [x della casella 1, y] normalizzati, MISURATI sull'immagine reale della plancia.
## Le 4 plance condividono il layout; la lunghezza dei tracciati cambia ma le
## caselle partono sempre dalle stesse coordinate, quindi: x = x0 + (livello-1)*passo.
const PROD_TRACKS := {
	"energy": [0.119, 0.205],
	"raw_materials": [0.282, 0.205],
	"food": [0.679, 0.205],
	"consumer_goods": [0.125, 0.527],
	"services": [0.125, 0.606],
	"diplomacy": [0.436, 0.540],
	"armies": [0.751, 0.540],
}
## Cerchi Focus (Domestic, Diplomatic, Military).
const FOCUS_POS := [[0.307, 0.311], [0.600, 0.311], [0.921, 0.311]]
## Tracciato Prosperità: livello 0 (cerchio iniziale) .. 5.
const PROSPERITY_POS := [[0.514, 0.631], [0.600, 0.631], [0.671, 0.631], [0.743, 0.631], [0.814, 0.631], [0.886, 0.631]]
## Colonne x della traccia RESOURCES (numeri 1..5 in alto, 6..10 in basso).
const RES_TRACK_X := [0.21, 0.385, 0.56, 0.735, 0.91]
## Risorse che hanno un token-immagine (armies è un tracciato a parte).
const RES_TOKENS := ["energy", "raw_materials", "food", "consumer_goods", "services", "diplomacy"]


## Costruisce la vista plancia: immagine reale a piena visibilità + segnalini
## (Produzione per ogni risorsa, Risorse possedute, Prosperità).
## Aree cliccabili dei 3 Focus sulla plancia: [x0,x1] per colonna, y [y0,y1].
const FOCUS_ZONES := [[0.02, 0.33], [0.34, 0.66], [0.67, 0.99]]


func _build_plancia_view(p: PlayerState, is_active: bool) -> Control:
	# La plancia ha un TETTO ASSOLUTO in pixel (come le carte) così non diventa mai
	# gigante, qualunque sia la dimensione/densità della finestra; più i limiti
	# proporzionali (larghezza disponibile e frazione d'altezza).
	var ph := minf(minf((size.x - 24.0) * PLANCIA_RATIO, size.y * 0.38), 360.0)
	var pw := ph / PLANCIA_RATIO
	var view := Control.new()
	view.custom_minimum_size = Vector2(pw, ph)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_bg = TextureRect.new()
	board_bg.texture = load("res://assets/player_boards/%s.jpg" % p.power)
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_bg.stretch_mode = TextureRect.STRETCH_SCALE
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(board_bg)
	# Zone Focus cliccabili (solo per il giocatore di turno): toccando la colonna
	# si sposta la pedina del Focus lì. Niente più bottoni di testo sotto.
	if is_active:
		for f in FOCUS_ZONES.size():
			var fb := Button.new()
			fb.flat = true
			fb.position = Vector2(FOCUS_ZONES[f][0] * pw, 0.27 * ph)
			fb.size = Vector2((FOCUS_ZONES[f][1] - FOCUS_ZONES[f][0]) * pw, 0.40 * ph)
			var fst := StyleBoxFlat.new(); fst.bg_color = Color(0, 0, 0, 0)
			fb.add_theme_stylebox_override("normal", fst)
			var fhv := StyleBoxFlat.new(); fhv.bg_color = Color(1, 1, 1, 0.08)
			fb.add_theme_stylebox_override("hover", fhv)
			fb.pressed.connect(func():
				p.focus = f
				_refresh())
			view.add_child(fb)
	var col: Color = POWER_COLORS.get(p.power, Color.WHITE)
	# Cubi di Produzione: uno sul livello attuale di ogni tracciato.
	for res in PROD_TRACKS:
		var lvl := int(p.production.get(res, 0))
		if lvl >= 1:
			var t: Array = PROD_TRACKS[res]
			_add_cube(view, t[0] + (lvl - 1) * PROD_PITCH, t[1], pw, ph, col, false)
	# Marker Focus (sul cerchio della colonna scelta).
	if p.focus >= 0 and p.focus < FOCUS_POS.size():
		_add_cube(view, FOCUS_POS[p.focus][0], FOCUS_POS[p.focus][1], pw, ph, col, true)
	# Marker Prosperità.
	var pl := clampi(p.prosperity_level, 0, PROSPERITY_POS.size() - 1)
	_add_cube(view, PROSPERITY_POS[pl][0], PROSPERITY_POS[pl][1], pw, ph, Color(0.45, 0.95, 0.55), true)
	# Token risorsa (immagini reali) sulla traccia RESOURCES 0..10, alla quantità.
	var stack: Dictionary = {}
	for res in RES_TOKENS:
		var amt := int(p.resources.get(res, 0))
		var slot := _resource_slot(amt)
		var n := int(stack.get(amt, 0))
		stack[amt] = n + 1
		_add_token(view, res, slot.x, slot.y, pw, ph, n)
	return view


## Posizione normalizzata della casella Risorse (0..10): "0" a sinistra, 1-5 in
## alto, 6-10 in basso.
func _resource_slot(amount: int) -> Vector2:
	var a := clampi(amount, 0, 10)
	if a == 0:
		return Vector2(0.06, 0.862)
	if a <= 5:
		return Vector2(RES_TRACK_X[a - 1], 0.812)
	return Vector2(RES_TRACK_X[a - 6], 0.922)


## Cubo/disco segnalino a coordinate normalizzate (circle=true → disco prosperità/focus).
func _add_cube(parent: Control, nx: float, ny: float, pw: float, ph: float, col: Color, circle: bool) -> void:
	var d := ph * (0.082 if circle else 0.074)
	var s := Vector2(d, d)
	var m := Panel.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.position = Vector2(nx * pw - s.x * 0.5, ny * ph - s.y * 0.5)
	m.size = s
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
	var tr := TextureRect.new()
	tr.texture = load("res://assets/tokens/%s.png" % res)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(s, s)
	tr.size = Vector2(s, s)
	tr.position = Vector2(nx * pw - s * 0.5 + stack_index * s * 0.5, ny * ph - s * 0.5)
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
## per il giocatore di turno: Invest/Build a Base).
func _build_allies_section(p: PlayerState, is_active: bool) -> void:
	if awaiting == "allied_country" and is_active:
		drawer_content.add_child(_section("Scegli una nazione amica per: %s" % String(awaiting_op.get("op", ""))))
	else:
		drawer_content.add_child(_section("Nazioni amiche (%d)" % p.allied_countries.size()))
	if p.allied_countries.is_empty():
		return
	var elig: Array = _eligible_allied(String(awaiting_op.get("op", ""))) if (awaiting == "allied_country" and is_active) else []
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, _card_height() + 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	scroll.add_child(row)
	drawer_content.add_child(scroll)
	for cn in p.allied_countries:
		var highlight: bool = is_active and awaiting == "allied_country" and (cn in elig)
		var dim: bool = is_active and awaiting == "allied_country" and not (cn in elig)
		var card := _country_card_button(cn, Vector2(_card_height() * 0.70, _card_height()), highlight)
		card.disabled = (not is_active) or dim
		if is_active:
			card.pressed.connect(_on_allied_pressed.bind(cn))
		row.add_child(card)


## Sezione mano: carte scoperte solo per il giocatore di turno; per gli altri
## (hot-seat) si mostra solo il numero, senza svelare le carte.
func _build_hand_section(p: PlayerState, is_active: bool) -> void:
	# La mano è SEMPRE in basso nel cassetto (hand_pinned), così non scorre mai via.
	if not is_active:
		hand_pinned.add_child(_section("Mano avversario: %d carte (coperte)" % p.hand.size()))
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
	_status("Turno di %s." % _active().power.to_upper())
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
		mrow.add_child(_market_card(card, "costo %d Ⓡ" % cost, _research_points < cost, _buy_market.bind(card)))

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
	done.text = "Continua ▶"
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
func _run_aftermath() -> void:
	gs.phase = WO.Phase.AFTERMATH
	var lines: Array[String] = ["— Aftermath round %d —" % gs.round]

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

	_show_summary(lines, func(): _next_round())


func _next_round() -> void:
	if gs.round >= GameState.TOTAL_ROUNDS:
		_game_end()
		return
	gs.round += 1
	gs.phase = WO.Phase.PREPARATION
	GamePhases.determine_turn_order(gs)
	GamePhases.produce_primary_resources(gs)
	# nuova mano: scarti = mano+giocate, poi pesca 6.
	for p in gs.players:
		p.discard.append_array(p.hand); p.discard.append_array(p.played)
		p.hand.clear(); p.played.clear()
		p.draw_cards(6)
	round_turn_count = 0
	active_seat = gs.turn_order[0]
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
	lines.append("🏆 Vincitore: %s" % GameRunner.winner(gs).to_upper())
	_show_summary(lines, func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_after_change()


func _vp_summary(d: Dictionary) -> String:
	var parts := []
	for k in d:
		if int(d[k]) != 0:
			parts.append("%s %+d" % [k.to_upper(), int(d[k])])
	return ", ".join(parts) if parts.size() > 0 else "—"


## Popup di riepilogo con un pulsante Continua.
func _show_summary(lines: Array, cb: Callable) -> void:
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
	for line in lines:
		var l := Label.new()
		l.text = String(line)
		vb.add_child(l)
	var ok := Button.new()
	ok.text = "Continua ▶"
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
		btn.disabled = not playing_card.is_empty()
		btn.tooltip_text = "%s\n%s" % [card.get("display_name", ""), card.get("effect_text", "")]
		btn.pressed.connect(_play_card.bind(card))
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
