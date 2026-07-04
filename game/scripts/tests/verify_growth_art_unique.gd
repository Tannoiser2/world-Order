extends SceneTree
## Bug: le 10 Growth Card italiane dell'espansione (Cambio di Leadership, Tenore di Vita
## Elevato, Autorità Inconfutabile, Programma Nucleare, Ottimizzazione delle Entrate,
## Affermazione di Predominio, Forza di Reazione Rapida, Collaborazione con gli Alleati,
## Efficienza delle Risorse, Vantaggio Operativo) puntavano alla stessa arte delle Growth
## Card BASE inglesi (es. "Cambio di Leadership" mostrava l'immagine di "Tactical
## Flexibility"): 10 wide_aux_0XX.jpg erano condivisi da 2 carte con nomi/effetti diversi.
## Estratta l'arte propria da "Carte Crescita aggiuntive.pdf" (indici 014-023, univoci).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_art_unique.gd

func _init() -> void:
	var fails := 0
	var cards: Array = DataLoader.load_growth()

	# 1) Ogni file "art" e' usato da UNA SOLA carta (nessun duplicato tra carte diverse).
	var by_art := {}
	for c in cards:
		var art := String(c.get("art", ""))
		if art == "":
			continue
		if not by_art.has(art):
			by_art[art] = []
		(by_art[art] as Array).append(String(c.get("display_name", "")))
	var dup_ok := true
	for art in by_art:
		var names: Array = by_art[art]
		if names.size() > 1:
			dup_ok = false
			print("  duplicato: %s usato da %s" % [art, str(names)])
	print("[%s] Nessuna arte Growth condivisa tra carte diverse" % ["OK" if dup_ok else "FAIL"])
	if not dup_ok: fails += 1

	# 2) Ogni file "art" referenziato esiste davvero sul disco.
	var all_exist := true
	for c in cards:
		var art := String(c.get("art", ""))
		if art != "" and not FileAccess.file_exists("res://assets/cards/%s" % art):
			all_exist = false
			print("  mancante: %s (%s)" % [art, c.get("display_name", "?")])
	print("[%s] Tutte le arte referenziate esistono" % ["OK" if all_exist else "FAIL"])
	if not all_exist: fails += 1

	# 3) Le 10 carte italiane usano specificamente gli indici NUOVI (014-023), non quelli
	#    delle carte base inglesi (000-013).
	var italian := ["Cambio di Leadership", "Tenore di Vita Elevato", "Autorità Inconfutabile",
		"Programma Nucleare", "Ottimizzazione delle Entrate", "Affermazione di Predominio",
		"Forza di Reazione Rapida", "Collaborazione con gli Alleati", "Efficienza delle Risorse",
		"Vantaggio Operativo"]
	var all_new := true
	for c in cards:
		var name := String(c.get("display_name", ""))
		if name in italian:
			var art := String(c.get("art", ""))
			var idx_str := art.replace("wide_aux/wide_aux_", "").replace(".jpg", "")
			if not idx_str.is_valid_int() or int(idx_str) < 14:
				all_new = false
				print("  indice non valido/riciclato per %s: %s" % [name, art])
	print("[%s] Le 10 Growth italiane usano arte propria (indici >= 014)" % ["OK" if all_new else "FAIL"])
	if not all_new: fails += 1

	print("Verifica unicità arte Growth Card: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
