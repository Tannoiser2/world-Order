extends SceneTree
## Bug: "i costi per la produzione non sono corretti" — con l'ordine VECCHIO (Produce del
## Focus PRIMA, Aumento Produzione DOPO) il +1 risorsa immediato dell'Aumento (es. +1 Energia
## "subito") arrivava troppo tardi per pagare la Produzione dello STESSO turno di Preparazione:
## il giocatore pagava l'Aumento ma non poteva ancora spenderne il beneficio. Con l'ordine
## NUOVO (Pronte -> Aumento -> Produce) la risorsa aumentata e' disponibile ED effettivamente
## spendibile nello stesso passo di Produce del Focus.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_focus_increase_produce_cost.gd

func _seat_of(b: Variant, power: String) -> int:
	for i in b.gs.players.size():
		if b.gs.players[i].power == power:
			return i
	return -1

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	var us := _seat_of(b, "usa")
	b._ui_phase = "Preparazione"; b.gs.phase = WO.Phase.PREPARATION
	b.gs.round = 2
	b._prep_idx = 0
	b.gs.turn_order.assign([us, 1 - us])
	b.active_seat = us
	b._prep_awaiting_increase = false
	b._produce_mode = false
	b._focus_round = {}
	var p = b.gs.players[us]
	p.exhausted = {}   # niente da riattivare: si passa subito all'Aumento Produzione
	p.money = 50
	# SOLO 0 Energia disponibile: senza il +1 "subito" dell'Aumento, produrre Beni di
	# consumo (costa 1 Energia + 1 Materia cad.) sarebbe impossibile.
	p.production = {"energy": 0, "raw_materials": 5, "food": 0, "consumer_goods": 3, "services": 0, "diplomacy": 0, "armies": 0}
	p.resources = {"energy": 0, "raw_materials": 5, "food": 0, "consumer_goods": 0, "services": 0, "diplomacy": 0}

	# 1) Scelta Focus Domestic -> offre l'Aumento Produzione (niente Produce ancora).
	b._do_focus(WO.Focus.DOMESTIC)
	await process_frame
	var s1: bool = b._prep_awaiting_increase and not b._produce_mode
	print("[%s] Focus scelto: offre l'Aumento Produzione prima della Produce" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) Aumenta la Produzione di Energia: +1 Produzione E +1 Energia SUBITO in risorsa.
	b.apply_command(GameCommands.increase_production(us, b._next_seq(), "energy"))
	await process_frame
	var s2: bool = int(p.production.get("energy", 0)) == 1 and int(p.resources.get("energy", 0)) == 1 \
		and p.money == 42 and b._produce_mode and not b._prep_awaiting_increase
	print("[%s] Aumento Energia: +1 Produzione, +1 Energia subito (-8 money), ora si apre la Produce (energia=%d money=%d produce=%s)" % [
		"OK" if s2 else "FAIL", int(p.resources.get("energy", 0)), p.money, str(b._produce_mode)])
	if not s2: fails += 1

	# 3) La Produzione del Focus (STESSO turno) puo' SPENDERE quell'Energia appena aumentata
	#    per produrre 1 Bene di consumo (costa 1 Energia + 1 Materia): prova che l'ordine
	#    Aumento -> Produce rende davvero disponibile/spendibile la risorsa aumentata.
	b._produce_sel = {"consumer_goods": 1}
	b._apply_produce()
	await process_frame
	var s3: bool = int(p.resources.get("consumer_goods", 0)) == 1 \
		and int(p.resources.get("energy", 0)) == 0 and int(p.resources.get("raw_materials", 0)) == 4
	print("[%s] Prodotto 1 Bene di consumo usando l'Energia appena aumentata (CG=%d En=%d RM=%d)" % [
		"OK" if s3 else "FAIL", int(p.resources.get("consumer_goods", 0)),
		int(p.resources.get("energy", 0)), int(p.resources.get("raw_materials", 0))])
	if not s3: fails += 1

	# 4) Dopo la Produce (ultimo passo) si passa al giocatore successivo.
	var s4: bool = not b._produce_mode and not b._prep_awaiting_increase and b._prep_idx == 1
	print("[%s] dopo la Produce del Focus: passa al giocatore successivo (idx=%d)" % ["OK" if s4 else "FAIL", b._prep_idx])
	if not s4: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica costi Produzione dopo Aumento (stesso turno): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
