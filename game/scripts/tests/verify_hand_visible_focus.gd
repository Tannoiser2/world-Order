extends SceneTree
## Segnalazione: "Quando scelgo il Focus devo vedere che carte ho in mano, è importante per la
## decisione di quale Focus scegliere." Prima _build_hand_section nascondeva la mano per TUTTA
## la Preparazione (auto_hide includeva _ui_phase == "Preparazione"), quindi la si perdeva anche
## nel momento in cui si sceglie il Focus. Corretto: la mano resta visibile (collassabile come
## sempre) durante Focus/Ready/Aumento; resta nascosta SOLO nella Produzione del Focus vera e
## propria (_produce_mode, che scatta comunque dopo aver scelto il Focus).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_hand_visible_focus.gd

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
	p.hand = [{"display_name": "Carta 1"}, {"display_name": "Carta 2"}, {"display_name": "Carta 3"}]
	b.active_seat = 0

	# 1) Scelta del Focus (appena iniziata la Preparazione, nessun sotto-passo ancora attivo):
	#    la mano deve essere VISIBILE (non la barra disabilitata "Mano nascosta...").
	b._ui_phase = "Preparazione"; b.gs.phase = WO.Phase.PREPARATION
	b._prep_idx = 0
	b.gs.turn_order.assign([0, 1])
	b._prep_ready_remaining = 0
	b._prep_awaiting_increase = false
	b._produce_mode = false
	b.awaiting = ""
	b._trade_mode = false
	b.hand_collapsed = false
	b._refresh()
	await process_frame
	var s1: bool = b.hand_box != null and is_instance_valid(b.hand_box)
	print("[%s] mano VISIBILE durante la scelta del Focus (hand_box presente=%s)" % ["OK" if s1 else "FAIL", str(s1)])
	if not s1: fails += 1

	# 2) Durante la Produzione del Focus vera e propria (_produce_mode true), la mano resta
	#    nascosta come prima (niente regressione: qui davvero serve tutta l'attenzione sulla
	#    plancia/Produce, non e' il momento di guardare la mano).
	b._produce_mode = true
	b._refresh()
	await process_frame
	var s2: bool = b.hand_box == null
	print("[%s] mano ANCORA nascosta durante la Produzione del Focus (_produce_mode)" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica mano visibile durante la scelta del Focus: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
