extends SceneTree
## Obiettivi Superpotenze — integrazione: assegnazione al setup (2 per potenza, scartando
## quelli che citano una potenza assente) e punteggio nei round di Scoring (3 e 6).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_objectives_game.gd

var _fails := 0

func _init() -> void:
	# --- A) Assegnazione al setup (engine puro) ---
	var gs: GameState = GameSetup.new_game(["usa", "eu", "russia", "china"])
	var assign_ok := true
	for p in gs.players:
		if p.objectives.size() != GameSetup.OBJECTIVES_PER_POWER:
			assign_ok = false
		for obj in p.objectives:
			if String(obj.get("power", "")) != p.power:
				assign_ok = false
	_chk(assign_ok, "setup: ogni potenza riceve %d Obiettivi della propria potenza" % GameSetup.OBJECTIVES_PER_POWER)

	# discard_if_no: l'Obiettivo si tiene solo se la potenza citata è in gioco.
	_chk(not GameSetup._objective_applies({"discard_if_no": "russia"}, {"eu": true, "china": true}), "discard: 'russia' assente -> scartato")
	_chk(GameSetup._objective_applies({"discard_if_no": "russia"}, {"russia": true}), "discard: 'russia' presente -> tenuto")
	_chk(GameSetup._objective_applies({"discard_if_no": "russia_or_china"}, {"china": true}), "discard: 'russia_or_china' con china -> tenuto")
	_chk(GameSetup._objective_applies({}, {"eu": true}), "discard: nessuna condizione -> sempre tenuto")

	# --- B) Punteggio nei round di Scoring (via board) ---
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	var usa = b.gs.player_by_power("usa")
	# Obiettivo con 3 condizioni sempre vere (soglia 0) -> 3/3 -> 7 VP.
	usa.objectives = [{
		"id": "obj_test", "power": "usa", "name": "Test", "reward": [2, 4, 7],
		"conditions": [
			{"t": "money", "min": [0, 0]},
			{"t": "growth_cards", "min": [0, 0]},
			{"t": "resource", "res": "food", "min": [0, 0]},
		],
	}]
	b.gs.round = 3
	b.gs.phase = WO.Phase.AFTERMATH
	b._aftermath_lines.clear()
	var vp0: int = usa.victory_points
	b._aftermath_resolve()
	await process_frame
	var has_line := false
	for ln in b._aftermath_lines:
		if String(ln).begins_with("Obiettivi:"):
			has_line = true
	_chk(has_line, "scoring round 3: riga 'Obiettivi:' nel riepilogo")
	_chk(usa.victory_points >= vp0 + 7, "scoring round 3: +VP dall'Obiettivo (>= +7); VP %d -> %d" % [vp0, usa.victory_points])

	# Round NON di scoring: nessun punteggio Obiettivi.
	b.gs.round = 2
	b._aftermath_lines.clear()
	var vp1: int = usa.victory_points
	b._aftermath_resolve()
	await process_frame
	var no_obj := true
	for ln in b._aftermath_lines:
		if String(ln).begins_with("Obiettivi:"):
			no_obj = false
	_chk(no_obj and usa.victory_points == vp1, "round 2 (non Scoring): nessun punteggio Obiettivi")

	b.queue_free()
	await process_frame
	print("Verifica Obiettivi (integrazione setup + scoring): %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _chk(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1
