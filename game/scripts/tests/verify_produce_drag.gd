extends SceneTree
## Produce: rifatta la UI per non scrivere piu' "+N -N" sulle caselle e non usare i bottoni +/-
## per le Armate. Ora si trascina (drag&drop nativo di Godot, come il Commercio) il segnalino
## della risorsa lungo la SUA track fino allo slot desiderato (o lo si tocca, come fallback); le
## primarie necessarie si vedono scalare in diretta sulla LORO track. Ricetta corretta delle
## risorse derivate: Beni di consumo = Materie Prime + Energia, Servizi = Cibo + Energia, Armate
## = Cibo + Materie Prime, Diplomazia = denaro (non piu' una risorsa primaria).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_produce_drag.gd

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

	# 1) Ricetta corretta (SECONDARY_REQ).
	var s1: bool = Actions.SECONDARY_REQ["consumer_goods"] == {"raw_materials": 1, "energy": 1} \
		and Actions.SECONDARY_REQ["services"] == {"food": 1, "energy": 1} \
		and Actions.SECONDARY_REQ["armies"] == {"food": 1, "raw_materials": 1} \
		and Actions.SECONDARY_REQ["diplomacy"] == {"money": 3}
	print("[%s] ricetta risorse derivate corretta (CG=RM+En, Servizi=Cibo+En, Armate=Cibo+RM, Dip=denaro)" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) _produce_primary_spend: somma il consumo di TUTTE le secondarie/Armate selezionate.
	b._open_produce_ui(0, [])
	b._produce_sel = {"consumer_goods": 2, "services": 1}
	# consumer_goods 2 -> 2 RM + 2 En; services 1 -> 1 Cibo + 1 En. Energia totale = 2+1 = 3.
	var s2: bool = b._produce_primary_spend("energy") == 3 and b._produce_primary_spend("raw_materials") == 2 \
		and b._produce_primary_spend("food") == 1
	print("[%s] _produce_primary_spend somma il consumo di piu' selezioni (energy=%d rm=%d food=%d)" % [
		"OK" if s2 else "FAIL", b._produce_primary_spend("energy"), b._produce_primary_spend("raw_materials"), b._produce_primary_spend("food")])
	if not s2: fails += 1

	# 3) Drag&drop: _produce_drag_begin ritorna il payload col tipo; _produce_can_drop accetta
	#    solo lo stesso tipo; _produce_do_drop imposta la quantita' (i - cur) come farebbe un tap.
	b._produce_sel = {}
	p.production["consumer_goods"] = 5
	p.resources["consumer_goods"] = 2
	var data: Variant = b._produce_drag_begin(Vector2.ZERO, "consumer_goods")
	var s3a: bool = data is Dictionary and String(data.get("produce_res", "")) == "consumer_goods"
	print("[%s] _produce_drag_begin: payload col tipo trascinato (%s)" % ["OK" if s3a else "FAIL", str(data)])
	if not s3a: fails += 1

	var s3b: bool = b._produce_can_drop(Vector2.ZERO, data, "consumer_goods") \
		and not b._produce_can_drop(Vector2.ZERO, data, "services") \
		and not b._produce_can_drop(Vector2.ZERO, {"produce_res": "other"}, "consumer_goods")
	print("[%s] _produce_can_drop: accetta solo lo stesso tipo di risorsa" % ["OK" if s3b else "FAIL"])
	if not s3b: fails += 1

	# cur=2 (risorsa attuale), rilascio sullo slot i=5 -> quantita' da produrre = 5-2 = 3.
	b._produce_do_drop(Vector2.ZERO, data, "consumer_goods", 2, 5)
	var s3c: bool = int(b._produce_sel.get("consumer_goods", 0)) == 3
	print("[%s] _produce_do_drop: rilascio sullo slot imposta la quantita' (sel=%d, atteso 3)" % [
		"OK" if s3c else "FAIL", int(b._produce_sel.get("consumer_goods", 0))])
	if not s3c: fails += 1

	# 4) Armate: _produce_set("armies", i) imposta la quantita' ASSOLUTA (0..Produzione), come per
	#    le altre risorse — sostituisce il vecchio bottone ±.
	b._produce_sel = {}
	p.production["armies"] = 4
	b._produce_set("armies", 3)
	var s4: bool = int(b._produce_sel.get("armies", 0)) == 3
	print("[%s] Armate: _produce_set imposta la quantita' assoluta (sel=%d, atteso 3)" % [
		"OK" if s4 else "FAIL", int(b._produce_sel.get("armies", 0))])
	if not s4: fails += 1

	# 5) _apply_produce: le Armate ora consumano Cibo + Materie Prime (non piu' solo Materie
	#    Prime), riusando lo stesso motore (has_resources/spend) delle altre secondarie.
	p.resources["food"] = 5
	p.resources["raw_materials"] = 5
	p.armies_available = 0
	b._produce_sel = {"armies": 3}
	b._apply_produce()
	await process_frame
	var s5: bool = p.armies_available == 3 and int(p.resources.get("food", 0)) == 2 \
		and int(p.resources.get("raw_materials", 0)) == 2
	print("[%s] Produzione Armate: -3 Cibo -3 Materie Prime, +3 riserva (armate=%d cibo=%d rm=%d)" % [
		"OK" if s5 else "FAIL", p.armies_available, int(p.resources.get("food", 0)), int(p.resources.get("raw_materials", 0))])
	if not s5: fails += 1

	# 6) Diplomazia: si paga in DENARO (money), non con una risorsa primaria.
	p.money = 20
	p.resources["diplomacy"] = 0
	p.production["diplomacy"] = 2
	b._produce_sel = {"diplomacy": 2}
	b._apply_produce()
	await process_frame
	var s6: bool = int(p.resources.get("diplomacy", 0)) == 2 and p.money == 20 - 2 * 3
	print("[%s] Produzione Diplomazia: -%d money (denaro, non risorsa), +2 Diplomazia (money=%d)" % [
		"OK" if s6 else "FAIL", 2 * 3, p.money])
	if not s6: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Produce drag&drop + ricetta corretta: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
