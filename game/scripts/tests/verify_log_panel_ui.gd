extends SceneTree
## Segnalazione: il Registro era "piatto" (un elenco di Label tutte uguali). Corretto:
##  1) Colonna VERA (map_viewport si restringe di log_w), non più una finestra che si
##     sovrappone alla mappa (z_index sopra, senza riservare spazio).
##  2) Le righe di un'azione di una potenza sono colorate col colore della Nazione e in
##     NERETTO (font emboldato); le righe generiche restano nel colore/peso di default.
##  3) Ordine invertito: le più recenti IN ALTO (prima erano in fondo, come una chat).
##  4) I cambi di turno/round sono un'intestazione a sé (barra colorata), non testo con simboli
##     "══" (poco leggibili) mescolato alle righe normali.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_log_panel_ui.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	# 1) Colonna VERA: con log NON collassato, la mappa (map_viewport) deve essere più STRETTA
	#    della larghezza intera (board_w..w) di circa log_w - non deve più coprirla un overlay.
	b._log_collapsed = false
	b.size = Vector2(1600, 900)
	b._layout_ui()
	await process_frame
	var full_w: float = b.size.x - b._board_w()
	var s1: bool = b.map_viewport.size.x < full_w - 50.0 and b.log_panel.size.x > 100.0 \
		and b.map_viewport.position.x + b.map_viewport.size.x <= b.log_panel.position.x + 1.0
	print("[%s] Registro: colonna VERA, la mappa si restringe e non ci finisce sotto (mappa=%.0f, piena=%.0f, log=%.0f)" % [
		"OK" if s1 else "FAIL", b.map_viewport.size.x, full_w, b.log_panel.size.x])
	if not s1: fails += 1

	# 2) Righe colorate + in NERETTO per potenza; riga generica resta nel colore di default.
	b._log_lines = []
	b._event("USA: Engage in Europa (-2 Dip, +1 VP).")
	b._event("CHINA: Invest in Paese Test (+2 VP).")
	b._log("Scoring: nessuna Regione assegnata.")
	b._render_log()
	await process_frame
	var labels := []
	_collect_labels(b.log_content, labels)
	var usa_lab: Label = null
	var china_lab: Label = null
	var generic_lab: Label = null
	for l in labels:
		if String((l as Label).text).begins_with("USA:"): usa_lab = l
		elif String((l as Label).text).begins_with("CHINA:"): china_lab = l
		elif "Scoring" in String((l as Label).text): generic_lab = l
	var s2: bool = usa_lab != null and china_lab != null and generic_lab != null \
		and usa_lab.get_theme_color("font_color") == b.POWER_COLORS["usa"] \
		and china_lab.get_theme_color("font_color") == b.POWER_COLORS["china"] \
		and usa_lab.has_theme_font_override("font") \
		and not generic_lab.has_theme_font_override("font")
	print("[%s] righe azione colorate per Nazione + NERETTO, riga generica senza colore/neretto" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# 3) Ordine INVERTITO: la riga più recente (Scoring, aggiunta per ultima) è la PRIMA
	#    visibile, non l'ultima come in una chat classica.
	var first_child: Variant = null
	for c in b.log_content.get_children():
		first_child = c
		break
	var s3: bool = first_child is Label and "Scoring" in String((first_child as Label).text)
	print("[%s] ordine invertito: la riga più recente è in cima (prima riga=%s)" % [
		"OK" if s3 else "FAIL", String((first_child as Label).text) if first_child is Label else "?"])
	if not s3: fails += 1

	# 4) Cambio di turno: intestazione a sé (non una Label con simboli "══" mescolata alle righe).
	b._log_lines = []
	b._log_turn(" Round 3 · Azione ")
	b._event("USA: Trade completato.")
	b._render_log()
	await process_frame
	var has_turn_text := false
	for l2 in _all_labels(b.log_content):
		if "══" in String((l2 as Label).text):
			has_turn_text = true
	var turn_header_found := false
	for c2 in b.log_content.get_children():
		if c2 is PanelContainer:
			turn_header_found = true
	var s4: bool = turn_header_found and not has_turn_text
	print("[%s] cambio turno: intestazione a sé, niente testo con simboli '══' nelle righe" % ["OK" if s4 else "FAIL"])
	if not s4: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Registro (colonna vera + colori + neretto + ordine + turni): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)


func _collect_labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for c in node.get_children():
		_collect_labels(c, out)


func _all_labels(node: Node) -> Array:
	var out := []
	_collect_labels(node, out)
	return out
