extends SceneTree
## Verifica headless che la scena del tabellone si istanzi senza errori di script.
## Uso: godot --headless --path game --script res://scripts/tests/verify_ui.gd

func _init() -> void:
	var packed: PackedScene = load("res://scenes/board.tscn")
	if packed == null:
		print("[FAIL] board.tscn non caricata"); quit(1); return
	var inst := packed.instantiate()
	get_root().add_child(inst)
	# lascia girare _ready
	await process_frame
	await process_frame
	var regions := inst.get_node("../").get_child_count() if false else 0
	var overlay_children := 0
	for c in inst.get_children():
		if c is Control and c.name == "Control":
			pass
	# verifica che gli overlay delle Regioni siano stati creati
	var ov: Control = inst.overlay
	overlay_children = ov.get_child_count() if ov else 0
	print("[OK] board.tscn istanziata; overlay Regioni: %d" % overlay_children)
	quit(0 if overlay_children == 7 else 2)
