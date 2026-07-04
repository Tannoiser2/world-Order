extends SceneTree
## Segnalazione: "avevo 2 carte azione crescita (es. Optimization Program: Produci 1 tipo, poi
## Get a Growth Card), la prima OK, la seconda non mi ha fatto scegliere nessuna Growth e mi ha
## detto che il turno era risolto" - la 2a volta non c'erano più risorse per una Growth, ma
## invece di avvisare chiaramente, il gioco mostrava solo un messaggio silenzioso nella riga di
## stato (facile da non notare), dando l'impressione che il turno fosse finito da solo.
## Causa: quando "Get a Growth" e' il 2° op della carta (dopo "Produce", che ha già avuto
## effetto), _action_failed non può restituire la carta (giusto - il Produce è già avvenuto) ma
## avvisava solo con _status(), non con un banner prominente come per un fallimento normale.
## Corretto: stesso banner (_notify) ben visibile anche in questo caso, con un messaggio che
## spiega che il resto della carta è già stato applicato.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_action_failed_notify.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.active_seat = 0
	var p = b.gs.players[0]
	p.production = {"energy": 3, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0, "armies": 0}
	p.resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}
	p.money = 0   # NESSUNA Growth Lv1 è acquistabile senza risorse/money
	p.growth_cards = []
	var card := {"display_name": "Optimization Program",
		"effect_ops": [{"op": "produce", "count": 1}, {"op": "get_growth"}]}
	p.hand = [card]
	b.playing_card = {}
	b.play_queue = []
	b._plays_left = 1
	b._played_this_turn = false
	var seq_before: int = b._notify_seq

	b._play_card(card)
	await process_frame
	# La Produce (1° op) si apre per davvero: produco 1 Energia (unico tipo prodotto).
	var s1: bool = b._produce_mode
	print("[%s] 1° op (Produce) si apre per davvero" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	b._produce_sel = {"energy": 1}
	b._apply_produce()
	await process_frame

	# 1) Il 2° op (Get a Growth) fallisce (nessuna Growth acquistabile) - AVVISO PROMINENTE
	#    (non solo la riga di stato silenziosa), che spiega che il resto e' gia' applicato.
	var s2: bool = b._notify_seq > seq_before and "già stato applicato" in String(b._notify_msg)
	print("[%s] avviso PROMINENTE quando Get a Growth fallisce a metà carta (msg=%s)" % [
		"OK" if s2 else "FAIL", String(b._notify_msg)])
	if not s2: fails += 1

	# 2) La carta NON torna in mano (il Produce è già avvenuto: non si può disfare) - resta
	#    "giocata" - ma il turno AVANZA normalmente (niente blocco/stato inconsistente).
	var s3: bool = not (card in p.hand) and b.playing_card.is_empty()
	print("[%s] carta consumata (non tornata in mano) e turno sbloccato (playing_card vuota=%s)" % [
		"OK" if s3 else "FAIL", str(b.playing_card.is_empty())])
	if not s3: fails += 1

	# 3) Il Produce del 1° op resta comunque applicato (1 Energia guadagnata) - solo la Growth
	#    non ha avuto effetto, non l'intera carta.
	var s4: bool = int(p.resources.get("energy", 0)) == 1
	print("[%s] l'effetto Produce (già avvenuto) resta applicato (energia=%d, atteso 1)" % [
		"OK" if s4 else "FAIL", int(p.resources.get("energy", 0))])
	if not s4: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica avviso 'Get a Growth' fallita a metà carta: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
