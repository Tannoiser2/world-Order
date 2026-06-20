extends Control
## Splash / menu principale: copertina del regolamento, scelta numero giocatori,
## modalita' (Hot Seat / Online), Opzioni (placeholder) e avvio partita.

var _player_count := 2
var _count_buttons: Array[Button] = []
var _mode := "hotseat"
var _mode_buttons: Array[Button] = []


func _ready() -> void:
	# Sfondo: copertina del regolamento.
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/cover.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Velo scuro per leggibilita'.
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.45)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(420, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "WORLD ORDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Versione digitale — uso personale"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	box.add_child(subtitle)

	box.add_child(_spacer(8))

	# Numero giocatori.
	box.add_child(_section_label("Numero di giocatori"))
	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 10)
	box.add_child(counts)
	for n in [2, 3, 4]:
		var b := Button.new()
		b.text = str(n)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(60, 44)
		b.pressed.connect(_on_count.bind(n))
		counts.add_child(b)
		_count_buttons.append(b)

	# Modalita' di gioco.
	box.add_child(_section_label("Modalità"))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10)
	box.add_child(modes)
	var hot := Button.new()
	hot.text = "Hot Seat"
	hot.toggle_mode = true
	hot.custom_minimum_size = Vector2(140, 44)
	hot.pressed.connect(_on_mode.bind("hotseat"))
	modes.add_child(hot)
	_mode_buttons.append(hot)
	var online := Button.new()
	online.text = "Online (presto)"
	online.disabled = true
	online.custom_minimum_size = Vector2(140, 44)
	modes.add_child(online)

	box.add_child(_spacer(8))

	# Opzioni (placeholder).
	var opts := Button.new()
	opts.text = "Opzioni (prossimamente)"
	opts.disabled = true
	box.add_child(opts)

	# Avvia.
	var play := Button.new()
	play.text = "▶  Avvia partita"
	play.custom_minimum_size = Vector2(0, 52)
	play.add_theme_font_size_override("font_size", 22)
	play.pressed.connect(_on_play)
	box.add_child(play)

	_update_selection(_count_buttons, 0)   # 2 giocatori
	_update_selection(_mode_buttons, 0)    # hot seat


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_count(n: int) -> void:
	_player_count = n
	_update_selection(_count_buttons, [2, 3, 4].find(n))


func _on_mode(m: String) -> void:
	_mode = m
	_update_selection(_mode_buttons, 0)


func _update_selection(buttons: Array, idx: int) -> void:
	for i in buttons.size():
		buttons[i].button_pressed = (i == idx)


func _on_play() -> void:
	GameConfig.player_count = _player_count
	GameConfig.mode = _mode
	GameConfig.powers = GameConfig.powers_for_count()
	get_tree().change_scene_to_file("res://scenes/board.tscn")
