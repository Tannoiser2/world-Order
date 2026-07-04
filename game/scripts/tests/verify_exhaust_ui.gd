extends SceneTree
## Sconto (esaurisci alleati per Impegnati/Migliora Relazioni):
##  - selezionare una Nazione per lo sconto la fa "girare" in anteprima (grigia), come se
##    fosse già esaurita, prima ancora di confermare;
##  - la barra ha un solo bottone "Conferma" (niente più "Salta" separato: 0 carte girate
##    equivale già a nessuno sconto).
## Growth Card once-per-round: si clicca DIRETTAMENTE la carta (bordo acceso quando
## usabile) invece del vecchio bottone "Usa" separato; si gira/ingrigisce quando usata.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_exhaust_ui.gd

func _first_button_labeled(node: Node, contains: String) -> Button:
	if node is Button and contains in String((node as Button).tooltip_text):
		return node
	for c in node.get_children():
		var f := _first_button_labeled(c, contains)
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

	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.active_seat = 0
	var p = b.gs.players[0]
	var ids := []
	for c in p.allied_countries:
		ids.append(String(c.get("id", "")))
	var cid: String = ids[0]

	# 1) Barra sconto: un solo bottone "Conferma", niente "Salta" separato.
	var cb_called := []
	b._pick_exhaust_discount("europe", "Test", func(chosen): cb_called.append(chosen))
	await process_frame
	var texts := []
	for c in b.choice_flow.get_children():
		if c is Button:
			texts.append(String((c as Button).text))
	var s1: bool = texts.size() == 1 and texts[0] == "Conferma"
	print("[%s] Barra sconto: un solo bottone '%s'" % ["OK" if s1 else "FAIL", ", ".join(texts)])
	if not s1: fails += 1

	# 2) Selezionare una Nazione per lo sconto la fa girare (grigia) in ANTEPRIMA.
	b._refresh()
	await process_frame
	var before: bool = bool(b._exhausted_seen.get(cid, false))
	b._on_exhaust_toggle(p.allied_countries[0])
	await create_timer(0.4).timeout
	var after: bool = bool(b._exhausted_seen.get(cid, false))
	print("[%s] Selezionata per lo sconto: tracciata come 'esaurita' in anteprima (prima=%s dopo=%s)" % [
		"OK" if (not before and after) else "FAIL", str(before), str(after)])
	if before or not after: fails += 1

	# Deseleziona: torna Pronta.
	b._on_exhaust_toggle(p.allied_countries[0])
	await create_timer(0.4).timeout
	var back: bool = bool(b._exhausted_seen.get(cid, false))
	print("[%s] Deselezionata: torna Pronta (=%s)" % ["OK" if not back else "FAIL", str(back)])
	if back: fails += 1

	# 3) Conferma con 0 selezioni = nessuno sconto (stesso comportamento di uno "skip").
	b._exhaust_confirm()
	await process_frame
	var s3: bool = cb_called.size() == 1 and (cb_called[0] as Array).is_empty()
	print("[%s] Conferma senza selezioni: nessuno sconto applicato" % ["OK" if s3 else "FAIL"])
	if not s3: fails += 1

	# 4) Growth Card once-per-round: click DIRETTO sulla carta (non serve più un bottone "Usa").
	var once_card := {"id": "gtest", "display_name": "Reduced Bureaucracy",
		"effect_ops": [{"op": "ongoing", "tag": "once_per_round:draw_then_trash"}]}
	p.growth_cards = [once_card]
	p.hand = []
	p.deck = [{"id": "d1"}, {"id": "d2"}]
	b._used_ongoing = {}
	b.playing_card = {}
	var col := VBoxContainer.new()
	get_root().add_child(col)
	b._build_growth_section(p, true, col)
	await process_frame
	var gbtn: Button = _first_button_labeled(col, "Reduced Bureaucracy")
	var s4: bool = gbtn != null and not gbtn.disabled
	print("[%s] Growth usabile: la carta stessa è un bottone cliccabile (non disabilitato)" % ["OK" if s4 else "FAIL"])
	if not s4: fails += 1
	if gbtn != null:
		gbtn.pressed.emit()
	await create_timer(0.4).timeout
	var s5: bool = b._ongoing_used(p.power, "once_per_round:draw_then_trash")
	print("[%s] Click sulla carta: l'abilità once-per-round risulta usata" % ["OK" if s5 else "FAIL"])
	if not s5: fails += 1
	# Ricostruita, ora deve mostrare la carta girata/grigia e NON più cliccabile.
	for c in col.get_children(): c.queue_free()
	var col2 := VBoxContainer.new()
	get_root().add_child(col2)
	b._build_growth_section(p, true, col2)
	await create_timer(0.4).timeout
	var gbtn2: Button = _first_button_labeled(col2, "Reduced Bureaucracy")
	var s6: bool = gbtn2 != null and gbtn2.disabled and gbtn2.modulate.r < 0.45
	print("[%s] Dopo l'uso: la carta è girata (grigia) e non più cliccabile" % ["OK" if s6 else "FAIL"])
	if not s6: fails += 1

	col.queue_free(); col2.queue_free()
	b.queue_free()
	await process_frame
	print("Verifica UI sconto/Growth click: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
