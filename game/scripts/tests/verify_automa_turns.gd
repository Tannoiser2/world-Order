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

	# B) Azione del bot: esegue UN'azione vera (via Automa board) e passa il turno. Il tipo carta
	#    e' casuale, quindi non si assume QUALE azione: si verifica che il turno avanzi (seat
	#    successivo, conteggio +1) e che lo stato Automa del seggio esista.
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.gs.turn_order.assign([ci, 1 - ci]); b.round_turn_count = 0; b.active_seat = ci
	b.gs.players[ci].money = 200
	b.gs.players[ci].allied_countries = [{"id": "x", "region": "europe", "exports": ["food", "energy"]}]
	b._played_this_turn = false
	b._automa_run()
	# Visibilita': dopo la mossa il banner prominente mostra cosa ha fatto il bot (oltre al LOG).
	var banner_ok: bool = b.notify_banner.visible and ("BOT" in b.notify_label.text)
	var b_ok: bool = b.active_seat == (1 - ci) and b.round_turn_count == 1 and b._automa.has("china") and banner_ok
	print("[%s] bot Azione: azione eseguita, turno passato, banner='%s'" % [
		"OK" if b_ok else "FAIL", b.notify_label.text])
	if not b_ok: fails += 1

	# C) Gating: con automa_powers vuoto il driver NON fa nulla (nessun bot).
	GameConfig.automa_powers = []
	b._ui_phase = "Azione"; b.active_seat = ci; b.round_turn_count = 5
	var cm0: int = b.gs.players[ci].money
	b._automa_run()
	var c_ok: bool = b.gs.players[ci].money == cm0 and b.round_turn_count == 5
	print("[%s] gating off: nessun bot, nessun avanzamento" % ["OK" if c_ok else "FAIL"])
	if not c_ok: fails += 1

	# C2) Partita MISTA: con un umano al tavolo (solo China bot) _all_automa()=false -> il driver
	#     NON avanza da solo il riepilogo di fine round (lo fa l'umano). All-bot -> true.
	GameConfig.automa_powers = ["china"]
	var mix_ok: bool = not b._all_automa()
	GameConfig.automa_powers = ["china", "usa"]
	var allbot_ok: bool = b._all_automa()
	print("[%s] _all_automa: misto=%s all-bot=%s" % ["OK" if (mix_ok and allbot_ok) else "FAIL", str(not mix_ok), str(allbot_ok)])
	if not (mix_ok and allbot_ok): fails += 1
	GameConfig.automa_powers = []
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

	# E) Partita COMPLETA all-bot: pompa fino a fine partita (game_over), attraversando tutti i
	#    round, gli Scoring (3 e 6), Research, Aftermath e i riepiloghi, senza bloccarsi. Si cede
	#    il frame a ogni passo (come nel gioco reale, un passo per frame): cosi' i queue_free
	#    deferiti — es. la chiusura dell'overlay del riepilogo — vengono effettivamente applicati.
	var steps2 := 0
	while not b2.game_over and steps2 < 800:
		b2._automa_run()
		await process_frame
		steps2 += 1
	var e_ok: bool = b2.game_over and steps2 < 800
	print("[%s] partita completa all-bot: game_over=%s al Round %d in %d passi" % [
		"OK" if e_ok else "FAIL", str(b2.game_over), b2.gs.round, steps2])
	if not e_ok:
		print("   DIAG blocco: ui_phase=%s popup=%d summary_kind=%s prep_idx=%d research_idx=%d active=%d aft=%s playing=%s" % [
			b2._ui_phase, b2.popup_layer.get_child_count(), str(b2._summary.get("kind", "-")),
			b2._prep_idx, b2._research_idx, b2.active_seat, str(b2._aftermath_choice_p != null), str(not b2.playing_card.is_empty())])
	if not e_ok: fails += 1
	b2.queue_free()
	await process_frame

	GameConfig.automa_powers = []   # cleanup
	print("Verifica turni automatici dei bot (stadio 4a): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
