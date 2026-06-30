extends SceneTree
## Bot vs Neutrali: in una partita con seggi Umani+Bot e potenze Neutrali, le carte
## Auto-Influence si applicano SOLO alle potenze Neutrali (non-seggio). I Bot sono seggi
## (giocano da soli) e NON ricevono l'influenza automatica. Verifica la richiesta dell'utente.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_bot_vs_neutral.gd

func _inf(track, owner: String) -> int:
	var n := 0
	for o in track.perm:
		if o != null and String(o) == owner: n += 1
	for o in track.temp:
		if o != null and String(o) == owner: n += 1
	return n

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	# 2 seggi: USA (umano) e Russia (bot). UE e Cina restano NEUTRALI (non sono seggi).
	GameConfig.powers = ["usa", "russia"]
	GameConfig.automa_powers = ["russia"]
	GameConfig.automa_difficulty = "normal"
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	# 1) Stato Automa creato per il Bot (russia), non per l'umano (usa).
	var s1: bool = b._automa.has("russia") and not b._automa.has("usa") \
		and b.gs.players.size() == 2
	print("[%s] seggi: Bot=russia, umano=usa; 2 seggi (UE/Cina neutrali)" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) Carta Auto-Influence con una riga per ogni potenza in Regioni distinte. Applicandola,
	#    SOLO le Neutrali (UE, Cina) ricevono Influenza; i seggi (USA, Russia) NO.
	var card := {"art": "", "rows": {
		"usa":    {"region": "americas", "army": false, "trade_with": null},
		"eu":     {"region": "europe", "army": false, "trade_with": null},
		"russia": {"region": "central_asia", "army": false, "trade_with": null},
		"china":  {"region": "east_asia_pacific", "army": false, "trade_with": null},
	}}
	var eu0 := _inf(b.gs.regions["europe"]["track"], "eu")
	var china0 := _inf(b.gs.regions["east_asia_pacific"]["track"], "china")
	var usa0 := _inf(b.gs.regions["americas"]["track"], "usa")
	var russia0 := _inf(b.gs.regions["central_asia"]["track"], "russia")
	b._auto_inf_shown = [card]
	b._apply_auto_influence([])
	var eu1 := _inf(b.gs.regions["europe"]["track"], "eu")
	var china1 := _inf(b.gs.regions["east_asia_pacific"]["track"], "china")
	var usa1 := _inf(b.gs.regions["americas"]["track"], "usa")
	var russia1 := _inf(b.gs.regions["central_asia"]["track"], "russia")
	var neutral_ok: bool = eu1 == eu0 + 1 and china1 == china0 + 1
	var seat_ok: bool = usa1 == usa0 and russia1 == russia0
	print("[%s] Neutrali ricevono Auto-Influence: UE %d->%d, Cina %d->%d" % [
		"OK" if neutral_ok else "FAIL", eu0, eu1, china0, china1])
	if not neutral_ok: fails += 1
	print("[%s] Seggi NON ricevono Auto-Influence: USA(seggio) %d->%d, Russia(bot) %d->%d" % [
		"OK" if seat_ok else "FAIL", usa0, usa1, russia0, russia1])
	if not seat_ok: fails += 1

	b.queue_free()
	await process_frame
	GameConfig.automa_powers = []   # cleanup
	print("Verifica Bot vs Neutrali (Auto-Influence): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
