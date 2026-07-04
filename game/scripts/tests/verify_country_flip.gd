extends SceneTree
## Effetto "giro" delle carte Nazione tra Pronta <-> Esaurita:
##  - aspetto Esaurita più marcato (grigio scuro, non solo un leggero modulate);
##  - il giro (flip) si anima SOLO alla transizione vera (non a ogni refresh se lo stato
##    resta invariato) grazie a _exhausted_seen.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_country_flip.gd

func _init() -> void:
	var fails := 0
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	var card := Control.new()
	get_root().add_child(card)
	var sz := Vector2(80, 112)

	# 1) Primo render mai visto (cid nuovo): applica direttamente, NESSUNA animazione.
	b._apply_exhausted(card, sz, "cid1", false)
	var s1: bool = card.modulate.is_equal_approx(Color(1, 1, 1)) and card.rotation_degrees == 0.0 \
		and bool(b._exhausted_seen.get("cid1", true)) == false
	print("[%s] Primo render (Pronta, mai vista prima): nessuna animazione, aspetto normale" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) Stesso stato (Pronta di nuovo): nessuna transizione, applicazione diretta.
	b._apply_exhausted(card, sz, "cid1", false)
	var s2: bool = card.modulate.is_equal_approx(Color(1, 1, 1))
	print("[%s] Stato invariato (Pronta->Pronta): applicazione diretta, niente giro" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# 3) Transizione Pronta -> Esaurita: subito dopo la chiamata l'aspetto e' ANCORA quello
	#    VECCHIO (il giro e' appena partito, non ancora a metà corsa) - e' cosi' che si vede
	#    l'animazione invece di uno scatto istantaneo. Lo stato tracciato pero' e' gia' aggiornato.
	b._apply_exhausted(card, sz, "cid1", true)
	var mid_ok: bool = card.modulate.is_equal_approx(Color(1, 1, 1))   # ancora l'aspetto vecchio
	var tracked_ok: bool = bool(b._exhausted_seen.get("cid1", false)) == true
	print("[%s] Transizione Pronta->Esaurita: appena iniziata mostra ancora il vecchio aspetto (giro in corso)" % ["OK" if mid_ok else "FAIL"])
	if not mid_ok: fails += 1
	print("[%s] _exhausted_seen aggiornato subito a Esaurita" % ["OK" if tracked_ok else "FAIL"])
	if not tracked_ok: fails += 1

	# Aspetta che il tween del giro finisca (~0.24s) e verifica l'aspetto FINALE marcato.
	await create_timer(0.4).timeout
	var s3: bool = card.modulate.is_equal_approx(Color(0.32, 0.32, 0.36)) and card.rotation_degrees == 8.0
	print("[%s] A giro concluso: grigio marcato (0.32,0.32,0.36) e ruotata 8°" % ["OK" if s3 else "FAIL"])
	if not s3: fails += 1
	# Ben distinguibile dal vecchio grigio chiaro (0.55,0.55,0.6) usato prima del fix.
	var s3b: bool = card.modulate.r < 0.45
	print("[%s] Grigio più scuro del precedente (0.55) -> più distinguibile dalle carte pronte" % ["OK" if s3b else "FAIL"])
	if not s3b: fails += 1

	# 4) Stesso stato (Esaurita di nuovo): applicazione diretta, niente nuova animazione.
	card.modulate = Color(0.32, 0.32, 0.36)   # marca lo stato "finale" per rilevare se viene toccato
	b._apply_exhausted(card, sz, "cid1", true)
	var s4: bool = card.modulate.is_equal_approx(Color(0.32, 0.32, 0.36))
	print("[%s] Stato invariato (Esaurita->Esaurita): applicazione diretta" % ["OK" if s4 else "FAIL"])
	if not s4: fails += 1

	# 5) Transizione Esaurita -> Pronta (riattivata): anima il giro all'indietro.
	b._apply_exhausted(card, sz, "cid1", false)
	await create_timer(0.4).timeout
	var s5: bool = card.modulate.is_equal_approx(Color(1, 1, 1)) and card.rotation_degrees == 0.0
	print("[%s] Transizione Esaurita->Pronta: torna all'aspetto normale (giro all'indietro)" % ["OK" if s5 else "FAIL"])
	if not s5: fails += 1

	card.queue_free()
	b.queue_free()
	await process_frame
	print("Verifica giro/aspetto carte Nazione esaurite: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
