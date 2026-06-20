extends Control
## Scena di gioco (Fase 2, MVP hot-seat): mostra il tabellone reale come sfondo,
## sovrappone gli overlay delle 7 Regioni (costo Engage + Influenza per potenza)
## e un pannello del giocatore attivo. La logica vive nel motore (GameState);
## questa scena e' solo renderer + input.

const POWER_COLORS := {
	"usa": Color(0.45, 0.62, 0.9), "eu": Color(0.95, 0.82, 0.2),
	"russia": Color(0.85, 0.85, 0.85), "china": Color(0.85, 0.2, 0.2),
	"local": Color(0.2, 0.2, 0.2),
}

var gs: GameState
var board_rect: TextureRect
var overlay: Control
var layout: Dictionary


func _ready() -> void:
	# Partita configurata dal menu (default 2 giocatori se avviata direttamente).
	var powers: Array = GameConfig.powers if GameConfig.powers.size() == GameConfig.player_count else GameConfig.powers_for_count()
	gs = GameSetup.new_game(powers)
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_layout.json"))

	board_rect = TextureRect.new()
	board_rect.texture = load(layout.get("board_image", "res://assets/board/board.jpg"))
	board_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	board_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board_rect)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	_build_player_panel()
	resized.connect(_layout_overlays)
	_layout_overlays()


## Rettangolo (in pixel della scena) occupato dall'immagine del tabellone,
## tenendo conto del letterboxing di STRETCH_KEEP_ASPECT_CENTERED.
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
		var panel := _make_region_panel(region)
		panel.position = br.position + Vector2(r[0] * br.size.x, r[1] * br.size.y)
		panel.size = Vector2((r[2] - r[0]) * br.size.x, (r[3] - r[1]) * br.size.y)
		overlay.add_child(panel)


func _make_region_panel(region: String) -> Control:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.border_color = Color(1, 1, 1, 0.5)
	style.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	p.add_child(vb)
	var rd: Dictionary = gs.regions.get(region, {})
	var title := Label.new()
	title.text = "%s  (Engage %d)" % [region.replace("_", " ").to_upper(), int(rd.get("engage_cost", 0))]
	title.add_theme_font_size_override("font_size", 12)
	vb.add_child(title)

	# Conteggio Influenza per potenza presente.
	var track: InfluenceTrack = rd.get("track")
	if track:
		var hb := HBoxContainer.new()
		vb.add_child(hb)
		for owner in track.owners():
			var lbl := Label.new()
			lbl.text = "●%d" % track.count(owner)
			lbl.add_theme_color_override("font_color", POWER_COLORS.get(owner, Color.WHITE))
			hb.add_child(lbl)
	return p


func _build_player_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.92)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	panel.add_child(hb)
	var p: PlayerState = gs.players[0]
	var info := Label.new()
	info.text = "Round %d — Giocatore: %s   Money %d   VP %d   Mano %d" % [
		gs.round, p.power.to_upper(), p.money, p.victory_points, p.deck.size()]
	hb.add_child(info)
