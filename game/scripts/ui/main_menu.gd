extends Control
## Splash / menu principale: copertina del regolamento, scelta numero giocatori,
## selezione delle potenze (col vincolo del 2 giocatori), modalita' (Hot Seat /
## Online), Opzioni (placeholder) e avvio partita.

const POWERS := ["usa", "eu", "russia", "china"]
const POWER_NAME := {"usa": "USA", "eu": "UE", "russia": "Russia", "china": "Cina"}
const POWER_COLOR := {
	"usa": Color(0.45, 0.62, 0.9), "eu": Color(0.95, 0.82, 0.2),
	"russia": Color(0.9, 0.9, 0.9), "china": Color(0.9, 0.3, 0.3),
}

var _player_count := 2
var _count_buttons: Array[Button] = []
var _mode := "hotseat"
var _mode_buttons: Array[Button] = []
var _seat_powers: Array = []          # potenza scelta per seggio
var _seats_box: VBoxContainer
var _warn: Label


func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/cover.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.5)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(460, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "WORLD ORDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	box.add_child(_section_label("Numero di giocatori"))
	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 10)
	box.add_child(counts)
	for n in [2, 3, 4]:
		var b := Button.new()
		b.text = str(n)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(56, 40)
		b.pressed.connect(_on_count.bind(n))
		counts.add_child(b)
		_count_buttons.append(b)

	box.add_child(_section_label("Potenze"))
	_seats_box = VBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 6)
	box.add_child(_seats_box)

	box.add_child(_section_label("Modalità"))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10)
	box.add_child(modes)
	var hot := Button.new()
	hot.text = "Hot Seat"
	hot.toggle_mode = true
	hot.custom_minimum_size = Vector2(140, 40)
	hot.pressed.connect(_on_mode.bind("hotseat"))
	modes.add_child(hot)
	_mode_buttons.append(hot)
	var online := Button.new()
	online.text = "Online (presto)"
	online.disabled = true
	online.custom_minimum_size = Vector2(140, 40)
	modes.add_child(online)

	var opts := Button.new()
	opts.text = "Opzioni (prossimamente)"
	opts.disabled = true
	box.add_child(opts)

	_warn = Label.new()
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	box.add_child(_warn)

	var play := Button.new()
	play.text = "▶  Avvia partita"
	play.custom_minimum_size = Vector2(0, 50)
	play.add_theme_font_size_override("font_size", 22)
	play.pressed.connect(_on_play)
	box.add_child(play)

	_update_selection(_count_buttons, 0)
	_update_selection(_mode_buttons, 0)
	_set_count(2)


# --- Numero giocatori / potenze ---

func _on_count(n: int) -> void:
	_set_count(n)
	_update_selection(_count_buttons, [2, 3, 4].find(n))


func _set_count(n: int) -> void:
	_player_count = n
	# default sensati e validi (rispettano il vincolo del 2 giocatori).
	_seat_powers = GameConfig.powers_for_count_n(n).duplicate()
	_rebuild_seats()


## Potenze ammesse per un seggio (vincolo del 2 giocatori).
func _allowed_for_seat(seat: int) -> Array:
	if _player_count == 2:
		return ["usa", "eu"] if seat == 0 else ["russia", "china"]
	return POWERS.duplicate()


func _rebuild_seats() -> void:
	for c in _seats_box.get_children():
		c.queue_free()
	for seat in _player_count:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		var lbl := Label.new()
		lbl.text = "Giocatore %d:" % (seat + 1)
		lbl.custom_minimum_size = Vector2(96, 0)
		row.add_child(lbl)
		for power in _allowed_for_seat(seat):
			var b := Button.new()
			b.text = POWER_NAME[power]
			b.toggle_mode = true
			b.button_pressed = (_seat_powers[seat] == power)
			b.custom_minimum_size = Vector2(72, 36)
			b.add_theme_color_override("font_color", POWER_COLOR[power])
			# disabilita se gia' scelta da un altro seggio
			b.disabled = (power in _seat_powers and _seat_powers[seat] != power)
			b.pressed.connect(_on_pick_power.bind(seat, power))
			row.add_child(b)
		_seats_box.add_child(row)
	_validate()


func _on_pick_power(seat: int, power: String) -> void:
	_seat_powers[seat] = power
	_rebuild_seats()


func _validate() -> bool:
	var chosen := {}
	for p in _seat_powers:
		if p == "" or chosen.has(p):
			_warn.text = "Assegna una potenza diversa a ogni giocatore."
			return false
		chosen[p] = true
	_warn.text = ""
	return true


# --- Modalita' / avvio ---

func _on_mode(m: String) -> void:
	_mode = m
	_update_selection(_mode_buttons, 0)


func _on_play() -> void:
	if not _validate():
		return
	GameConfig.player_count = _player_count
	GameConfig.mode = _mode
	GameConfig.powers = _seat_powers.duplicate()
	get_tree().change_scene_to_file("res://scenes/board.tscn")


# --- helper UI ---

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	return l


func _update_selection(buttons: Array, idx: int) -> void:
	for i in buttons.size():
		buttons[i].button_pressed = (i == idx)
