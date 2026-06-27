extends SceneTree
## REGRESSIONE: la PREPARAZIONE guidata (scelta Focus -> ready Country card + Produzione del
## Focus + aumento Produzione opzionale) deve avvenire ANCHE al Round 1. Prima il Round 1
## saltava tutto (Focus Domestic forzato, dritti in Azione) -> la fase mancava. Verifica che
## una partita locale parta in Preparazione e, dopo che ogni giocatore sceglie il Focus,
## passi alla fase Azione applicando gli effetti del Focus.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_round1_prep.gd

func _init() -> void:
	var fails := 0
	var powers := ["usa", "china"]

	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null   # partita LOCALE (hot-seat): niente rete
	GameConfig.powers = powers
	var b: Variant = board_packed.instantiate()
	get_root().add_child(b)
	await process_frame

	# 1) Round 1 parte in PREPARAZIONE (non dritti in Azione come prima).
	var s1: bool = b.gs.round == 1 and b.gs.phase == WO.Phase.PREPARATION \
		and b._ui_phase == "Preparazione" and b._prep_idx == 0
	print("[%s] Round 1 parte in Preparazione (phase=%s, ui=%s, prep_idx=%d)" % [
		"OK" if s1 else "FAIL", str(b.gs.phase), b._ui_phase, b._prep_idx])
	if not s1: fails += 1

	# 2) Ogni giocatore sceglie il Focus (Domestic=0); se viene offerto l'aumento Produzione,
	#    lo si SALTA. Al termine la fase passa ad Azione.
	var guard := 0
	while b._ui_phase == "Preparazione" and guard < 10:
		guard += 1
		var seat: int = b.active_seat
		b.apply_command(GameCommands.choose_focus(seat, guard * 2, 0))
		await process_frame
		if b._prep_awaiting_increase:
			# type vuoto = salta l'aumento Produzione opzionale.
			b.apply_command(GameCommands.increase_production(seat, guard * 2 + 1, ""))
			await process_frame

	var s2: bool = b._ui_phase == "Azione" and b.gs.phase == WO.Phase.ACTION
	print("[%s] dopo le scelte del Focus la fase passa ad Azione (ui=%s)" % [
		"OK" if s2 else "FAIL", b._ui_phase])
	if not s2: fails += 1

	# 3) Gli effetti del Focus sono stati applicati al Round 1: _focus_round segnato per
	#    entrambe le potenze (prova che _apply_focus e' girato in Preparazione, non saltato).
	var applied := true
	for pw in powers:
		if int(b._focus_round.get(pw, -1)) != 1:
			applied = false
	print("[%s] effetti del Focus applicati al Round 1 (_focus_round per potenza = %s)" % [
		"OK" if applied else "FAIL", str(b._focus_round)])
	if not applied: fails += 1

	b.queue_free()
	await process_frame

	print("Verifica Preparazione al Round 1: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
