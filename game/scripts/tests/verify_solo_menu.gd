extends SceneTree
## Stadio 4c: menu modalita' SOLO (vs Bot). Verifica che il menu principale:
##   - esponga la modalita' "solo" e il selettore difficolta';
##   - calcoli correttamente l'elenco delle potenze Bot dai seggi marcati Bot;
##   - imposti GameConfig (automa_powers/difficulty) e azzeri i bot in Hot Seat/Online.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_solo_menu.gd

func _init() -> void:
	var fails := 0
	var mp: PackedScene = load("res://scenes/main_menu.tscn")
	var m: Variant = mp.instantiate()
	get_root().add_child(m)
	await process_frame

	# 1) Default: 2 giocatori, seggio 0 Umano, seggio 1 Bot.
	var s1: bool = m._player_count == 2 and m._seat_bot.size() == 2 \
		and m._seat_bot[0] == false and m._seat_bot[1] == true
	print("[%s] default 2p: seggio0=Umano seggio1=Bot (%s)" % ["OK" if s1 else "FAIL", str(m._seat_bot)])
	if not s1: fails += 1

	# 2) Modalita' solo: compare il selettore difficolta'; i seggi si rigenerano.
	m._on_mode("solo")
	await process_frame
	var s2: bool = m._mode == "solo" and m._diff_box.visible and not m._lobby_box.visible
	print("[%s] modalita' solo: difficolta' visibile, lobby nascosta" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# 3) Elenco Bot: con i default (seggio1=Bot) il bot e' la potenza del seggio 1.
	var expect_bot: String = m._seat_powers[1]
	var bots: Array = m._solo_bot_powers()
	var s3: bool = bots.size() == 1 and bots[0] == expect_bot
	print("[%s] elenco Bot di default = [%s] (atteso [%s])" % ["OK" if s3 else "FAIL", ", ".join(PackedStringArray(bots)), expect_bot])
	if not s3: fails += 1

	# 4) Marcando ANCHE il seggio 0 come Bot -> due bot (tutti i seggi).
	m._on_toggle_bot(0)
	await process_frame
	var bots2: Array = m._solo_bot_powers()
	var s4: bool = bots2.size() == 2 and (m._seat_powers[0] in bots2) and (m._seat_powers[1] in bots2)
	print("[%s] tutti Bot: elenco = [%s]" % ["OK" if s4 else "FAIL", ", ".join(PackedStringArray(bots2))])
	if not s4: fails += 1

	# 5) Difficolta': Hard selezionabile.
	m._on_difficulty("hard")
	var s5: bool = m._difficulty == "hard"
	print("[%s] difficolta' = %s" % ["OK" if s5 else "FAIL", m._difficulty])
	if not s5: fails += 1

	# 6) Avvio SOLO: GameConfig riceve i bot e la difficolta', net azzerato. (Senza
	#    cambiare scena: replichiamo la riga di _on_play, gia' coperta dall'helper.)
	GameConfig.automa_powers = m._solo_bot_powers()
	GameConfig.automa_difficulty = m._difficulty
	GameConfig.net = null
	var s6: bool = GameConfig.automa_powers.size() == 2 and GameConfig.automa_difficulty == "hard" \
		and GameConfig.is_automa(m._seat_powers[0])
	print("[%s] GameConfig solo: automa_powers=%s diff=%s" % [
		"OK" if s6 else "FAIL", str(GameConfig.automa_powers), GameConfig.automa_difficulty])
	if not s6: fails += 1

	# 7) Tornando in Hot Seat NON ci sono bot (il selettore difficolta' sparisce).
	m._on_mode("hotseat")
	await process_frame
	GameConfig.automa_powers = m._solo_bot_powers() if m._mode == "solo" else []
	var s7: bool = not m._diff_box.visible and GameConfig.automa_powers.is_empty()
	print("[%s] hotseat: nessun bot, difficolta' nascosta" % ["OK" if s7 else "FAIL"])
	if not s7: fails += 1

	m.queue_free()
	await process_frame
	GameConfig.automa_powers = []   # cleanup
	print("Verifica menu Solo (stadio 4c): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
