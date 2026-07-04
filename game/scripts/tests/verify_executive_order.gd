extends SceneTree
## Executive Order (modulo): ora vive nella mano come le carte Strategiche (dopo di esse) e si
## attiva con la STESSA logica del gettone 10 monete/Strategic Asset: selezioni prima una carta
## di mano, poi tocchi l'Ordine Esecutivo per attivarlo — quella carta e' il costo (faccia in
## giu', va negli scarti). Una volta per partita, al posto di una carta, esegue una delle 8
## azioni (scelta). Se non usata vale +3 VP a fine partita (gia' nello scoring). Essendo un
## costo gia' speso all'attivazione (come gli Asset), se la prima azione fallisce NON si
## restituisce piu' (comportamento allineato agli Strategic Asset).
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
	p.hand = [{"id": "h1", "display_name": "Test1"}, {"id": "h2", "display_name": "Test2"}]
	b._plays_left = 1
	b._played_this_turn = false

	# 1) All'inizio l'Executive Order e' disponibile.
	var s1: bool = not p.executive_order_used
	print("[%s] Executive Order disponibile all'inizio" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) Usandola con una carta di mano selezionata come costo: si segna come usata, la carta
	#    sparisce dalla mano (va negli scarti), e apre la scelta tra le 8 azioni.
	var spent: Dictionary = p.hand[0]
	var hand_before: int = p.hand.size()
	b._play_executive_order(spent)
	var s2: bool = p.executive_order_used and not b.playing_card.is_empty() \
		and b._popup_active() and b._popup_items.size() == 8 \
		and p.hand.size() == hand_before - 1 and not (spent in p.hand) and (spent in p.discard)
	print("[%s] uso EO -> usata=%s, carta di mano spesa (mano %d->%d, negli scarti=%s), scelta a %d opzioni" % [
		"OK" if s2 else "FAIL", str(p.executive_order_used), hand_before, p.hand.size(), str(spent in p.discard), b._popup_items.size()])
	if not s2: fails += 1

	# 3) Scelta dell'opzione 'Produci 3 tipi' (indice 7): si entra in Produce con limite 3.
	b.apply_command(GameCommands.popup_choice(seat, 1, 7))
	await process_frame
	var s3: bool = b._produce_mode and b._produce_max_types == 3
	print("[%s] scelta 'Produci' -> Produce (limite tipi=%d)" % ["OK" if s3 else "FAIL", b._produce_max_types])
	if not s3: fails += 1

	# 4) Conferma Produce (1 Energia): l'azione si risolve, la giocata e' consumata e l'EO NON
	#    finisce ne' in mano ne' negli scarti come "carta" (non e' una carta: solo il suo costo lo e').
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

	# 5) Guardia: non si puo' usare una seconda volta (anche con un'altra carta di mano).
	b._plays_left = 1
	b.playing_card = {}
	var hand_before2: int = p.hand.size()
	b._play_executive_order(p.hand[0])
	var s5: bool = b.playing_card.is_empty() and p.hand.size() == hand_before2   # bloccata: non parte nulla, nessuna carta persa
	print("[%s] seconda Executive Order rifiutata (gia' usata, nessuna carta persa)" % ["OK" if s5 else "FAIL"])
	if not s5: fails += 1

	# 6) Come uno Strategic Asset: la carta di mano e' gia' il costo speso all'attivazione. Se la
	#    PRIMA azione fallisce (risorse insufficienti), NON si restituisce piu' nulla (a differenza
	#    di una carta normale) — comportamento allineato a _playing_asset.
	var p2 = b.gs.players[1]
	p2.executive_order_used = false
	p2.hand = [{"id": "hx", "display_name": "TestX"}]
	var spent2: Dictionary = p2.hand[0]
	b.active_seat = 1
	b._plays_left = 1
	b.playing_card = {}
	b._play_executive_order(spent2)
	var s6a: bool = p2.executive_order_used and not (spent2 in p2.hand) and (spent2 in p2.discard)
	print("[%s] 2° uso EO: carta spesa, EO usata (usata=%s, carta persa=%s)" % [
		"OK" if s6a else "FAIL", str(p2.executive_order_used), str(not (spent2 in p2.hand))])
	if not s6a: fails += 1
	b._play_ops_started = 1
	var aborted: bool = b._action_failed("test: azione non eseguibile")
	# NON abortita (a differenza di una carta normale): playing_card resta impostata, la carta
	# di mano spesa resta persa e l'EO resta usata.
	var s6b: bool = not aborted and p2.executive_order_used and not (spent2 in p2.hand) \
		and not b.playing_card.is_empty()
	print("[%s] fallimento 1a azione: EO NON restituita (abortita=%s, usata=%s, carta ancora persa=%s)" % [
		"OK" if s6b else "FAIL", str(aborted), str(p2.executive_order_used), str(not (spent2 in p2.hand))])
	if not s6b: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Executive Order: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
