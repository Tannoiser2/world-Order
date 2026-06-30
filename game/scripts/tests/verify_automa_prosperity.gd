extends SceneTree
## Fix: i Bot ora aumentano la Prosperità nell'Aftermath pagando in money (traccia Prosperità
## della loro Player card), invece di restare a 0 (e accumulare money all'infinito).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_automa_prosperity.gd

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
	var usa = b.gs.player_by_power("usa")

	# 1) Aumento diretto: con money abbondante il bot massimizza la sua traccia Prosperità.
	usa.money = 200
	usa.prosperity_level = 0
	var vp0: int = usa.victory_points
	var res: Dictionary = b._automa_increase_prosperity(usa)
	# usa: costi 10+15+25+35+45 = 130 ; VP 2+3+4+5+8 = 22 ; 5 livelli.
	_chk(usa.prosperity_level == 5, "Prosperità massimizzata a 5 (=%d)" % usa.prosperity_level)
	_chk(usa.money == 70, "speso 130 money (200->%d)" % usa.money)
	_chk(usa.victory_points == vp0 + 22, "+22 VP dalla Prosperità (=%d)" % (usa.victory_points - vp0))
	_chk(int(res["levels"]) == 5 and int(res["vp"]) == 22, "ritorno {levels:5, vp:22}")

	# 2) Money insufficiente: si ferma al livello che può permettersi.
	var china = b.gs.player_by_power("china")
	china.prosperity_level = 0
	china.money = 30   # china: primo spazio costa 15, secondo 20 -> ne prende 1 (15)
	b._automa_increase_prosperity(china)
	_chk(china.prosperity_level == 1 and china.money == 15, "china con 30 money sale di 1 livello (liv=%d money=%d)" % [china.prosperity_level, china.money])

	# 3) Via driver Aftermath: il bot aumenta la Prosperità e poi passa al giocatore dopo.
	china.prosperity_level = 0
	china.money = 100
	b._ui_phase = "Aftermath"
	b.gs.phase = WO.Phase.AFTERMATH
	b._aftermath_idx = 1
	b._aftermath_choice_p = china
	b._aftermath_lines.clear()
	b.playing_card = {}
	b._automa_run()
	await process_frame
	_chk(china.prosperity_level > 0, "driver Aftermath: il bot ha aumentato la Prosperità (liv=%d)" % china.prosperity_level)
	_chk(b._aftermath_idx == 2, "driver Aftermath: passato al giocatore successivo (idx=%d)" % b._aftermath_idx)

	b.queue_free()
	await process_frame
	GameConfig.automa_powers = []
	print("Verifica Prosperità dei Bot: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _chk(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1
