extends SceneTree
## Verifica i criteri MINACCIA/Difesa di Move/Build dell'Automa (_pick_threat_region):
##  1) priorità DIFESA: sceglie la Regione della zona dove è sotto minaccia;
##  2) tra più Regioni sotto minaccia, la minima differenza MINACCIA-Difesa;
##  3) NATO: USA ignora la minaccia di EU (e viceversa);
##  4) priorità OFFENSIVA in zona: mette un altro giocatore sotto minaccia.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_automa_defense.gd

## Imposta zona e Armate di una Regione (sovrascrive lo stato di setup).
func _set_region(gs, rid: String, zone: Array, armies: Dictionary) -> void:
	gs.regions[rid]["zone"] = zone.duplicate()
	gs.regions[rid]["armies"] = armies.duplicate()

## Tutti i giocatori su Focus Nazionale (niente bonus Militare a MINACCIA/Difesa).
func _all_domestic(gs) -> void:
	for pl in gs.players:
		pl.focus = WO.Focus.DOMESTIC

func _init() -> void:
	var fails := 0
	var powers := ["usa", "eu", "russia", "china"]

	# 1) DIFESA: la Russia è nella zona di A (avversario USA con 2 Armate, lei 0 -> sotto minaccia)
	#    e di B (sicura). _pick_threat_region deve scegliere A.
	var gs = GameSetup.new_game(powers)
	_all_domestic(gs)
	var keys: Array = gs.regions.keys()
	var ra: String = keys[0]
	var rb: String = keys[1]
	_set_region(gs, ra, ["russia"], {"usa": 2})
	_set_region(gs, rb, ["russia"], {})
	var ru := Automa.from_setup("russia")
	var ok := func(r): return r == ra or r == rb
	var pick1: String = ru._pick_threat_region(gs, ok)
	var s1: bool = pick1 == ra
	print("[%s] DIFESA: sceglie la Regione sotto minaccia (%s, atteso %s)" % ["OK" if s1 else "FAIL", pick1, ra])
	if not s1: fails += 1

	# 2) MINIMA DIFFERENZA: due Regioni sotto minaccia, margine +1 (A) e +3 (B) -> sceglie A.
	var gs2 = GameSetup.new_game(powers)
	_all_domestic(gs2)
	var k2: Array = gs2.regions.keys()
	var ra2: String = k2[0]
	var rb2: String = k2[1]
	_set_region(gs2, ra2, ["russia"], {"usa": 1})   # margine 1 - 0 = 1
	_set_region(gs2, rb2, ["russia"], {"usa": 3})   # margine 3 - 0 = 3
	var ru2 := Automa.from_setup("russia")
	var ok2 := func(r): return r == ra2 or r == rb2
	var pick2: String = ru2._pick_threat_region(gs2, ok2)
	var s2: bool = pick2 == ra2
	print("[%s] MINIMA DIFFERENZA: sceglie margine minimo (%s, atteso %s)" % ["OK" if s2 else "FAIL", pick2, ra2])
	if not s2: fails += 1

	# 3) NATO: USA bot, Regione X con minaccia solo da EU (partner NATO, ignorata) e Regione Y con
	#    minaccia da Cina. La difesa deve scattare su Y (Cina), non su X (EU).
	var gs3 = GameSetup.new_game(powers)
	_all_domestic(gs3)
	var k3: Array = gs3.regions.keys()
	var rx: String = k3[0]
	var ry: String = k3[1]
	_set_region(gs3, rx, ["usa"], {"eu": 3})     # EU = partner NATO -> ignorato
	_set_region(gs3, ry, ["usa"], {"china": 3})  # Cina = minaccia reale
	var us := Automa.from_setup("usa")
	var ok3 := func(r): return r == rx or r == ry
	var pick3: String = us._pick_threat_region(gs3, ok3)
	var s3: bool = pick3 == ry
	print("[%s] NATO: USA ignora la minaccia di EU, difende contro la Cina (%s, atteso %s)" % [
		"OK" if s3 else "FAIL", pick3, ry])
	if not s3: fails += 1

	# 4) OFFENSIVA in zona: nessuna Regione sotto minaccia; in A (zona russia+china, 1 Armata
	#    ciascuno) piazzando 1 Armata la Russia mette la Cina sotto minaccia; B è neutra.
	var gs4 = GameSetup.new_game(powers)
	_all_domestic(gs4)
	var k4: Array = gs4.regions.keys()
	var ra4: String = k4[0]
	var rb4: String = k4[1]
	_set_region(gs4, ra4, ["russia", "china"], {"russia": 1, "china": 1})  # 1<=1 ora, 2>1 dopo
	_set_region(gs4, rb4, ["russia"], {})
	var ru4 := Automa.from_setup("russia")
	var ok4 := func(r): return r == ra4 or r == rb4
	var pick4: String = ru4._pick_threat_region(gs4, ok4)
	var s4: bool = pick4 == ra4
	print("[%s] OFFENSIVA: sceglie la Regione dove mette un altro sotto minaccia (%s, atteso %s)" % [
		"OK" if s4 else "FAIL", pick4, ra4])
	if not s4: fails += 1

	# 5) Coerenza col regolamento: con tutti i giocatori non in zona/senza Armate, ripiego su una
	#    Regione valida (preferendo la zona).
	var gs5 = GameSetup.new_game(powers)
	_all_domestic(gs5)
	var k5: Array = gs5.regions.keys()
	var rz: String = k5[0]
	_set_region(gs5, rz, ["russia"], {})   # nessuna minaccia, nessun bersaglio
	var ru5 := Automa.from_setup("russia")
	var ok5 := func(r): return r == rz
	var pick5: String = ru5._pick_threat_region(gs5, ok5)
	var s5: bool = pick5 == rz
	print("[%s] RIPIEGO: una Regione valida quando non c'è minaccia né bersaglio (%s)" % ["OK" if s5 else "FAIL", pick5])
	if not s5: fails += 1

	print("Verifica difesa MINACCIA dell'Automa: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
