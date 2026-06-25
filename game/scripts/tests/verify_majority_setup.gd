extends SceneTree
## I PV di maggioranza NON devono essere "attivi" gia' al setup: i cubetti iniziali neutrali
## "local" non sono influenza permanente di una potenza, quindi non devono completare da soli la
## riga permanente. Verifica che NESSUNA Regione parta con i permanenti tutti pieni, che i
## "local" siano in temporanea, e che una Regione torni a segnare quando un giocatore riempie
## davvero la riga permanente.
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

	# 2) I cubetti "local" stanno in TEMPORANEA, non in PERMANENTE.
	var local_in_perm := []
	for rid in gs.regions:
		var track: InfluenceTrack = gs.regions[rid]["track"]
		if "local" in track.perm:
			local_in_perm.append(rid)
	var s2: bool = local_in_perm.is_empty()
	print("[%s] nessun cubetto 'local' negli slot permanenti (in perm: %s)" % [
		"OK" if s2 else "FAIL", str(local_in_perm)])
	if not s2: fails += 1

	# 3) La Regione torna a segnare quando un GIOCATORE riempie i permanenti rimasti.
	#    MENA: 3 permanenti, al setup eu+usa (1 slot libero) -> un'altra influenza permanente la
	#    completa e i PV si attivano.
	var mena: InfluenceTrack = gs.regions["middle_east_north_africa"]["track"]
	var before: bool = mena.all_permanent_filled()
	while not mena.all_permanent_filled():
		mena.add("china", "permanent")
	var after: bool = mena.all_permanent_filled()
	var s3: bool = (not before) and after
	print("[%s] MENA: non attiva al setto, attiva dopo aver riempito i permanenti (prima=%s, dopo=%s)" % [
		"OK" if s3 else "FAIL", str(before), str(after)])
	if not s3: fails += 1

	print("Verifica attivazione maggioranze (cubetti iniziali): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
