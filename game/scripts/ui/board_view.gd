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
var tab_bar: HBoxContainer          # maniglie sempre visibili in basso
var drawer_open := false
var drawer_tab := 0                 # 0 Plancia · 1 Alleati · 2 Mano
const DRAWER_TABS := ["Plancia", "Alleati", "Mano"]

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
	var powers: Array = GameConfig.powers if GameConfig.powers.size() >= 2 else GameConfig.powers_for_count_n(2)
	gs = GameSetup.new_game(powers)
	for p in gs.players:
		p.draw_cards(6)
		p.resources["diplomacy"] = 8
		p.money = 30
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_layout.json"))
	all_countries = DataLoader.load_countries()
	_setup_country_decks()
	market_deck = DataLoader.load_market().duplicate()
	market_deck.shuffle()
	growth_pool = DataLoader.load_growth()
	_refill_market()

	board_rect = TextureRect.new()
	board_rect.texture = load(layout.get("board_image", "res://assets/board/board.jpg"))
	board_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	board_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board_rect)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_build_hud()
	_build_drawer()
	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)

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

func _board_image_rect() -> Rect2:
	var tex := board_rect.texture
	if tex == null:
		return Rect2(Vector2.ZERO, size)
	var ts := tex.get_size()
	var sc := minf(size.x / ts.x, size.y / ts.y)
	return Rect2((size - ts * sc) * 0.5, ts * sc)


func _layout_overlays() -> void:
	for c in overlay.get_children():
		c.queue_free()
	var br := _board_image_rect()
	for region in layout.get("regions", {}):
		var r: Array = layout["regions"][region]
		var btn := _make_region_button(region)
		btn.position = br.position + Vector2(r[0] * br.size.x, r[1] * br.size.y)
		btn.size = Vector2((r[2] - r[0]) * br.size.x, (r[3] - r[1]) * br.size.y)
		overlay.add_child(btn)


func _make_region_button(region: String) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.pressed.connect(_on_region_pressed.bind(region))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.2, 0.6, 0.95, 0.30) if awaiting == "region" else Color(0, 0, 0, 0.15)
	st.border_color = Color(0.4, 0.9, 1, 0.9) if awaiting == "region" else Color(1, 1, 1, 0.3)
	st.set_border_width_all(2 if awaiting == "region" else 1)
	btn.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate(); hv.bg_color = Color(0.2, 0.5, 0.9, 0.40)
	btn.add_theme_stylebox_override("hover", hv)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(vb)
	var rd: Dictionary = gs.regions.get(region, {})
	var t := Label.new()
	t.text = "%s (Eng %d)" % [region.replace("_", " ").to_upper(), int(rd.get("engage_cost", 0))]
	t.add_theme_font_size_override("font_size", 11)
	vb.add_child(t)
	var track: InfluenceTrack = rd.get("track")
	if track:
		var hb := HBoxContainer.new()
		vb.add_child(hb)
		for owner in track.owners():
			var lbl := Label.new()
			lbl.text = "●%d" % track.count(owner)
			lbl.add_theme_color_override("font_color", POWER_COLORS.get(owner, Color.WHITE))
			hb.add_child(lbl)
	# Country disponibili (cliccabili per Improve Relations).
	for cn in region_countries.get(region, {}).get("available", []):
		var cb := Button.new()
		cb.text = "%s (%d)" % [cn.get("display_name", "?"), int(cn.get("value", 0))]
		cb.add_theme_font_size_override("font_size", 10)
		cb.pressed.connect(_on_country_pressed.bind(cn, region))
		var hl := (awaiting == "board_country")
		if hl:
			cb.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
		vb.add_child(cb)
	return btn


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


## Cassetto in basso: immagine della plancia di produzione come fondale, velo per
## leggibilità, contenuto a schede (Plancia / Alleati / Mano). Sotto, una barra di
## maniglie sempre visibile che apre/chiude e seleziona la scheda.
func _build_drawer() -> void:
	drawer = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.09, 0.98)
	st.set_corner_radius_all(10)
	drawer.add_theme_stylebox_override("panel", st)
	drawer.visible = false
	add_child(drawer)

	board_bg = TextureRect.new()
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	board_bg.modulate = Color(1, 1, 1, 0.35)
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.add_child(board_bg)
	drawer_veil = ColorRect.new()
	drawer_veil.color = Color(0.04, 0.05, 0.08, 0.62)
	drawer_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.add_child(drawer_veil)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 10)
	drawer.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	drawer_content = VBoxContainer.new()
	drawer_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_theme_constant_override("separation", 8)
	scroll.add_child(drawer_content)

	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	add_child(tab_bar)
	for i in DRAWER_TABS.size():
		var b := Button.new()
		b.toggle_mode = false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab_pressed.bind(i))
		tab_bar.add_child(b)


