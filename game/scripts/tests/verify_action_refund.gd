extends SceneTree
## Azione non eseguibile per risorse insufficienti: la carta NON dev'essere sprecata.
## - Se l'azione fallita è la PRIMA (e unica) cosa della carta -> carta restituita in mano,
##   turno NON consumato.
## - Se un op PRECEDENTE ha già avuto effetto (carta multi-op) -> si prosegue, carta giocata.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_action_refund.gd

func _init() -> void:
	var fails := 0
	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	var b: Variant = board_packed.instantiate()
	get_root().add_child(b)
	await process_frame

	var seat: int = b.active_seat
	var p = b.gs.players[seat]

	# Trova una Country che QUESTA potenza puo' allearsi, con valore > 0 (costo > 0).
	var rid0 := ""
	var target_id := ""
	for rid in b.region_countries:
		for c in ((b.region_countries.get(rid, {}) as Dictionary).get("available", []) as Array):
			var cd := c as Dictionary
			if int(cd.get("value", 0)) > 0 and not (p.power in cd.get("no_relations_powers", [])):
				rid0 = rid; target_id = String(cd.get("id", "")); break
		if target_id != "":
			break

	# --- CASO 1: improve come UNICA azione, diplomazia 0 -> azione impossibile -> RESTITUITA ---
	p.resources["diplomacy"] = 0
	p.allied_countries = []                  # niente alleati -> niente barra sconto
	p.hand.clear()
	p.hand.append({"display_name": "Solo Improve", "effect_ops": [{"op": "improve_relations"}], "effect_modifiers": []})
	b._plays_left = 1
	b._played_this_turn = false
	var hand0: int = p.hand.size()

	b.apply_command(GameCommands.play_card(seat, 1, 0))
	await process_frame
	b.apply_command(GameCommands.pick_board_country(seat, 2, rid0, target_id))
	await process_frame

	var refunded: bool = p.hand.size() == hand0 and b.playing_card.is_empty() and b.awaiting == "" \
		and not b._played_this_turn and b._plays_left == 1
	print("[%s] azione impossibile (1° op): carta RESTITUITA (mano=%d, playing=%s, played=%s, plays=%d)" % [
		"OK" if refunded else "FAIL", p.hand.size(), str(not b.playing_card.is_empty()), str(b._played_this_turn), b._plays_left])
	if not refunded: fails += 1

	# --- CASO 2: carta multi-op (play_another POI improve impossibile): NON si restituisce ---
	p.resources["diplomacy"] = 0
	p.allied_countries = []
	p.hand.clear()
	p.hand.append({"display_name": "Doppio", "effect_ops": [{"op": "play_another"}, {"op": "improve_relations"}], "effect_modifiers": []})
	b._plays_left = 1
	b._played_this_turn = false

	b.apply_command(GameCommands.play_card(seat, 3, 0))
	await process_frame
	b.apply_command(GameCommands.pick_board_country(seat, 4, rid0, target_id))
	await process_frame

	# play_another ha gia' avuto effetto: la carta NON torna in mano, e' giocata.
	var consumed: bool = p.hand.is_empty() and b.playing_card.is_empty() and b._played_this_turn
	print("[%s] op precedente gia' applicato: la carta NON viene restituita (mano=%d, played=%s)" % [
		"OK" if consumed else "FAIL", p.hand.size(), str(b._played_this_turn)])
	if not consumed: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica restituzione carta su azione impossibile: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
