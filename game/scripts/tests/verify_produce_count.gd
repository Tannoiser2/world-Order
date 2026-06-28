extends SceneTree
## Azione Produce: quando una carta dice "Produce N tipi" (count), si possono produrre al
## massimo N TIPI di risorsa (es. Growth Strategy = 3, R&D Champion = 2, Optimization
## Program = 1). Prima l'interfaccia ignorava il count e lasciava produrre TUTTI i tipi.
## Verifica anche, come riferimento, la regola del Trade: le Armate sono vendibili (valore 20)
## e la Diplomazia non e' commerciabile (regolamento pag. 13).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_produce_count.gd

func _init() -> void:
	var fails := 0
	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	var b: Variant = board_packed.instantiate()
	get_root().add_child(b)
	await process_frame
	b._begin_action_phase()
	var p = b._active()
	p.production = {"energy": 3, "raw_materials": 3, "food": 3, "consumer_goods": 3, "services": 3, "diplomacy": 3, "armies": 3}

	# 1) Limite a 2 tipi: il terzo tipo viene RIFIUTATO.
	b._open_produce_ui(2)
	b._produce_set("energy", 1)
	b._produce_set("food", 1)
	b._produce_set("raw_materials", 1)   # terzo tipo -> rifiutato
	var s1: bool = b._produce_sel.size() == 2 and b._produce_sel.has("energy") \
		and b._produce_sel.has("food") and not b._produce_sel.has("raw_materials")
	print("[%s] limite 2 tipi: terzo rifiutato (sel=%s)" % ["OK" if s1 else "FAIL", str(b._produce_sel)])
	if not s1: fails += 1

	# 2) Un tipo gia' scelto si puo' sempre REGOLARE (non conta come nuovo tipo).
	b._produce_set("energy", 3)
	var s2: bool = b._produce_sel.size() == 2 and int(b._produce_sel.get("energy", 0)) == 3
	print("[%s] regolare un tipo gia' scelto (energy=%d, tipi=%d)" % ["OK" if s2 else "FAIL",
		int(b._produce_sel.get("energy", 0)), b._produce_sel.size()])
	if not s2: fails += 1

	# 3) Anche le Armate contano come un TIPO: col limite gia' raggiunto vengono rifiutate.
	b._produce_armies_adjust(1)
	var s3: bool = not b._produce_sel.has("armies") and b._produce_sel.size() == 2
	print("[%s] Armate come tipo: rifiutate oltre il limite (armi in sel=%s)" % [
		"OK" if s3 else "FAIL", str(b._produce_sel.has("armies"))])
	if not s3: fails += 1

	# 4) Senza count (0 = illimitato): si possono scegliere piu' tipi.
	b._open_produce_ui(0)
	b._produce_set("energy", 1)
	b._produce_set("food", 1)
	b._produce_set("raw_materials", 1)
	b._produce_set("services", 1)
	var s4: bool = b._produce_sel.size() == 4
	print("[%s] illimitato: 4 tipi consentiti (tipi=%d)" % ["OK" if s4 else "FAIL", b._produce_sel.size()])
	if not s4: fails += 1

	# 5) Autorita': _apply_produce non supera il limite anche se la selezione e' forzata a 3.
	b._open_produce_ui(2)
	p.resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	b._produce_sel = {"energy": 3, "food": 3, "raw_materials": 3}   # forzati 3 tipi
	b._apply_produce()
	# Tenuti i primi 2 (energy, food); raw_materials NON prodotto.
	var s5: bool = int(p.resources.get("energy", 0)) == 3 and int(p.resources.get("food", 0)) == 3 \
		and int(p.resources.get("raw_materials", 0)) == 0
	print("[%s] _apply_produce taglia al limite (energy=%d food=%d raw=%d)" % ["OK" if s5 else "FAIL",
		int(p.resources.get("energy", 0)), int(p.resources.get("food", 0)), int(p.resources.get("raw_materials", 0))])
	if not s5: fails += 1

	# 6) Regola Trade (riferimento): Armate vendibili a 20; Diplomazia NON commerciabile.
	var s6: bool = int(Actions.EXPORT_GAIN.get("armies", 0)) == 20 and not Actions.EXPORT_GAIN.has("diplomacy") \
		and not Actions.IMPORT_COST.has("armies")
	print("[%s] Trade: Armate vendibili (20), Diplomazia non commerciabile, Armate non importabili" % ["OK" if s6 else "FAIL"])
	if not s6: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Produce (limite tipi) + regola Trade Armate: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
