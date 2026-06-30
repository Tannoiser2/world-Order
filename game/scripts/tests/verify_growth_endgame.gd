extends SceneTree
## Carte Crescita aggiuntive (D&D), 2° gruppo: effetti nel motore puro (Scoring/THREAT).
##   - "Autorità Inconfutabile": a parità di Influenza vince il pareggio (ignora le Armate).
##   - "Programma Nucleare": +1 MINACCIA e +1 Difesa in ogni Regione (anche senza Armate).
##   - Costo in Armate della Growth: pagato dalla riserva (armies_available).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_endgame.gd

func _init() -> void:
	var fails := 0

	# 1) Tie-break (#9): USA e Cina pari (1 Influenza ciascuno, 0 Armate). Senza l'abilità
	#    condividono la posizione più bassa; con l'abilità USA vince la posizione più alta.
	var track := InfluenceTrack.new([1, 1], [])
	track.add("usa", "permanent")
	track.add("china", "permanent")
	var players := ["usa", "china"]
	var mb := [10, 5]
	var no_tb: Dictionary = Scoring.score_region(track, mb, {}, players, [])
	var with_tb: Dictionary = Scoring.score_region(track, mb, {}, players, ["usa"])
	# senza: 1 cubo + bonus posizione 2 (5) = 6 ciascuno. con: USA 1+10=11, Cina 1+5=6.
	var s1: bool = int(no_tb.get("usa", 0)) == 6 and int(no_tb.get("china", 0)) == 6 \
		and int(with_tb.get("usa", 0)) == 11 and int(with_tb.get("china", 0)) == 6
	print("[%s] tie-break: senza usa=%d/china=%d, con usa=%d/china=%d" % [
		"OK" if s1 else "FAIL", int(no_tb.get("usa",0)), int(no_tb.get("china",0)),
		int(with_tb.get("usa",0)), int(with_tb.get("china",0))])
	if not s1: fails += 1

	# 2) Programma Nucleare - MINACCIA (#10): in una Regione di zona Cina, gli USA SENZA Armate
	#    non minacciano; CON l'abilità minacciano (+1) e la Cina (Difesa 0) perde 2 VP.
	var loss_no: Dictionary = Threat.resolve_region(["china"], {"china": 0}, {}, {}, [], [])
	var loss_nuc: Dictionary = Threat.resolve_region(["china"], {"china": 0}, {}, {}, [], ["usa"])
	var s2: bool = loss_no.is_empty() and int(loss_nuc.get("china", 0)) == 2
	print("[%s] nucleare MINACCIA: senza=%s, con -> Cina perde %d" % [
		"OK" if s2 else "FAIL", str(loss_no), int(loss_nuc.get("china", 0))])
	if not s2: fails += 1

	# 3) Programma Nucleare - DIFESA (#10): zona USA, Cina 1 Armata. Senza, gli USA (Difesa 0)
	#    perdono 2; con l'abilità (Difesa +1 = 1 >= MINACCIA Cina 1) NON perdono.
	var def_no: Dictionary = Threat.resolve_region(["usa"], {"china": 1, "usa": 0}, {}, {}, [], [])
	var def_nuc: Dictionary = Threat.resolve_region(["usa"], {"china": 1, "usa": 0}, {}, {}, [], ["usa"])
	var s3: bool = int(def_no.get("usa", 0)) == 2 and not def_nuc.has("usa")
	print("[%s] nucleare DIFESA: senza USA perde %d, con USA perde %d" % [
		"OK" if s3 else "FAIL", int(def_no.get("usa", 0)), int(def_nuc.get("usa", 0))])
	if not s3: fails += 1

	# 4) Costo in Armate: "Programma Nucleare" costa 5 Servizi + 2 Armate (dalla riserva).
	var gs = GameSetup.new_game(["usa", "china"])
	var p = gs.player_by_power("usa")
	p.armies_available = 5
	p.resources["services"] = 10
	p.growth_cards = []
	var nuke := {"id": "growth_programma_nucleare", "level": 1, "victory_points": 8, "cost": {"services": 5, "armies": 2}}
	var vp0: int = p.victory_points
	var ok: bool = Actions.execute_get_growth(p, nuke, 1)
	var s4: bool = ok and p.armies_available == 3 and int(p.resources.get("services", 0)) == 5 \
		and p.victory_points == vp0 + 8 and p.growth_cards.size() == 1
	print("[%s] costo Armate: armate 5->%d, servizi 10->%d, +8 VP" % [
		"OK" if s4 else "FAIL", p.armies_available, int(p.resources.get("services", 0))])
	if not s4: fails += 1

	# 5) Costo in Armate insufficiente: l'acquisto fallisce e NON spende nulla.
	var p2 = gs.player_by_power("china")
	p2.armies_available = 1   # servono 2
	p2.resources["services"] = 10
	p2.growth_cards = []
	var ok2: bool = Actions.execute_get_growth(p2, nuke, 1)
	var s5: bool = not ok2 and p2.armies_available == 1 and int(p2.resources.get("services", 0)) == 10 \
		and p2.growth_cards.is_empty()
	print("[%s] armate insufficienti: acquisto rifiutato, nulla speso" % ["OK" if s5 else "FAIL"])
	if not s5: fails += 1

	print("Verifica Growth espansione (Scoring/THREAT): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
