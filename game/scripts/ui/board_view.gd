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
var player_panel: VBoxContainer
var hand_box: HBoxContainer
var popup_layer: Control

var all_countries: Array = []
var region_countries: Dictionary = {}   # rid -> { available:[c,c], deck:[...] }
# Stato del gioco di una carta:
var playing_card: Dictionary = {}
var play_queue: Array = []
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
	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)

	GamePhases.determine_turn_order(gs)
	round_turn_count = 0
	active_seat = gs.turn_order[0]

	resized.connect(_layout_overlays)
	_layout_overlays()
	_refresh()


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
	var cost := Actions.improve_relations_cost(int(country.get("value", 0)), [])
	if p.resources.get("diplomacy", 0) < cost:
		_status("Diplomazia insufficiente per Improve Relations con %s (serve %d)." % [country.get("display_name", ""), cost])
		return
	if Actions.execute_improve_relations(gs, p.power, country, []):
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
	_status("Giochi: %s" % card.get("display_name", "carta"))
	_advance_play()


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
			_status("Scegli una Regione per: %s" % name)
			_layout_overlays()
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
			Actions.execute_engage(gs, p.power, region, [], p.focus == WO.Focus.DIPLOMATIC, "temporary")
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
	awaiting = ""
	_status("Giocata annullata.")
	_layout_overlays()


func _board_countries() -> Array:
	# i Country non ancora alleati di questo giocatore (semplificazione: tutti)
	return all_countries


## Country alleate idonee per l'op data (invest = tutte; build_base = con base).
func _eligible_allied(op_name: String) -> Array:
	var p := _active()
	if op_name == "build_base":
		return p.allied_countries.filter(func(c): return c.get("has_base_symbol", false) and p.power in c.get("base_allowed_powers", []))
	return p.allied_countries


# --- Plancia, mano, stato ---

func _build_player_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 88
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.09, 0.12, 0.92)
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)
	player_panel = VBoxContainer.new()
	panel.add_child(player_panel)


func _refresh() -> void:
	for c in player_panel.get_children():
		c.queue_free()
	var p := _active()
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 14)
	player_panel.add_child(row1)
	var my_turn := (round_turn_count / gs.players.size()) + 1
	var who := Label.new()
	who.text = "Round %d  ·  %s  ·  turno %d/4" % [gs.round, p.power.to_upper(), mini(my_turn, 4)]
	who.add_theme_color_override("font_color", POWER_COLORS.get(p.power, Color.WHITE))
	who.add_theme_font_size_override("font_size", 18)
	row1.add_child(who)
	row1.add_child(_kv("Money", p.money))
	row1.add_child(_kv("VP", p.victory_points))
	for f in 3:
		var b := Button.new()
		b.text = FOCUS_NAME[f]
		b.toggle_mode = true
		b.button_pressed = (p.focus == f)
		b.pressed.connect(func(): p.focus = f; _refresh())
		row1.add_child(b)
	var endt := Button.new()
	endt.text = "Fine turno ▶"
	endt.disabled = game_over or not playing_card.is_empty()
	endt.pressed.connect(_end_turn)
	row1.add_child(endt)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	player_panel.add_child(row2)
	for rtype in RES:
		row2.add_child(_kv2("%s %d/%d" % [RES_LABEL[rtype], int(p.resources.get(rtype, 0)), int(p.production.get(rtype, 0))]))
	# Riga 3: Country alleate davanti al giocatore (cliccabili per Invest/Build).
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	player_panel.add_child(row3)
	row3.add_child(_kv2("Alleati (%d):" % p.allied_countries.size()))
	var elig: Array = _eligible_allied(String(awaiting_op.get("op", ""))) if awaiting == "allied_country" else []
	for cn in p.allied_countries:
		var ab := Button.new()
		ab.text = "%s (%d)" % [cn.get("display_name", "?"), int(cn.get("value", 0))]
		ab.add_theme_font_size_override("font_size", 11)
		ab.pressed.connect(_on_allied_pressed.bind(cn))
		if awaiting == "allied_country":
			if cn in elig:
				ab.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
			else:
				ab.disabled = true
		row3.add_child(ab)


func _kv(k: String, v: int) -> Label:
	var l := Label.new(); l.text = "%s %d" % [k, v]; l.add_theme_font_size_override("font_size", 15); return l


func _kv2(t: String) -> Label:
	var l := Label.new(); l.text = t; return l


func _end_turn() -> void:
	if not playing_card.is_empty() or game_over:
		return
	round_turn_count += 1
	if round_turn_count >= 4 * gs.players.size():
		_run_aftermath()
		return
	active_seat = gs.turn_order[round_turn_count % gs.players.size()]
	_status("Turno di %s." % _active().power.to_upper())
	_after_change()


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
	_render_hand()


func _build_hand_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -184
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	panel.add_theme_stylebox_override("panel", st)
	var scroll := ScrollContainer.new()
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 6)
	scroll.add_child(hand_box)
	panel.add_child(scroll)
	add_child(panel)
	status_label = Label.new()
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.offset_top = -206
	status_label.offset_bottom = -186
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)
	_render_hand()


func _render_hand() -> void:
	if hand_box == null:
		return
	for c in hand_box.get_children():
		c.queue_free()
	for card in _active().hand:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(112, 160)
		btn.flat = true
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
