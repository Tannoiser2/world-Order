extends SceneTree
## Menu Locale: per ognuna delle 4 superpotenze si sceglie Umano / Bot / Neutrale. Le attive
## (Umane o Bot) sono i seggi; le Neutrali sono guidate dalle Auto-Influence. Verifica i ruoli,
## la mappatura a GameConfig (powers/automa_powers) e l'azzeramento dei bot in Online.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_solo_menu.gd

func _init() -> void:
	var fails := 0
	var mp: PackedScene = load("res://scenes/main_menu.tscn")
	var m: Variant = mp.instantiate()
	get_root().add_child(m)
	await process_frame

	# 1) Default: USA e Cina Umani, UE e Russia Neutrali -> 2 attive, nessun bot.
	var s1: bool = m._mode == "local" and m._active_powers().size() == 2 \
		and not m._has_bot() and m._role["usa"] == "human" and m._role["eu"] == "neutral"
	print("[%s] default: attive=%s bot=%s" % ["OK" if s1 else "FAIL", str(m._active_powers()), str(m._bot_powers())])
	if not s1: fails += 1

	# 2) Solitario: USA Umano, UE/Russia/Cina Bot -> 4 attive, 3 bot; difficolta' visibile.
	m._on_role("eu", "bot")
	m._on_role("russia", "bot")
	m._on_role("china", "bot")
	await process_frame
	var s2: bool = m._active_powers().size() == 4 and m._bot_powers().size() == 3 \
		and m._diff_box.visible and m._has_bot()
	print("[%s] solitario: attive=%d bot=%s diff_visibile=%s" % [
		"OK" if s2 else "FAIL", m._active_powers().size(), str(m._bot_powers()), str(m._diff_box.visible)])
	if not s2: fails += 1

	# 3) Difficolta' Hard.
	m._on_difficulty("hard")
	var s3: bool = m._difficulty == "hard"
	print("[%s] difficolta' = %s" % ["OK" if s3 else "FAIL", m._difficulty])
	if not s3: fails += 1

	# 4) Avvio Locale: GameConfig riceve le potenze attive, i bot e la difficolta'; net azzerato.
	#    (Replica la logica di _on_play senza cambiare scena.)
	GameConfig.player_count = m._active_powers().size()
	GameConfig.powers = m._active_powers()
	GameConfig.automa_powers = m._bot_powers()
	GameConfig.automa_difficulty = m._difficulty
	GameConfig.net = null
	var s4: bool = GameConfig.powers.size() == 4 and GameConfig.automa_powers.size() == 3 \
		and GameConfig.is_automa("china") and not GameConfig.is_automa("usa") \
		and GameConfig.automa_difficulty == "hard"
	print("[%s] GameConfig locale: powers=%s automa=%s" % [
		"OK" if s4 else "FAIL", str(GameConfig.powers), str(GameConfig.automa_powers)])
	if not s4: fails += 1

	# 5) Una potenza Neutrale: con 2 Umani + 1 Bot, la 4a resta Neutrale (non e' un seggio).
	m._on_role("usa", "human")
	m._on_role("eu", "human")
	m._on_role("russia", "bot")
	m._on_role("china", "neutral")
	await process_frame
	var s5: bool = m._active_powers().size() == 3 and m._bot_powers() == ["russia"] \
		and "china" not in m._active_powers()
	print("[%s] mista: attive=%s (Cina Neutrale esclusa)" % ["OK" if s5 else "FAIL", str(m._active_powers())])
	if not s5: fails += 1

	# 6) Validazione: meno di 2 attive non e' avviabile.
	m._on_role("usa", "human")
	m._on_role("eu", "neutral")
	m._on_role("russia", "neutral")
	m._on_role("china", "neutral")
	await process_frame
	var s6: bool = not m._validate() and m._active_powers().size() == 1
	print("[%s] validazione: 1 sola attiva NON avviabile" % ["OK" if s6 else "FAIL"])
	if not s6: fails += 1

	# 7) Online: la griglia ruoli sparisce, compare il setup seggi/lobby; nessun bot.
	m._on_mode("online")
	await process_frame
	GameConfig.automa_powers = m._bot_powers() if m._mode == "local" else []
	var s7: bool = not m._local_setup_box.visible and m._online_setup_box.visible \
		and m._lobby_box.visible and not m._diff_box.visible and GameConfig.automa_powers.is_empty()
	print("[%s] online: griglia nascosta, lobby visibile, nessun bot" % ["OK" if s7 else "FAIL"])
	if not s7: fails += 1

	m.queue_free()
	await process_frame
	GameConfig.automa_powers = []   # cleanup
	print("Verifica menu Locale Umano/Bot/Neutrale: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
