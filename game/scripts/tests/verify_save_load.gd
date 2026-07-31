extends SceneTree
## SALVATAGGIO E RIPRESA della partita (mancava del tutto: una partita dura 6 round e non si
## poteva interrompere - audit). Verifica il round-trip completo: stato di gioco (GameState) E
## stato che vive nella Vista (mazzi Country/Market scoperti, carte Commercio girate, abilità
## 1x/round usate, Registro, bot), più le guardie sui "punti sporchi" in cui non si può salvare.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_save_load.gd

var _fails := 0

func _init() -> void:
	SaveGame.delete_save()   # parti pulito
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = ["china"]
	GameConfig.automa_difficulty = "normal"
	GameConfig.resume_save = false
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	# --- Stato riconoscibile da ritrovare identico dopo la ripresa ---
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.gs.round = 3
	b.active_seat = 1
	b.round_turn_count = 5
	b._plays_left = 1
	b._played_this_turn = true
	var usa = b.gs.players[0]
	usa.money = 137
	usa.victory_points = 42
	usa.resources["energy"] = 7
	usa.production["food"] = 4
	usa.allied_countries = [{"id": "sv1", "display_name": "Paese Salvato", "region": "africa", "value": 2}]
	usa.exhausted = {"sv1": true}
	usa.fdi_countries = ["sv1"]
	usa.hand = [{"id": "h1", "display_name": "Carta in mano"}]
	b.gs.regions["africa"]["track"].add("usa", "permanent")
	b.gs.regions["africa"]["armies"]["usa"] = 3
	b._used_ongoing = {"usa": ["once_per_round:redraw_hand"]}
	b._commerce_flipped = {"china": [0]}
	b._focus_round = {"usa": 3}
	b._research_points = 6
	b._threat_defense = {"europe": {"usa": 2}}
	b._log_lines = ["riga di prova A", "riga di prova B"]
	b.market_display = [{"id": "m1", "display_name": "Market Salvata"}]
	var first_region: String = b.region_countries.keys()[0]
	b.region_countries[first_region]["available"] = [{"id": "cc1", "display_name": "Country scoperta"}]
	# Stato del bot (Cina): deve tornare identico, altrimenti riprendendo il bot "riparte".
	if b._automa.has("china"):
		b._automa["china"].money = 88
		b._automa["china"].vp = 17
		b._automa["china"].action_cubes = {"invest": 4}

	var inf_pre: int = b.gs.regions["africa"]["track"].count("usa")

	# --- 1) Si salva in un punto pulito ---
	var why: String = b.save_game()   # b è Variant: tipo esplicito, niente inferenza
	_check(why == "" and SaveGame.has_save(), "salvataggio riuscito in un punto pulito (motivo='%s')" % why)

	# --- 2) Le guardie impediscono di salvare a metà di una risoluzione ---
	b.playing_card = {"display_name": "in corso", "effect_ops": []}
	_check(b.save_game() != "", "NON si salva con una carta in risoluzione")
	b.playing_card = {}
	b.awaiting = "region"
	_check(b.save_game() != "", "NON si salva con una scelta sulla mappa in attesa")
	b.awaiting = ""
	b._trade_mode = true
	_check(b.save_game() != "", "NON si salva durante il Commercio")
	b._trade_mode = false

	var desc := SaveGame.describe()
	_check("Round 3" in desc, "descrizione per il menu: '%s'" % desc)

	b.queue_free()
	await process_frame

	# --- 3) RIPRESA in una board NUOVA (come farebbe il menu) ---
	GameConfig.resume_save = true
	var b2: Variant = bp.instantiate()
	get_root().add_child(b2)
	await process_frame
	await process_frame

	_check(not GameConfig.resume_save, "il flag di ripresa si consuma (niente ripresa a ripetizione)")

	var u2 = b2.gs.players[0]
	_check(b2.gs.round == 3 and b2.active_seat == 1 and b2.round_turn_count == 5,
		"stato di turno ripreso (round=%d, seggio=%d, turni=%d)" % [b2.gs.round, b2.active_seat, b2.round_turn_count])
	_check(u2.money == 137 and u2.victory_points == 42 and int(u2.resources["energy"]) == 7 \
		and int(u2.production["food"]) == 4,
		"giocatore ripreso (money=%d, VP=%d, energia=%d, prod.cibo=%d)" % [
			u2.money, u2.victory_points, int(u2.resources["energy"]), int(u2.production["food"])])
	_check(u2.allied_countries.size() == 1 and String(u2.allied_countries[0].get("id", "")) == "sv1" \
		and bool(u2.exhausted.get("sv1", false)) and ("sv1" in u2.fdi_countries),
		"alleati/esaurite/IDE ripresi")
	_check(u2.hand.size() == 1 and String(u2.hand[0].get("id", "")) == "h1", "mano ripresa (%d carte)" % u2.hand.size())
	_check(b2.gs.regions["africa"]["track"].count("usa") == inf_pre \
		and int(b2.gs.regions["africa"]["armies"].get("usa", 0)) == 3,
		"tabellone ripreso (influenza=%d, armate=%d)" % [
			b2.gs.regions["africa"]["track"].count("usa"), int(b2.gs.regions["africa"]["armies"].get("usa", 0))])

	# Stato della VISTA: è la parte che si sarebbe persa senza salvarla a parte.
	_check(b2._ongoing_used("usa", "once_per_round:redraw_hand"), "abilità 1x/round già usata ripresa")
	_check((b2._commerce_flipped.get("china", []) as Array).size() == 1, "carte Commercio girate riprese")
	_check(int(b2._focus_round.get("usa", 0)) == 3, "Focus già scelto nel round ripreso")
	_check(b2._research_points == 6, "punti Research ripresi (=%d)" % b2._research_points)
	_check(int((b2._threat_defense.get("europe", {}) as Dictionary).get("usa", 0)) == 2, "Difesa da Engage ripresa")
	_check("riga di prova A" in b2._log_lines and "riga di prova B" in b2._log_lines, "Registro ripreso")
	_check(b2.market_display.size() == 1 and String(b2.market_display[0].get("id", "")) == "m1", "Market scoperto ripreso")
	_check((b2.region_countries[first_region]["available"] as Array).size() == 1 \
		and String(b2.region_countries[first_region]["available"][0].get("id", "")) == "cc1",
		"Country scoperte sul tabellone riprese")
	_check(b2._automa.has("china") and b2._automa["china"].money == 88 and b2._automa["china"].vp == 17 \
		and int(b2._automa["china"].action_cubes.get("invest", 0)) == 4,
		"stato del BOT ripreso (money/VP/cubi azione)")

	# --- 4) La partita ripresa è giocabile: si può salvare di nuovo ---
	b2.playing_card = {}
	b2.play_queue = []
	b2.awaiting = ""
	_check(b2.save_game() == "", "la partita ripresa si può salvare di nuovo")

	b2.queue_free()
	await process_frame

	# --- 5) Cancellazione ---
	SaveGame.delete_save()
	_check(not SaveGame.has_save() and SaveGame.describe() == "", "salvataggio cancellabile")

	print("Verifica salvataggio/ripresa partita: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1
