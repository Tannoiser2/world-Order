extends Control
## Splash / menu principale: copertina del regolamento, scelta numero giocatori,
## selezione delle potenze (col vincolo del 2 giocatori), modalita' (Hot Seat /
## Online), Opzioni (placeholder) e avvio partita.

## Versione e changelog mostrati nello splash. Aggiornare a ogni rilascio.
const VERSION := "v0.7.0"
const CHANGELOG := [
	"v0.6.7 — Regole: ordine di turno corretto (più VP gioca per primo). Strategic Asset nel setup (pesca 3, tiene 2 → VP iniziali). Vedi TODO.md per lo stato regole↔meccanica.",
	"v0.6.6 — Cubi produzione ricalibrati (3 colonne: erano sbagliati materie prime/grano/diplomazia). Linguette potenze con BANDIERE su barra dedicata in basso (non coprono la mappa). Mano collassabile (toggle) così non copre mai la plancia.",
	"v0.6.5 — Setup iniziale esatto: produzioni di partenza corrette per ogni potenza, risorse iniziali = produzione, nazioni amiche iniziali complete (4-5 per potenza). Nazioni amiche a destra della plancia (griglia). Prosperità e risorse ricalibrate.",
	"v0.6.4 — Cassetto: plancia a sinistra, nazioni amiche, mano in basso. Segnalini ancorati alla plancia.",
	"v0.6.3 — FIX plancia gigante: all'immagine mancava expand_mode=IGNORE_SIZE, non scendeva sotto la dimensione nativa (1400px).",
	"v0.6.2 — Tentativo tetto massimo plancia (non bastava da solo).",
	"v0.6.1 — Tolte le scritte ridondanti nel cassetto (intestazione potenza, 'La tua mano'). Flyover anche su mano e nazioni amiche. (Se non vedi questa versione nello splash, svuota la cache.)",
	"v0.6.0 — Flyover: passa sopra una carta per ingrandirla. Plancia adattiva (niente più gigante su desktop). Mano del giocatore sempre visibile in basso; carte più grandi.",
	"v0.5.0 — Mazzi potenza completi (12 carte, doppioni inclusi). Nazioni amiche iniziali (dal salvataggio TTS). Plancia con cubi/token reali e Focus cliccabile direttamente sull'immagine.",
	"v0.4.0 — Carte nazione originali posate negli slot designati del tabellone (coordinate dal TTS). Market/Growth illustrate.",
	"v0.3.0 — Mappa con zoom e trascinamento. Plance reali con i segnalini.",
	"v0.2.0 — UI responsive, cassetti per potenza.",
]

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

	var ver := Label.new()
	ver.text = VERSION
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	box.add_child(ver)

	_build_changelog()

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


## Pannello changelog ancorato in basso a destra, scrollabile.
func _build_changelog() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -340
	panel.offset_top = -210
	panel.offset_right = -12
	panel.offset_bottom = -12
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.09, 0.85)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var head := Label.new()
	head.text = "Novità — %s" % VERSION
	head.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	vb.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size = Vector2(310, 0)
	scroll.add_child(list)
	for entry in CHANGELOG:
		var e := Label.new()
		e.text = "• " + String(entry)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(310, 0)
		e.add_theme_font_size_override("font_size", 12)
		e.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
		list.add_child(e)


func _update_selection(buttons: Array, idx: int) -> void:
	for i in buttons.size():
		buttons[i].button_pressed = (i == idx)
