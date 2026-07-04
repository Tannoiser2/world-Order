extends SceneTree
## Segnalazione: invece di un elenco di bottoni testuali nella barra scelte, l'Aumento
## Produzione (Choose Focus) deve EVIDENZIARE direttamente sulla plancia la/le caselle dove la
## Produzione puo' aumentare (come gia' avviene per Commercio/Produce): Diplomatico -> solo la
## casella Diplomazia, Militare -> solo la casella Armate, Domestico -> QUALSIASI delle 7
## (scelta libera). Toccando la casella evidenziata la Produzione aumenta per davvero e si
## passa alla Produzione del Focus - verificato passando dal vero rendering
## (_build_plancia_view -> _add_increase_overlays), non solo chiamando le funzioni a mano.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_increase_board_overlay.gd

func _count_buttons(node: Node) -> int:
	var n := 0
	if node is Button:
		n += 1
	for c in node.get_children():
		n += _count_buttons(c)
	return n


func _find_button_tooltip(node: Node, needle: String) -> Button:
	if node is Button and needle in String((node as Button).tooltip_text):
		return node
	for c in node.get_children():
		var f := _find_button_tooltip(c, needle)
		if f != null:
			return f
	return null


func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	b._ui_phase = "Preparazione"; b.gs.phase = WO.Phase.PREPARATION
	b.active_seat = 0
	var p = b.gs.players[0]
	p.money = 100
	p.production = {"energy": 2, "raw_materials": 2, "food": 2, "consumer_goods": 2, "services": 2, "diplomacy": 2, "armies": 2}
	p.focus = WO.Focus.DOMESTIC
	b._prep_awaiting_increase = true
	b._prep_increases_done = 0
	b._prep_increased_types = []

	# 1) Niente più bottoni testuali "+1 X" nella barra scelte in alto (solo istruzione + Salta).
	b._show_increase_bar()
	await process_frame
	var bar_buttons := _count_buttons(b.choice_flow)
	var s1: bool = bar_buttons == 1   # solo "Salta"
	print("[%s] barra scelte: niente più bottoni per tipo, solo 'Salta' (bottoni=%d, atteso 1)" % [
		"OK" if s1 else "FAIL", bar_buttons])
	if not s1: fails += 1

	# 2) Focus Domestico: la plancia REALE (_build_plancia_view -> _add_increase_overlays) mostra
	#    7 caselle evidenziate (una per ogni Produzione, scelta libera), col tooltip giusto.
	var view: Control = b._build_plancia_view(p, true)
	get_root().add_child(view)
	await process_frame
	var nbtn_dom := _count_buttons(view)
	var s2: bool = nbtn_dom >= 7
	print("[%s] Focus Domestico: la plancia evidenzia almeno le 7 caselle Produzione (bottoni=%d, attesi >= 7)" % [
		"OK" if s2 else "FAIL", nbtn_dom])
	if not s2: fails += 1

	# 3) Toccando DAVVERO la casella evidenziata "Energia" (trovata dal tooltip, come premerebbe
	#    l'utente - non chiamo _cmd_increase_production a mano): la Produzione aumenta per davvero.
	var btn := _find_button_tooltip(view, "Energia")
	var money_pre: int = int(p.money)
	var lvl_pre := int(p.production.get("energy", 0))
	var s3ok: bool = btn != null
	if btn: btn.pressed.emit()
	await process_frame
	var s3: bool = s3ok and int(p.production.get("energy", 0)) == lvl_pre + 1 and p.money < money_pre
	print("[%s] toccando la casella evidenziata Energia si aumenta per davvero (trovata=%s, produzione=%d money %d->%d)" % [
		"OK" if s3 else "FAIL", str(s3ok), int(p.production.get("energy", 0)), money_pre, p.money])
	if not s3: fails += 1
	view.queue_free()

	# 4) Focus Militare: solo 1 casella evidenziata (Armate), niente per le altre risorse.
	#    (Il passo 3 ha gia' esaurito l'aumento Domestico e aperto la Produce del Focus: la si
	#    richiude esplicitamente, altrimenti la plancia mostrerebbe ANCORA quella, non l'Aumento.)
	b._produce_mode = false
	b._produce_allowed = []
	b._produce_sel = {}
	b._prep_awaiting_increase = true
	b._prep_increases_done = 0
	b._prep_increased_types = []
	p.focus = WO.Focus.MILITARY
	var view2: Control = b._build_plancia_view(p, true)
	get_root().add_child(view2)
	await process_frame
	var has_armies: bool = _find_button_tooltip(view2, "Armate") != null
	var has_energy: bool = _find_button_tooltip(view2, "Energia") != null
	var s4: bool = has_armies and not has_energy
	print("[%s] Focus Militare: evidenziata SOLO la casella Armate (armate=%s, energia=%s)" % [
		"OK" if s4 else "FAIL", str(has_armies), str(has_energy)])
	if not s4: fails += 1
	view2.queue_free()

	b.queue_free()
	await process_frame
	print("Verifica Aumento Produzione (evidenziazione sulla plancia): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
