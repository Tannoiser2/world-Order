extends SceneTree
## Executive Order (modulo): una volta per partita, al posto di una carta, esegue una delle 8
## azioni (scelta). Consuma una giocata; se non usata vale +3 VP a fine partita (gia' nello
## scoring). Verifica l'uso, la scelta, la risoluzione, il consumo, il "non e' una carta" e la
## guardia "una sola volta".
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_executive_order.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	b._begin_action_phase()
	var seat: int = b.active_seat
	var p = b._active()
	p.production = {"energy": 2, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0, "armies": 0}
	p.resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	b._plays_left = 1
	b._played_this_turn = false

	# 1) All'inizio l'Executive Order e' disponibile.
	var s1: bool = not p.executive_order_used
	print("[%s] Executive Order disponibile all'inizio" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) Usandola: si segna come usata e apre la scelta tra le 8 azioni.
	b._play_executive_order()
	var s2: bool = p.executive_order_used and not b.playing_card.is_empty() \
		and b._popup_active() and b._popup_items.size() == 8
	print("[%s] uso EO -> usata=%s, scelta a %d opzioni" % ["OK" if s2 else "FAIL",
		str(p.executive_order_used), b._popup_items.size()])
	if not s2: fails += 1

	# 3) Scelta dell'opzione 'Produci 3 tipi' (indice 7): si entra in Produce con limite 3.
	b.apply_command(GameCommands.popup_choice(seat, 1, 7))
	await process_frame
	var s3: bool = b._produce_mode and b._produce_max_types == 3
	print("[%s] scelta 'Produci' -> Produce (limite tipi=%d)" % ["OK" if s3 else "FAIL", b._produce_max_types])
	if not s3: fails += 1

	# 4) Conferma Produce (1 Energia): l'azione si risolve, la giocata e' consumata e l'EO NON
	#    finisce ne' in mano ne' negli scarti (non e' una carta).
	b.apply_command(GameCommands.produce(seat, 2, {"energy": 1}))
	await process_frame
	var not_a_card := true
	for c in p.played:
		if String((c as Dictionary).get("display_name", "")) == "Executive Order":
			not_a_card = false
	var s4: bool = int(p.resources.get("energy", 0)) >= 1 and b.playing_card.is_empty() \
		and not b._produce_mode and b._played_this_turn and not_a_card and p.executive_order_used
	print("[%s] EO risolta (energia=%d, giocata consumata, non in scarti=%s, usata=%s)" % [
		"OK" if s4 else "FAIL", int(p.resources.get("energy", 0)), str(not_a_card), str(p.executive_order_used)])
	if not s4: fails += 1

	# 5) Guardia: non si puo' usare una seconda volta.
	b._plays_left = 1
	b.playing_card = {}
	b._play_executive_order()
	var s5: bool = b.playing_card.is_empty()   # bloccata: non parte nulla
	print("[%s] seconda Executive Order rifiutata (gia' usata)" % ["OK" if s5 else "FAIL"])
	if not s5: fails += 1

	# 6) Restituzione: se l'azione scelta non e' eseguibile (abort), l'EO torna NON usata.
	var p2 = b._active()
	p2.executive_order_used = false
	b._playing_eo = true
	b._abort_play("test")
	var s6: bool = (not p2.executive_order_used) and (not b._playing_eo)
	print("[%s] EO restituita su azione non eseguibile (usata=%s)" % ["OK" if s6 else "FAIL", str(p2.executive_order_used)])
	if not s6: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Executive Order: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
