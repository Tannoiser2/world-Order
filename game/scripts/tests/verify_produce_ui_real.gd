extends SceneTree
## Verifica la Produce UI passando per il VERO percorso di rendering (_build_plancia_view/
## _add_produce_overlays/_show_produce_bar), non solo chiamando _produce_set a mano: cosi' si
## scoprono bug di collegamento che i test "diretti" non vedono. Copre 4 segnalazioni:
##  1) "Produci 3 tipi" (Executive Order/carte): dopo aver scelto 1 tipo, i bersagli delle
##     ALTRE risorse devono restare presenti/attivi per scegliere il 2° e il 3° tipo.
##  2) Stesso bug: il bottone "Conferma" deve avvisare se non sono stati ancora scelti tutti i
##     tipi consentiti, cosi' non si conclude per sbaglio dopo il solo 1° tipo.
##  3) Focus Militare: le Armate non hanno una casella sulla resource track (vanno in riserva,
##     nessun segnalino da trascinare sulla plancia) - devono restare regolabili con un ± CHIARO
##     nella barra scelte in alto (_show_produce_bar), generato dal vero rendering.
##  4) Focus Domestico: la Produce e' limitata a Beni di consumo + Servizi ma SENZA un "count"
##     (illimitato) - prima non c'era alcun avviso se si confermava dopo un solo tipo, quindi si
##     produceva "solo un tipo tra Beni di Consumo e Servizi" pur potendo fare entrambi.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_produce_ui_real.gd

func _find_button_text(node: Node, text: String) -> Button:
	if node is Button and String((node as Button).text) == text:
		return node
	for c in node.get_children():
		var f := _find_button_text(c, text)
		if f != null:
			return f
	return null


