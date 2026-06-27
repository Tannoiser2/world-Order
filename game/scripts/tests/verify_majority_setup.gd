extends SceneTree
## I PV di maggioranza NON devono essere "attivi" gia' al setup. I cubetti iniziali (incluso il
## NEUTRALE "local", nero) occupano la loro casella e contano nelle maggioranze come forze locali,
## ma NON devono completare da soli la riga permanente (che fa scattare i PV). MENA e South Asia
## partivano "attive" perche' i loro slot permanenti contavano solo le caselle iniziali: ora
## board.json conta anche le caselle "fill", cosi' la riga si completa solo quando i giocatori
## piazzano davvero altra Influenza permanente.
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

	# 2) I cubetti "local" stanno negli slot PERMANENTI (occupano la casella iniziale): MENA e
	#    South Asia ne hanno uno ciascuna.
	var mena: InfluenceTrack = gs.regions["middle_east_north_africa"]["track"]
	var sasia: InfluenceTrack = gs.regions["south_asia"]["track"]
	var s2: bool = ("local" in mena.perm) and ("local" in sasia.perm)
	print("[%s] cubetto 'local' nero negli slot permanenti iniziali (MENA=%s, South Asia=%s)" % [
		"OK" if s2 else "FAIL", str("local" in mena.perm), str("local" in sasia.perm)])
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
	#    MENA: 6 slot permanenti (3 iniziali eu/usa/local + 3 "fill" vuote) -> serve riempire le
	#    fill perche' i PV si attivino.
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

	print("Verifica attivazione maggioranze (cubetti iniziali): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
