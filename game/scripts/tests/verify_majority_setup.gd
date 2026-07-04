extends SceneTree
## I PV di maggioranza NON devono essere "attivi" gia' al setup. I cubetti iniziali (incluso il
## NEUTRALE "local", nero) occupano la riga colorata SOPRA quella permanente (InfluenceTrack.
## starting) e contano nelle maggioranze come forze locali, ma NON toccano gli slot di `perm`:
## la riga permanente vera (permanent_slots in board.json, che corrisponde ESATTAMENTE alle
## caselle stampate sul tabellone reale) si completa SOLO quando i giocatori vi piazzano davvero
## Influenza in gioco. Bug precedente: i cubi iniziali venivano messi DENTRO gli stessi slot
## `perm` usati per lo scoring (Europe/Central Asia/East Asia Pacific attivavano i PV dopo un
## solo vero piazzamento, invece di richiedere TUTTI gli slot reali) — e il "fix" di allora per
## MENA/South Asia (raddoppiare permanent_slots con caselle "fill" finte) non corrispondeva al
## tabellone reale (verificato su assets/board/board.jpg: MENA ha 3 caselle permanenti, non 6;
## South Asia ne ha 2, non 4).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_majority_setup.gd

func _init() -> void:
	var fails := 0
	var gs := GameSetup.new_game(["usa", "china", "russia", "eu"])

	# 1) Nessuna Regione deve avere la riga permanente gia' completa al setup.
	var active := []
	for rid in gs.regions:
		var track: InfluenceTrack = gs.regions[rid]["track"]
		if track.all_permanent_filled():
			active.append(rid)
	var s1: bool = active.is_empty()
	print("[%s] nessuna Regione 'attiva' al setup (permanenti pieni: %s)" % [
		"OK" if s1 else "FAIL", str(active)])
	if not s1: fails += 1

	# 2) I cubetti "local" stanno nella riga INIZIALE di setup (InfluenceTrack.starting), NON
	#    negli slot permanenti veri: MENA e South Asia ne hanno uno ciascuna.
	var mena: InfluenceTrack = gs.regions["middle_east_north_africa"]["track"]
	var sasia: InfluenceTrack = gs.regions["south_asia"]["track"]
	var s2: bool = ("local" in mena.starting) and ("local" in sasia.starting) \
		and not ("local" in mena.perm) and not ("local" in sasia.perm)
	print("[%s] cubetto 'local' nero nella riga iniziale, non nei permanenti veri (MENA=%s, South Asia=%s)" % [
		"OK" if s2 else "FAIL", str("local" in mena.starting), str("local" in sasia.starting)])
	if not s2: fails += 1

	# 3) Il "local" CONTA nella classifica di maggioranza (forza locale).
	var rank: Array = Scoring.region_ranking(mena, gs.regions["middle_east_north_africa"]["majority_bonus"], {})
	var local_in_rank := false
	for e in rank:
		if String((e as Dictionary).get("owner", "")) == "local":
			local_in_rank = true
	var s3: bool = local_in_rank
	print("[%s] il 'local' compare nella classifica di maggioranza di MENA (%s)" % [
		"OK" if s3 else "FAIL", str(rank)])
	if not s3: fails += 1

	# 4) La Regione torna a segnare quando un GIOCATORE riempie le caselle permanenti rimaste.
	#    MENA: 3 slot permanenti VERI (i 3 cubi iniziali eu/usa/local sono a parte, in `starting`)
	#    -> servono 3 piazzamenti REALI perche' i PV si attivino.
	var before: bool = mena.all_permanent_filled()
	var guard := 0
	while not mena.all_permanent_filled() and guard < 12:
		guard += 1
		mena.add("china", "permanent")
	var after: bool = mena.all_permanent_filled()
	var s4: bool = (not before) and after
	print("[%s] MENA: non attiva al setup, attiva dopo aver riempito i permanenti (prima=%s, dopo=%s)" % [
		"OK" if s4 else "FAIL", str(before), str(after)])
	if not s4: fails += 1

	# 5) A riga piena la Regione segna e il 'local' resta nel conteggio (ma senza PV, non e' un
	#    giocatore reale): score_region non e' piu' vuoto.
	var players := ["usa", "china", "russia", "eu"]
	var scored: Dictionary = Scoring.score_region(mena, gs.regions["middle_east_north_africa"]["majority_bonus"], {}, players)
	var s5: bool = not scored.is_empty() and not scored.has("local")
	print("[%s] MENA piena segna PV ai giocatori (niente PV al 'local'): %s" % [
		"OK" if s5 else "FAIL", str(scored)])
	if not s5: fails += 1

	# 6) Bug segnalato: Europe (3 cubi iniziali eu/usa/russia), Central Asia (1, russia) ed
	#    East Asia Pacific (2, china/usa) attivavano i PV dopo un solo vero piazzamento perche'
	#    i cubi iniziali riempivano gia' quasi tutta la riga permanente vera. Ora servono TUTTI
	#    gli slot permanenti REALI (quanti sono le caselle stampate), a prescindere dai cubi
	#    iniziali: Europe ne servono 4, East Asia Pacific 3, Central Asia 2.
	var checks := [
		{"rid": "europe", "power": "eu", "real_slots": 4},
		{"rid": "east_asia_pacific", "power": "china", "real_slots": 3},
		{"rid": "central_asia", "power": "russia", "real_slots": 2},
	]
	var s6 := true
	for c in checks:
		var rid: String = c["rid"]
		var track: InfluenceTrack = gs.regions[rid]["track"]
		if track.all_permanent_filled():
			s6 = false
			print("  %s: gia' attiva al setup!" % rid)
			continue
		var guard2 := 0
		while not track.all_permanent_filled() and guard2 < int(c["real_slots"]) - 1:
			guard2 += 1
			track.add(String(c["power"]), "permanent")
		if track.all_permanent_filled():
			s6 = false
			print("  %s: attiva con solo %d/%d piazzamenti reali (dovrebbero servirne %d)" % [
				rid, guard2, int(c["real_slots"]), int(c["real_slots"])])
			continue
		track.add(String(c["power"]), "permanent")
		if not track.all_permanent_filled():
			s6 = false
			print("  %s: ancora NON attiva dopo %d piazzamenti reali (attesi esattamente %d)" % [
				rid, guard2 + 1, int(c["real_slots"])])
	print("[%s] Europe/East Asia Pacific/Central Asia: servono TUTTI gli slot permanenti reali" % ["OK" if s6 else "FAIL"])
	if not s6: fails += 1

	print("Verifica attivazione maggioranze (cubetti iniziali): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
