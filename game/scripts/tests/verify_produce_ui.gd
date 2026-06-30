extends SceneTree
## Produce UI: il riepilogo leggibile spiega cosa significano i numeri sulla track. Per ogni
## tipo selezionato mostra nome esteso, quantita' prodotta e (per le derivate) il costo in
## primarie — cosi' "+4 -4,-4" diventa "Beni di consumo +4 (costa 4 Energia, 4 Materie Prime)".
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_produce_ui.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	# 1) Primaria: nessun costo. Cibo +2.
	b._produce_sel = {"food": 2}
	var s1text: String = b._produce_summary_text()
	var s1: bool = "Cibo +2" in s1text and "costa" not in s1text
	print("[%s] primaria: '%s'" % ["OK" if s1 else "FAIL", s1text])
	if not s1: fails += 1

	# 2) Derivata Beni di consumo (costa Energia + Materie Prime), x3.
	b._produce_sel = {"consumer_goods": 3}
	var s2text: String = b._produce_summary_text()
	var s2: bool = "Beni di consumo +3" in s2text and "3 Energia" in s2text and "3 Materie Prime" in s2text
	print("[%s] derivata CG: '%s'" % ["OK" if s2 else "FAIL", s2text])
	if not s2: fails += 1

	# 3) Derivata Servizi (costa Cibo + Materie Prime), x2.
	b._produce_sel = {"services": 2}
	var s3text: String = b._produce_summary_text()
	var s3: bool = "Servizi +2" in s3text and "2 Cibo" in s3text and "2 Materie Prime" in s3text
	print("[%s] derivata Servizi: '%s'" % ["OK" if s3 else "FAIL", s3text])
	if not s3: fails += 1

	# 4) Mix di piu' tipi nel riepilogo, in ordine stabile.
	b._produce_sel = {"food": 1, "consumer_goods": 2}
	var s4text: String = b._produce_summary_text()
	var s4: bool = "Cibo +1" in s4text and "Beni di consumo +2" in s4text and s4text.begins_with("Stai producendo:")
	print("[%s] mix: '%s'" % ["OK" if s4 else "FAIL", s4text])
	if not s4: fails += 1

	# 5) Nessuna selezione -> riepilogo vuoto.
	b._produce_sel = {}
	var s5: bool = b._produce_summary_text() == ""
	print("[%s] nessuna selezione: riepilogo vuoto" % ["OK" if s5 else "FAIL"])
	if not s5: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Produce UI (riepilogo leggibile): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