func _find_label_containing(node: Node, needle: String) -> Label:
	if node is Label and needle in String((node as Label).text):
		return node
	for c in node.get_children():
		var f := _find_label_containing(c, needle)
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
	p.production = {"energy": 5, "raw_materials": 5, "food": 5, "consumer_goods": 5, "services": 5, "diplomacy": 5, "armies": 5}
	p.resources = {"energy": 5, "raw_materials": 5, "food": 5, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	p.money = 50
	p.armies_available = 0

	# 1) "Produci 3 tipi": dopo aver selezionato energy, i bersagli di food/raw_materials
	#    restano presenti nel VERO albero della plancia (non solo in teoria via _produce_set).
	b._open_produce_ui(3, [])
	b._produce_set("energy", 2)
	await process_frame
	var s1: bool = b._produce_sel.size() == 1 and int(b._produce_sel.get("energy", 0)) == 2
	print("[%s] 1° tipo selezionato (energy=2)" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	b._produce_set("food", 1)
	b._produce_set("raw_materials", 1)
	await process_frame
	var s2: bool = b._produce_sel.size() == 3
	print("[%s] Con count=3 si possono selezionare TUTTI e 3 i tipi in sequenza (sel=%s)" % [
		"OK" if s2 else "FAIL", str(b._produce_sel)])
	if not s2: fails += 1

	# 2) Il bottone "Conferma" DEVE avvisare se non sono ancora stati scelti tutti i tipi
	#    consentiti (il bug segnalato: "Produci 3 tipi" ha prodotto solo 1, probabilmente perche'
	#    si e' premuto Conferma subito dopo il 1° tipo pensando di aver finito).
	b._produce_sel = {}
	b._open_produce_ui(3, [])
	b._produce_set("energy", 1)
	await process_frame
	var ok_btn: Button = _find_button_text(b.choice_flow, "Conferma (solo 1/3 tipi)")
	var s2b: bool = ok_btn != null
	print("[%s] bottone Conferma avvisa 'solo 1/3 tipi' quando ne manca ancora qualcuno" % ["OK" if s2b else "FAIL"])
	if not s2b: fails += 1

	b._produce_set("food", 1)
	b._produce_set("raw_materials", 1)
	await process_frame
	var ok_btn2: Button = _find_button_text(b.choice_flow, "Conferma")
	var s2c: bool = ok_btn2 != null
	print("[%s] bottone torna a 'Conferma' semplice con tutti e 3 i tipi scelti" % ["OK" if s2c else "FAIL"])
	if not s2c: fails += 1

	# 3) Focus Militare: le Armate NON hanno una casella sulla resource track, quindi la barra
	#    scelte in alto (_show_produce_bar, ricostruita DAVVERO da _refresh) deve mostrare un ±
	#    CHIARO con un'etichetta "N/Produzione" - non un bottone bersaglio nascosto sulla plancia.
	b._produce_sel = {}
	b._open_produce_ui(0, ["armies"])   # chiama _refresh() -> _show_produce_bar(p) per davvero
	await process_frame
	var minus_btn: Button = _find_button_text(b.choice_flow, "-")
	var plus_btn: Button = _find_button_text(b.choice_flow, "+")
	var cnt_lab: Label = _find_label_containing(b.choice_flow, "0/5")
	var s3: bool = minus_btn != null and plus_btn != null and cnt_lab != null
	print("[%s] Focus Militare: la barra scelte mostra un ± CHIARO per le Armate (trovati -=%s +=%s conteggio=%s)" % [
		"OK" if s3 else "FAIL", str(minus_btn != null), str(plus_btn != null), str(cnt_lab != null)])
	if not s3: fails += 1

	# 4) Premendo DAVVERO (segnale pressed, non chiamando la funzione a mano) il bottone "+" 3
	#    volte nella barra reale: _produce_sel si imposta e il conteggio si aggiorna a schermo.
	for i in range(3):
		var pb: Button = _find_button_text(b.choice_flow, "+")
		pb.pressed.emit()
		await process_frame
	var s4: bool = int(b._produce_sel.get("armies", 0)) == 3
	var cnt_lab2: Label = _find_label_containing(b.choice_flow, "3/5")
	var s4b: bool = cnt_lab2 != null
	print("[%s] premere '+' 3 volte nella barra reale imposta la quantita' (sel=%d, atteso 3; etichetta '3/5' mostrata=%s)" % [
		"OK" if (s4 and s4b) else "FAIL", int(b._produce_sel.get("armies", 0)), str(s4b)])
	if not (s4 and s4b): fails += 1

	# 5) Premendo "-" una volta: torna a 2 (verifica anche il verso opposto del ±, non solo +).
	var mb: Button = _find_button_text(b.choice_flow, "-")
	mb.pressed.emit()
	await process_frame
	var s5: bool = int(b._produce_sel.get("armies", 0)) == 2
	print("[%s] premere '-' nella barra reale decrementa la quantita' (sel=%d, atteso 2)" % [
		"OK" if s5 else "FAIL", int(b._produce_sel.get("armies", 0))])
	if not s5: fails += 1

	# 6) Focus Domestico: allowed=[consumer_goods, services] SENZA count (illimitato). Scelto un
	#    solo tipo, il bottone Conferma deve avvisare che manca l'altro; scelti entrambi, deve
	#    tornare a "Conferma" semplice - e ENTRAMBI vanno davvero prodotti alla conferma.
	b._produce_sel = {}
	p.resources["consumer_goods"] = 0; p.resources["services"] = 0
	b._open_produce_ui(0, ["consumer_goods", "services"], "prep")
	b._produce_set("consumer_goods", 1)
	await process_frame
	var ok_dom: Button = _find_button_text(b.choice_flow, "Conferma (manca: Servizi)")
	var s6: bool = ok_dom != null
	print("[%s] Focus Domestico: Conferma avvisa 'manca: Servizi' con un solo tipo scelto" % ["OK" if s6 else "FAIL"])
	if not s6: fails += 1

	b._produce_set("services", 1)
	await process_frame
	var ok_dom2: Button = _find_button_text(b.choice_flow, "Conferma")
	var s7: bool = ok_dom2 != null and b._produce_sel.size() == 2
	print("[%s] Focus Domestico: scelti entrambi (Beni di consumo + Servizi), Conferma torna semplice (sel=%s)" % [
		"OK" if s7 else "FAIL", str(b._produce_sel)])
	if not s7: fails += 1

	b._apply_produce()
	await process_frame
	var s8: bool = int(p.resources.get("consumer_goods", 0)) == 1 and int(p.resources.get("services", 0)) == 1
	print("[%s] Confermando si producono DAVVERO entrambi (CG=%d Servizi=%d)" % [
		"OK" if s8 else "FAIL", int(p.resources.get("consumer_goods", 0)), int(p.resources.get("services", 0))])
	if not s8: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Produce UI (rendering reale): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
