extends Control
## Scena di gioco (Fase 2, MVP hot-seat): tabellone reale + Regioni cliccabili,
## plancia del giocatore attivo (risorse/produzione/Focus) e mano di carte.
## Renderer + input sullo stato del motore (GameState).

const POWER_COLORS := {
	"usa": Color(0.45, 0.62, 0.9), "eu": Color(0.95, 0.82, 0.2),
	"russia": Color(0.9, 0.9, 0.9), "china": Color(0.9, 0.3, 0.3),
	"local": Color(0.3, 0.3, 0.3),
}
const RES_LABEL := {
	"energy": "⚡", "raw_materials": "⛏", "food": "🌾",
	"consumer_goods": "📱", "services": "💼", "diplomacy": "⚖", "armies": "🛡",
}
const FOCUS_NAME := ["Domestic", "Diplomatic", "Military"]

var gs: GameState
var active_seat := 0
var board_rect: TextureRect
var overlay: Control
var layout: Dictionary
var status_label: Label
var player_panel: VBoxContainer
var hand_box: HBoxContainer


func _ready() -> void:
	var powers: Array = GameConfig.powers if GameConfig.powers.size() >= 2 else GameConfig.powers_for_count_n(2)
	gs = GameSetup.new_game(powers)
	# dota i giocatori di una mano e di un po' di Diplomacy per il demo interattivo.
	for p in gs.players:
		p.draw_cards(6)
		p.resources["diplomacy"] = 8
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_layout.json"))

	board_rect = TextureRect.new()
	board_rect.texture = load(layout.get("board_image", "res://assets/board/board.jpg"))
	board_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	board_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board_rect)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_build_player_panel()
	_build_hand_panel()
	resized.connect(_layout_overlays)
	_layout_overlays()
	_refresh()


func _active() -> PlayerState:
	return gs.players[active_seat]


func _board_image_rect() -> Rect2:
	var tex := board_rect.texture
	if tex == null:
		return Rect2(Vector2.ZERO, size)
	var tex_size := tex.get_size()
	var scale := minf(size.x / tex_size.x, size.y / tex_size.y)
	var draw := tex_size * scale
	return Rect2((size - draw) * 0.5, draw)


func _layout_overlays() -> void:
	for child in overlay.get_children():
		child.queue_free()
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
	btn.tooltip_text = "Engage in %s" % region.replace("_", " ")
	btn.pressed.connect(_on_region_pressed.bind(region))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.18)
	style.border_color = Color(1, 1, 1, 0.35)
	style.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.2, 0.5, 0.9, 0.35)
	btn.add_theme_stylebox_override("hover", hover)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(vb)
	var rd: Dictionary = gs.regions.get(region, {})
	var title := Label.new()
	title.text = "%s (Eng %d)" % [region.replace("_", " ").to_upper(), int(rd.get("engage_cost", 0))]
	title.add_theme_font_size_override("font_size", 11)
	vb.add_child(title)
	var track: InfluenceTrack = rd.get("track")
	if track:
		var hb := HBoxContainer.new()
		vb.add_child(hb)
		for owner in track.owners():
			var lbl := Label.new()
			lbl.text = "●%d" % track.count(owner)
			lbl.add_theme_color_override("font_color", POWER_COLORS.get(owner, Color.WHITE))
			hb.add_child(lbl)
	return btn


func _on_region_pressed(region: String) -> void:
	var p := _active()
	var rd: Dictionary = gs.regions[region]
	var cost := Actions.engage_cost(int(rd["engage_cost"]), [], p.focus == WO.Focus.DIPLOMATIC)
	if p.resources.get("diplomacy", 0) < cost:
		status_label.text = "Diplomazia insufficiente per Engage in %s (serve %d)." % [region.replace("_", " "), cost]
		return
	var vp := Actions.execute_engage(gs, p.power, region, [], p.focus == WO.Focus.DIPLOMATIC, "temporary")
	status_label.text = "%s: Engage in %s (−%d ⚖, +%d VP)." % [p.power.to_upper(), region.replace("_", " "), cost, vp]
	_layout_overlays()
	_refresh()


# --- Plancia giocatore ---

func _build_player_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 88
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.92)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	player_panel = VBoxContainer.new()
	panel.add_child(player_panel)


func _refresh() -> void:
	for c in player_panel.get_children():
		c.queue_free()
	var p := _active()
	# riga 1: identita' + money + VP + Focus
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 16)
	player_panel.add_child(row1)
	var who := Label.new()
	who.text = "Round %d  ·  %s" % [gs.round, p.power.to_upper()]
	who.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	who.add_theme_font_size_override("font_size", 18)
	row1.add_child(who)
	row1.add_child(_kv("💰", p.money))
	row1.add_child(_kv("VP", p.victory_points))
	# Focus switch
	for f in 3:
		var b := Button.new()
		b.text = FOCUS_NAME[f]
		b.toggle_mode = true
		b.button_pressed = (p.focus == f)
		b.pressed.connect(func(): p.focus = f; _refresh())
		row1.add_child(b)
	# cambia giocatore (hot seat)
	if gs.players.size() > 1:
		var nxt := Button.new()
		nxt.text = "Giocatore successivo ▶"
		nxt.pressed.connect(_next_player)
		row1.add_child(nxt)
	# riga 2: risorse (valore / produzione)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	player_panel.add_child(row2)
	for rtype in ["energy", "raw_materials", "food", "consumer_goods", "services", "diplomacy", "armies"]:
		var l := Label.new()
		l.text = "%s %d/%d" % [RES_LABEL[rtype], int(p.resources.get(rtype, 0)), int(p.production.get(rtype, 0))]
		row2.add_child(l)
	_build_hand_panel()


func _kv(k: String, v: int) -> Label:
	var l := Label.new()
	l.text = "%s %d" % [k, v]
	l.add_theme_font_size_override("font_size", 16)
	return l


func _next_player() -> void:
	active_seat = (active_seat + 1) % gs.players.size()
	status_label.text = "Turno di %s." % _active().power.to_upper()
	_layout_overlays()
	_refresh()


# --- Mano di carte ---

func _build_hand_panel() -> void:
	if hand_box == null:
		var panel := PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		panel.offset_top = -180
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.1, 0.92)
		panel.add_child(_make_hand_container())
		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)
		# status sopra la mano
		status_label = Label.new()
		status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		status_label.offset_top = -200
		status_label.offset_bottom = -182
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(status_label)
	_render_hand()


func _make_hand_container() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 6)
	scroll.add_child(hand_box)
	return scroll


func _render_hand() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	for card in _active().hand:
		var tr := TextureRect.new()
		var art: String = card.get("art", "")
		if art != "":
			var tex := load("res://assets/cards/" + art)
			if tex: tr.texture = tex
		tr.custom_minimum_size = Vector2(110, 158)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.tooltip_text = "%s\n%s" % [card.get("display_name", ""), card.get("effect_text", "")]
		hand_box.add_child(tr)
