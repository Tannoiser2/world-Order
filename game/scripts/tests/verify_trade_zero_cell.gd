extends SceneTree
## Segnalazione: nel Commercio, con una vendita PARZIALE già piazzata su una risorsa, la
## casella che corrisponde alla quantità di PARTENZA (nessun guadagno/costo netto) mostrava
## "-0" in rosso come se fosse un costo — matematicamente non era un errore di segno (le
## caselle a sinistra vendono/guadagnano sempre di più, quelle a destra comprano/costano
## sempre di più), ma quella specifica casella era fuorviante: sembrava un pagamento quando
## invece è solo il ripristino della quantità originale. Ora mostra un "0" neutro (grigio).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_trade_zero_cell.gd

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
	p.money = 50
	p.resources["energy"] = 8
	p.allied_countries = [{"id": "tz", "region": "africa", "value": 1,
		"exports": ["energy", "energy", "energy"], "imports": ["energy"]}]
	b.trade_deals = {"cards": [{"power": p.power, "exports": 2, "imports": 2, "import_from": {}}]}
	b._open_trade_ui()
	b._trade_active_res = "energy"
	b._trade_set_target("energy", 5)   # 8 -> 5: vendi 3 (parziale, eff=5) - deseleziona a fine set_target
	await process_frame

	var s1: bool = int(b._trade_sel["export"].get("energy", 0)) == 3
	print("[%s] setup: vendita parziale di 3 Energia piazzata (8->5)" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# Ri-tocco il token Energia (come nel gioco reale) per rivedere le caselle disponibili.
	b._trade_active_res = "energy"

	var view: Control = b._build_plancia_view(p, true)
	get_root().add_child(view)
	await process_frame
	var zero_btn: Button = _find_button_text(view, "0")
	var s2: bool = zero_btn != null and String(zero_btn.text) == "0"
	print("[%s] la casella della quantità di partenza (8) mostra '0' neutro, non '-0'" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1
	var minus_zero := _find_button_text(view, "-0")
	var s3: bool = minus_zero == null
	print("[%s] nessuna casella mostra ancora '-0'" % ["OK" if s3 else "FAIL"])
	if not s3: fails += 1
	view.queue_free()

	# Toccare DAVVERO quella casella (chiamando la stessa funzione collegata al bottone reale)
	# ripristina la quantità di partenza: nessuna vendita/acquisto netto per quella risorsa.
	b._trade_set_target("energy", 8)
	await process_frame
	var s4: bool = not (b._trade_sel["export"] as Dictionary).has("energy") \
		and not (b._trade_sel["import"] as Dictionary).has("energy")
	print("[%s] toccando '0' si ripristina la quantità di partenza (nessuna vendita/acquisto)" % ["OK" if s4 else "FAIL"])
	if not s4: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica casella '0' neutra nel Commercio: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)


func _find_button_text(node: Node, needle: String) -> Button:
	if node is Button and String((node as Button).text) == needle:
		return node
	for c in node.get_children():
		var f := _find_button_text(c, needle)
		if f != null:
			return f
	return null
