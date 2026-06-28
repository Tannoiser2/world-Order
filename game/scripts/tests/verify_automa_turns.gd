extends SceneTree
## Stadio 4a: i bot (Automa) prendono i loro turni in automatico in partite LOCALI, senza
## bloccare la partita, SOLO quando attivati (GameConfig.automa_powers non vuoto). Comportamento
## minimale ma valido: in Preparazione scelgono il Focus e incassano il money del Focus; in
## Azione fanno un Trade (money) e passano; Research/Aftermath proseguono da soli.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_automa_turns.gd

func _seat(b: Variant, power: String) -> int:
	for i in b.gs.players.size():
		if b.gs.players[i].power == power:
			return i
	return -1

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")

	# ---- A/B/C: passi diretti del driver (sincroni) ----
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = ["china"]
	GameConfig.automa_difficulty = "normal"
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	var ci := _seat(b, "china")

	# A) Preparazione del bot: Focus scelto + money del Focus incassato; avanza.
	b.gs.round = 2
	b._ui_phase = "Preparazione"; b.gs.phase = WO.Phase.PREPARATION
	b.gs.turn_order.assign([ci, 1 - ci]); b._prep_idx = 0; b.active_seat = ci
	var m0: int = b.gs.players[ci].money
	b._automa_run()
	var a_ok: bool = b.gs.players[ci].money > m0 and int(b._focus_round.get("china", -1)) == 2 and b._prep_idx == 1
	print("[%s] bot Preparazione: Focus + money (%d -> %d), avanzato" % ["OK" if a_ok else "FAIL", m0, b.gs.players[ci].money])
	if not a_ok: fails += 1

	# B) Azione del bot: Trade (5 money/Export) e passaggio del turno.
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.gs.turn_order.assign([ci, 1 - ci]); b.round_turn_count = 0; b.active_seat = ci
	b.gs.players[ci].allied_countries = [{"exports": ["food", "energy"]}, {"exports": ["food"]}]   # 3 export -> 15
	b._played_this_turn = false
	var bm0: int = b.gs.players[ci].money
	b._automa_run()
	var b_ok: bool = b.gs.players[ci].money == bm0 + 15 and b.active_seat == (1 - ci) and b.round_turn_count == 1
	print("[%s] bot Azione: Trade +15 e turno passato (money %d->%d, seat=%d)" % [
		"OK" if b_ok else "FAIL", bm0, b.gs.players[ci].money, b.active_seat])
	if not b_ok: fails += 1

	# C) Gating: con automa_powers vuoto il driver NON fa nulla (nessun bot).
	GameConfig.automa_powers = []
	b._ui_phase = "Azione"; b.active_seat = ci; b.round_turn_count = 5
	var cm0: int = b.gs.players[ci].money
	b._automa_run()
	var c_ok: bool = b.gs.players[ci].money == cm0 and b.round_turn_count == 5
	print("[%s] gating off: nessun bot, nessun avanzamento" % ["OK" if c_ok else "FAIL"])
	if not c_ok: fails += 1
	b.queue_free()
	await process_frame

	# ---- D: catena (entrambi bot) -> ogni passo AVANZA lo stato; la fase Azione si conclude in
	#         un numero limitato di passi (niente loop infinito sullo stesso stato). Pilotata
	#         con chiamate dirette (deterministico, senza dipendere dai tempi di _process). ----
	GameConfig.automa_powers = ["usa", "china"]
	var b2: Variant = bp.instantiate()
	get_root().add_child(b2)
	await process_frame
	# La partita parte al Round 1 in Azione (la Preparazione si salta).
	b2._begin_action_phase()
	var steps := 0
	while b2._ui_phase == "Azione" and steps < 30:
		b2._automa_run()
		steps += 1
	var d_ok: bool = b2._ui_phase != "Azione" and steps < 30   # superata l'Azione in pochi passi
	print("[%s] catena bot: Azione conclusa in %d passi (-> '%s'), nessun loop" % [
		"OK" if d_ok else "FAIL", steps, b2._ui_phase])
	if not d_ok: fails += 1
	b2.queue_free()
	await process_frame

	GameConfig.automa_powers = []   # cleanup
	print("Verifica turni automatici dei bot (stadio 4a): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
