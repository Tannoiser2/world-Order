extends SceneTree
## Segnalazione: "al conteggio dei PV al round 3, NON si sommano i PV degli Obiettivi ma si usa
## solo quello che ne dà di più, poi si elimina la carta e rimane l'altra per il round 6."
## Verificato leggendo il codice: _aftermath_resolve già SOMMAVA i VP di TUTTI gli Obiettivi
## assegnati (2 a testa) e non ne scartava nessuno - ma il riepilogo mostrava un SOLO numero
## già sommato (via _vp_summary), dando l'impressione che ne contasse solo uno. Corretto il
## riepilogo per mostrare il contributo di OGNI Obiettivo; questo test conferma anche che la
## somma/mantenimento di ENTRAMBI gli Obiettivi era (ed è) corretto nel motore.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_objectives_round3_sum.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	var usa = b.gs.player_by_power("usa")
	# 2 Obiettivi assegnati (come da regolamento), ENTRAMBI soddisfatti (soglia 0 sempre vera),
	# con ricompense diverse: A da' 2 VP (1 condizione), B da' 7 VP (3 condizioni).
	usa.objectives = [
		{"id": "obj_a", "power": "usa", "name": "Obiettivo A", "reward": [2, 4, 7],
			"conditions": [
				{"t": "money", "min": [0, 0]},
				{"t": "growth_cards", "min": [999, 999]},   # mai soddisfatta -> solo 1/3
				{"t": "deck_size", "min": [999, 999]},
			]},
		{"id": "obj_b", "power": "usa", "name": "Obiettivo B", "reward": [1, 3, 9],
			"conditions": [
				{"t": "money", "min": [0, 0]},
				{"t": "growth_cards", "min": [0, 0]},
				{"t": "deck_size", "min": [0, 0]},
			]},
	]
	b.gs.round = 3
	b.gs.phase = WO.Phase.AFTERMATH

	# 1) Round 3: si sommano ENTRAMBI (2 da A + 9 da B = 11), non solo il migliore (9). Chiamo
	#    direttamente Objectives.objective_score (non contaminato da Regioni/token/THREAT, che
	#    _aftermath_resolve applica anch'essi e altererebbero il delta VP totale del giocatore).
	var va: int = Objectives.objective_score(b.gs, "usa", usa.objectives[0], 0)
	var vb: int = Objectives.objective_score(b.gs, "usa", usa.objectives[1], 0)
	var s1: bool = va == 2 and vb == 9
	print("[%s] round 3: ENTRAMBI gli Obiettivi danno VP (A=%d atteso 2, B=%d atteso 9) - si sommano, non si tiene solo il migliore" % [
		"OK" if s1 else "FAIL", va, vb])
	if not s1: fails += 1

	b._aftermath_lines.clear()
	b._aftermath_resolve()
	await process_frame

	# 2) Nessun Obiettivo viene scartato: restano ENTRAMBI assegnati dopo il round 3.
	var s2: bool = usa.objectives.size() == 2
	print("[%s] nessun Obiettivo scartato dopo il round 3 (rimasti=%d, attesi 2)" % [
		"OK" if s2 else "FAIL", usa.objectives.size()])
	if not s2: fails += 1

	# 3) Il riepilogo mostra il contributo di OGNI Obiettivo (non un solo totale anonimo).
	var obj_line := ""
	for ln in b._aftermath_lines:
		if String(ln).begins_with("Obiettivi:"):
			obj_line = String(ln)
	var s3: bool = "Obiettivo A" in obj_line and "Obiettivo B" in obj_line and "+2" in obj_line and "+9" in obj_line
	print("[%s] riepilogo dettagliato per Obiettivo (%s)" % ["OK" if s3 else "FAIL", obj_line])
	if not s3: fails += 1

	# 4) Round 6: ENTRAMBI si contano di NUOVO (non e' rimasto solo "l'altro"): stessa somma,
	#    visto che le condizioni/soglie usate qui restano vere anche alla soglia del round 6.
	b.gs.round = 6
	var va6: int = Objectives.objective_score(b.gs, "usa", usa.objectives[0], 1)
	var vb6: int = Objectives.objective_score(b.gs, "usa", usa.objectives[1], 1)
	var s4: bool = va6 == 2 and vb6 == 9
	print("[%s] round 6: ENTRAMBI gli Obiettivi contano di nuovo (A=%d atteso 2, B=%d atteso 9)" % [
		"OK" if s4 else "FAIL", va6, vb6])
	if not s4: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Obiettivi round 3/6 (somma di entrambi, nessuno scartato): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