## Posiziona HUD, cassetto e barra schede in base alla dimensione corrente del
## device (responsive). La mappa resta a tutto schermo dietro.
func _layout_ui() -> void:
	if top_hud == null:
		return
	var w := size.x
	var h := size.y
	var hud_h := clampf(h * 0.10, 46, 84)
	top_hud.position = Vector2.ZERO
	top_hud.size = Vector2(w, hud_h)
	var tab_h := clampf(h * 0.065, 38, 56)
	tab_bar.position = Vector2(0, h - tab_h)
	tab_bar.size = Vector2(w, tab_h)
	var dy := h * 0.34
	drawer.visible = drawer_open
	drawer.position = Vector2(0, dy)
	drawer.size = Vector2(w, maxf(80, h - tab_h - dy - 4))


func _on_tab_pressed(idx: int) -> void:
	# Durante un'interazione con la mappa il cassetto resta chiuso.
	if awaiting in ["region", "board_country"]:
		return
	if drawer_open and drawer_tab == idx:
		drawer_open = false
	else:
		drawer_open = true
		drawer_tab = idx
	_refresh()


## Apre/chiude automaticamente il cassetto in base allo stato di gioco: chiuso
## quando si deve toccare la mappa, aperto su "Alleati" quando serve scegliere un
## Country alleato (Invest/Build a Base).
func _update_drawer_state() -> void:
	if awaiting in ["region", "board_country"]:
		drawer_open = false
	elif awaiting == "allied_country":
		drawer_open = true
		drawer_tab = 1


func _refresh() -> void:
	var p := _active()
	_update_drawer_state()
	_refresh_hud(p)
	_refresh_tab_bar(p)
	if board_bg:
		var tex := load("res://assets/player_boards/%s.jpg" % p.power)
		if tex:
			board_bg.texture = tex
	_refresh_drawer_content(p)
	_layout_ui()


func _refresh_hud(p: PlayerState) -> void:
	for c in hud_box.get_children():
		c.queue_free()
	var my_turn := (round_turn_count / gs.players.size()) + 1
	var who := Label.new()
	who.text = "R%d · %s · t%d/4" % [gs.round, p.power.to_upper(), mini(my_turn, 4)]
	who.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	who.add_theme_font_size_override("font_size", 17)
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


## Etichette delle maniglie: nome scheda + contatore, freccia su/giù secondo
## lo stato del cassetto. Disabilitate durante un'interazione con la mappa.
func _refresh_tab_bar(p: PlayerState) -> void:
	var counts := ["", " (%d)" % p.allied_countries.size(), " (%d)" % p.hand.size()]
	var map_lock: bool = awaiting in ["region", "board_country"]
	for i in tab_bar.get_child_count():
		var b: Button = tab_bar.get_child(i)
		var arrow := "▼" if (drawer_open and drawer_tab == i) else "▲"
		b.text = "%s %s%s" % [arrow, DRAWER_TABS[i], counts[i]]
		b.disabled = map_lock
		if drawer_open and drawer_tab == i:
			b.add_theme_color_override("font_color", Color(0.6, 1, 0.7))
		else:
			b.remove_theme_color_override("font_color")


func _refresh_drawer_content(p: PlayerState) -> void:
	for c in drawer_content.get_children():
		c.queue_free()
	if not drawer_open:
		return
	match drawer_tab:
		0: _build_plancia_tab(p)
		1: _build_alleati_tab(p)
		2: _build_mano_tab(p)


