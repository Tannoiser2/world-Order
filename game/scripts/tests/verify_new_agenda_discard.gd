extends SceneTree
## Segnalazione: "quando pesco carte e poi devo scartarne, devo poter SELEZIONARE quali
## scartare" (es. New Agenda: pesca 3, poi puoi scartarne 2 per giocare un'altra carta).
## Verificato che _do_discard chiama GIA' _pick_hand_card (popup) per OGNI carta da scartare
## (interattivo, non automatico/casuale) - ma l'opzione nella scelta a bottoni mostrava il nome
## tecnico grezzo "discard" (mai tradotto in OP_IT), invece di un'etichetta chiara col numero
## di carte ("Scarta 2 carte") - probabile causa della sensazione "non mi ha fatto scegliere".
## Corretto OP_IT + _option_label; questo test conferma anche che il flusso reale (draw ->
## scelta -> N popup di selezione scarto) funzionava e continua a funzionare.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_new_agenda_discard.gd

func _idx(b: Variant, needle: String) -> int:
	for i in b._popup_items.size():
		if needle in String((b._popup_items[i] as Dictionary).get("label", "")):
			return i
	return -1

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
	p.deck = []
	for i in 10:
		p.deck.append({"display_name": "Mazzo %d" % i, "effect_ops": []})
	p.hand = [{"display_name": "Vecchia 1", "effect_ops": []}, {"display_name": "Vecchia 2", "effect_ops": []}]

	# 1) Etichetta leggibile (non il codice grezzo "discard"), col NUMERO di carte da scartare.
	var opts := [
		[{"op": "discard", "n": 2, "then": [{"op": "play_another"}]}],
		[{"op": "noop"}],
	]
	var lbl0: String = b._option_label(opts[0])
	var s1: bool = "discard" not in lbl0 and "Scarta 2 carte" in lbl0
	print("[%s] etichetta leggibile per l'opzione scarto (non il codice grezzo): '%s'" % ["OK" if s1 else "FAIL", lbl0])
	if not s1: fails += 1

	# 2) Flusso REALE: New Agenda pesca 3 (vanno in mano), poi la scelta "Scarta 2 carte" apre
	#    un popup INTERATTIVO per la 1a carta da scartare (tra TUTTE quelle in mano, comprese le
	#    appena pescate), e un altro per la 2a - non uno scarto automatico/casuale.
	var card := {"display_name": "New Agenda",
		"effect_ops": [{"op": "draw", "n": 3}, {"op": "choice", "options": opts}]}
	p.hand.append(card)
	b.playing_card = {}
	b.play_queue = []
	b._plays_left = 1
	b._play_card(card)
	await process_frame

	# "New Agenda" stessa resta un membro dell'array mano finché non e' del tutto risolta
	# (_finish_card la sposta tra le giocate solo alla fine): 2 vecchie + New Agenda + 3 pescate.
	var hand_after_draw: int = p.hand.size()
	var s2: bool = hand_after_draw == 6
	print("[%s] le 3 carte pescate sono DAVVERO in mano (mano=%d, attese 6)" % ["OK" if s2 else "FAIL", hand_after_draw])
	if not s2: fails += 1

	var idx := _idx(b, "Scarta 2 carte")
	var s3: bool = b._popup_active() and idx >= 0
	print("[%s] la scelta mostra 'Scarta 2 carte' come opzione cliccabile (trovata=%s)" % ["OK" if s3 else "FAIL", str(idx >= 0)])
	if not s3: fails += 1

	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx))
	await process_frame
	# Popup INTERATTIVO per scegliere la 1a carta da scartare: 5 candidate (non 6 - "New Agenda"
	# stessa e' esclusa, e' ancora "in gioco", non una carta scartabile).
	var s4: bool = b._popup_active() and b._popup_items.size() == 5
	print("[%s] popup interattivo per scegliere la 1a carta da scartare (%d opzioni, attese 5)" % [
		"OK" if s4 else "FAIL", b._popup_items.size()])
	if not s4: fails += 1

	var target_name := String((b._popup_items[0] as Dictionary).get("label", ""))
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))
	await process_frame
	var discarded_1: bool = not p.hand.any(func(c): return String(c.get("display_name", "")) == target_name)
	# Popup INTERATTIVO ancora per la 2a carta (una in meno da scegliere).
	var s5: bool = discarded_1 and b._popup_active() and b._popup_items.size() == 4
	print("[%s] 1a carta scartata DAVVERO scelta dal giocatore, poi popup per la 2a (%d opzioni, attese 4)" % [
		"OK" if s5 else "FAIL", b._popup_items.size()])
	if not s5: fails += 1

	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))
	await process_frame
	# Dopo 2 scarti: "then" (play_another) da' +1 giocata, la carta e' risolta (rimossa dalla
	# mano da _finish_card): mano = 6 - 2 scartate - 1 (New Agenda finita) = 3.
	var s6: bool = p.hand.size() == 3 and b.playing_card.is_empty()
	print("[%s] dopo 2 scarti scelti: mano=%d (attesa 3), carta risolta" % ["OK" if s6 else "FAIL", p.hand.size()])
	if not s6: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica New Agenda (pesca + scelta scarto interattiva, etichetta leggibile): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
