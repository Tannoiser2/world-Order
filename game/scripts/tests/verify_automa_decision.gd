extends SceneTree
## Fedeltà: il Focus dei Bot ora viene dalle Automa Decision card (pesca 1 carta, legge la riga
## della propria potenza), non più a caso. Income invariato: round * 10/5/3 per Domestic/Dipl/Mil.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_automa_decision.gd

var _fails := 0

func _init() -> void:
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = ["usa", "china"]
	GameConfig.automa_difficulty = "normal"
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	# 1) Il mazzo Decision è costruito al setup (12 carte).
	_chk(b._automa_decision_deck.size() == 12, "mazzo Decision di 12 carte (=%d)" % b._automa_decision_deck.size())

	# 2) Mappatura deterministica del Focus dalla carta pescata.
	b._automa_decision_deck = [{"usa": "military", "eu": "diplomatic", "russia": "domestic", "china": "diplomatic"}]
	var fu: int = b._draw_automa_focus("usa")
	_chk(fu == WO.Focus.MILITARY, "usa -> Militare dalla carta")
	# il mazzo era da 1 carta: ora vuoto, la prossima pesca rimescola a 12.
	var fc: int = b._draw_automa_focus("china")
	_chk(b._automa_decision_deck.size() == 11, "rimescolato a mazzo vuoto (rimaste %d dopo 1 pesca)" % b._automa_decision_deck.size())
	_chk(fc == WO.Focus.DOMESTIC or fc == WO.Focus.DIPLOMATIC or fc == WO.Focus.MILITARY, "china -> Focus valido")

	# 3) _automa_prep usa la Decision card (non più random) e incassa l'income corretto.
	b._automa_decision_deck = [{"usa": "domestic", "eu": "domestic", "russia": "domestic", "china": "domestic"}]
	var ci := -1
	for i in b.gs.players.size():
		if b.gs.players[i].power == "china": ci = i
	b._ui_phase = "Preparazione"; b.gs.phase = WO.Phase.PREPARATION
	b.gs.round = 4
	b.gs.turn_order.assign([ci, 1 - ci]); b._prep_idx = 0; b.active_seat = ci
	var m0: int = b.gs.players[ci].money
	b._automa_prep()
	# china legge "domestic" -> Focus Nazionale; income = round 4 * 10 = 40.
	_chk(b.gs.players[ci].focus == WO.Focus.DOMESTIC, "prep: china Focus Nazionale dalla carta")
	_chk(b.gs.players[ci].money == m0 + 40, "prep: income Domestic round 4 = +40 (=%d)" % (b.gs.players[ci].money - m0))

	b.queue_free()
	await process_frame
	GameConfig.automa_powers = []
	print("Verifica Focus dei Bot da Decision card: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _chk(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1