## Scheda Plancia: Focus, produzioni/risorse, tracciato Prosperità.
func _build_plancia_tab(p: PlayerState) -> void:
	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 6)
	drawer_content.add_child(_section("Focus"))
	drawer_content.add_child(focus_row)
	for f in 3:
		var b := Button.new()
		b.text = FOCUS_NAME[f]
		b.toggle_mode = true
		b.button_pressed = (p.focus == f)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): p.focus = f; _refresh())
		focus_row.add_child(b)

	drawer_content.add_child(_section("Risorse / Produzione"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	drawer_content.add_child(grid)
	for rtype in RES:
		grid.add_child(_kv2("%s %d/%d" % [RES_LABEL[rtype], int(p.resources.get(rtype, 0)), int(p.production.get(rtype, 0))]))

	drawer_content.add_child(_section("Prosperità"))
	var pb: Dictionary = DataLoader.load_player_boards()
	var steps: Array = pb.get("prosperity_track", {}).get("steps_partial", [])
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 4)
	drawer_content.add_child(strip)
	for i in steps.size():
		var step: Dictionary = steps[i]
		var cell := Label.new()
		cell.text = "  %dCG→%dVP  " % [int(step.get("cost_consumer_goods", 0)), int(step.get("vp", 0))]
		cell.add_theme_font_size_override("font_size", 12)
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


## Scheda Alleati: Country alleate cliccabili (Invest/Build a Base).
func _build_alleati_tab(p: PlayerState) -> void:
	if awaiting == "allied_country":
		drawer_content.add_child(_section("Scegli un Country alleato per: %s" % String(awaiting_op.get("op", ""))))
	else:
		drawer_content.add_child(_section("Country alleate (tocca per Invest / Build a Base)"))
	if p.allied_countries.is_empty():
		drawer_content.add_child(_kv2("  Nessun alleato: fai Improve Relations sul tabellone."))
		return
	var elig: Array = _eligible_allied(String(awaiting_op.get("op", ""))) if awaiting == "allied_country" else []
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	drawer_content.add_child(grid)
	for cn in p.allied_countries:
		var ab := Button.new()
		ab.text = "%s (%d) · %s" % [cn.get("display_name", "?"), int(cn.get("value", 0)), String(cn.get("region", "")).replace("_", " ")]
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.clip_text = true
		ab.pressed.connect(_on_allied_pressed.bind(cn))
		if awaiting == "allied_country":
			if cn in elig:
				ab.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
			else:
				ab.disabled = true
		grid.add_child(ab)


## Scheda Mano: le carte giocabili (tocca per giocare).
func _build_mano_tab(p: PlayerState) -> void:
	drawer_content.add_child(_section("La tua mano (tocca una carta per giocarla)"))
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, _card_height() + 16)
	scroll.add_child(hand_box)
	drawer_content.add_child(scroll)
	_render_hand()


func _card_height() -> int:
	return int(clampf(size.y * 0.22, 130, 260))


func _kv(k: String, v: int) -> Label:
	var l := Label.new(); l.text = "%s %d" % [k, v]; l.add_theme_font_size_override("font_size", 16); return l


func _kv2(t: String) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", 13); return l


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
	for card in market_display:
		var cost := int(card.get("market_cost", 0))
		var b := Button.new()
		b.text = "%s  —  costo %d  (%s)" % [card.get("display_name", "?"), cost, card.get("type", "")]
		b.disabled = _research_points < cost
		b.pressed.connect(_buy_market.bind(card))
		vb.add_child(b)

	vb.add_child(_section("Growth (livello %d, spendi risorse):" % _next_growth_level(p)))
	var ag := _available_growth(p)
	if ag.is_empty():
		var none := Label.new()
		none.text = "  (nessuna Growth di questo livello)"
		vb.add_child(none)
	for card in ag:
		var b := Button.new()
		b.text = "%s  —  %s  (+%d VP)" % [card.get("display_name", "?"), _cost_text(card.get("cost", {})), int(card.get("victory_points", 0))]
		b.disabled = not p.has_resources(card.get("cost", {}))
		b.pressed.connect(_buy_growth.bind(card))
		vb.add_child(b)

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
	var ch := _card_height()
	for card in _active().hand:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(int(ch * 0.70), ch)
		btn.flat = true
		btn.disabled = not playing_card.is_empty()
		btn.tooltip_text = "%s\n%s" % [card.get("display_name", ""), card.get("effect_text", "")]
		btn.pressed.connect(_play_card.bind(card))
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var art: String = card.get("art", "")
		if art != "":
			var tex := load("res://assets/cards/" + art)
			if tex: tr.texture = tex
		btn.add_child(tr)
		hand_box.add_child(btn)


func _status(t: String) -> void:
	if status_label:
		status_label.text = t
