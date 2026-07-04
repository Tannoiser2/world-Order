extends SceneTree
## Pannello Obiettivi: rimossa l'etichetta "Obiettivi" (le carte si riconoscono da sole) e le
## carte sono leggermente più piccole. Le condizioni/VP mostrati sono ricalcolati IN TEMPO REALE
## ad ogni _refresh (non calcolati una volta sola all'apertura del pannello).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_objectives_panel_ui.gd

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

	var p = b.gs.players[0]
	# South Asia: nessun cubetto INIZIALE di USA (starting_influence = china + local), cosi'
	# l'Influenza contata riflette solo quella piazzata davvero in questo test.
	p.objectives = [{
		"name": "Test Objective",
		"conditions": [
			{"t": "influence_region", "region": "south_asia", "min": [3, 3]},
			{"t": "money", "min": [10, 10]},
			{"t": "deck_size", "min": [99, 99]},
		],
		"reward": [2, 4, 7],
		"art": "",
	}]
	p.money = 0
	b.gs.regions["south_asia"]["track"].add(p.power, "temporary")
	b.gs.regions["south_asia"]["track"].add(p.power, "temporary")   # 2 Influenza: non basta (serve 3)
	b.drawer_open = true
	b.drawer_power = p.power
	b.active_seat = 0
	b._refresh()
	await process_frame

	# 1) Niente etichetta "Obiettivi" nel pannello (le carte si riconoscono da sole).
	var hdr: Label = _find_label_containing(b.drawer_content, "Obiettivi")
	var s1: bool = hdr == null
	print("[%s] nessuna etichetta 'Obiettivi' nel pannello" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) Le carte Obiettivo sono leggermente più piccole (larghezza <= 270, prima fino a 320).
	var lab0: Label = _find_label_containing(b.drawer_content, "0/3 condizioni")
	var s2: bool = lab0 != null and lab0.custom_minimum_size.x <= 270.0
	print("[%s] carte Obiettivo rimpicciolite (larghezza=%s, atteso <= 270)" % [
		"OK" if s2 else "FAIL", str(lab0.custom_minimum_size.x if lab0 != null else "?")])
	if not s2: fails += 1

	# 3) 0/3 condizioni soddisfatte finora (money=0, Influenza=2<3, mazzo troppo piccolo).
	var s3: bool = lab0 != null
	print("[%s] 0/3 condizioni mostrate all'inizio" % ["OK" if s3 else "FAIL"])
	if not s3: fails += 1

	# 4) Cambio di stato REALE (money 0->10, 3a Influenza in Europa): il pannello ricalcola le
	#    condizioni IN TEMPO REALE al prossimo _refresh (non e' una spunta statica/cache).
	p.money = 10
	b.gs.regions["south_asia"]["track"].add(p.power, "temporary")   # ora 3 Influenza
	b._refresh()
	await process_frame
	var lab2: Label = _find_label_containing(b.drawer_content, "condizioni")
	var s4: bool = lab2 != null and "2/3" in lab2.text and "4 VP" in lab2.text
	print("[%s] ricalcolo in tempo reale dopo il cambio di stato (%s, atteso '2/3 condizioni -> 4 VP')" % [
		"OK" if s4 else "FAIL", lab2.text if lab2 != null else "?"])
	if not s4: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica pannello Obiettivi (UI + tempo reale): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
