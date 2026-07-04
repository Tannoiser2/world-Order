extends SceneTree
## Segnalazione: "Strengthen Alliance permette di costruire una Base in una Country con già una
## Base, ma non me lo fa fare" — confermato. La carta ha nei dati il modifier
## "base_repeat_once" (data/market_cards.json), ma NESSUNA parte del motore lo leggeva mai
## (Modifiers.gd lo marcava soltanto, cfr. commento "gli altri [modifier]... restano marcati
## nei dati"): la carta si comportava come un Build a Base NORMALE e falliva sempre sulla
## Country già usata (blocco "1 sola Base per Country", regolamento pag. 15).
## Corretto: _eligible_allied("build_base") e Actions.execute_build_base ora rispettano il
## modifier "base_repeat_once" (permette un 2° ingresso nella STESSA Country, mai un 3°).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_strengthen_alliance.gd

func _find_button(node: Node, text: String) -> Button:
	if node is Button and text in String((node as Button).text):
		return node
	for c in node.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null


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
	p.money = 200
	p.armies_available = 6
	var c := {"id": "sa_test_country", "display_name": "Test Ally", "region": "africa",
		"value": 2, "has_base_symbol": true, "base_allowed_powers": [p.power]}
	p.allied_countries.append(c)
	p.exhausted["sa_test_country"] = false
	p.bases = ["sa_test_country"]   # ha GIA' una Base li'

	# 1) Dati carta: la carta reale ha il modifier "base_repeat_once" (non un op generico e basta).
	var market: Array = DataLoader.load_market()
	var card: Dictionary = {}
	for m in market:
		if String(m.get("id", "")) == "mk_strengthen_alliance":
			card = m
	var s1: bool = not card.is_empty() and "base_repeat_once" in (card.get("effect_modifiers", []) as Array)
	print("[%s] Strengthen Alliance ha il modifier 'base_repeat_once' nei dati" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	# 2) SENZA il modifier (Build a Base NORMALE): la Country con già una Base non è tra le
	#    idonee (prima non veniva filtrata affatto: si poteva scegliere e falliva zitta zitta).
	b.active_mods = {}
	var elig_normal: Array = b._eligible_allied("build_base")
	var s2: bool = elig_normal.filter(func(x): return String(x.get("id", "")) == "sa_test_country").is_empty()
	print("[%s] Build a Base NORMALE: Country con già una Base esclusa dagli idonei" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# 3) Giocando DAVVERO la carta (via _play_card, non a mano): active_mods si imposta e la
	#    Country con già una Base ORA è tra le idonee (si può scegliere).
	p.hand.append(card)
	b.playing_card = {}
	b.play_queue = []
	b.awaiting = ""
	b._plays_left = 1
	b._play_card(card)
	var s3: bool = b.active_mods.has("base_repeat_once") and b.awaiting == "allied_country"
	print("[%s] Giocata la carta: modifier attivo, in attesa di una Country alleata (awaiting=%s)" % [
		"OK" if s3 else "FAIL", b.awaiting])
	if not s3: fails += 1

	var elig_repeat: Array = b._eligible_allied("build_base")
	var s4: bool = not elig_repeat.filter(func(x): return String(x.get("id", "")) == "sa_test_country").is_empty()
	print("[%s] Con la carta giocata: la Country con già una Base ORA è tra gli idonei" % ["OK" if s4 else "FAIL"])
	if not s4: fails += 1

	# 4) Tocco DAVVERO la Country (percorso reale _on_allied_pressed), scelgo lo slot sulla mappa
	#    e le Armate nel popup: la Base si costruisce per DAVVERO una 2a volta.
	b._on_allied_pressed(c)
	b._on_influence_cell("africa", "temporary")   # scelta slot SULLA MAPPA (no-op se già risolta)
	var n1_btn: Button = _find_button(b, "1 Armata/e")
	if n1_btn: n1_btn.pressed.emit()
	await process_frame
	var s5: bool = p.bases.count("sa_test_country") == 2 and (card in p.played)
	print("[%s] Base rinforzata per DAVVERO nella stessa Country (bases=%d, atteso 2)" % [
		"OK" if s5 else "FAIL", p.bases.count("sa_test_country")])
	if not s5: fails += 1

	# 5) Anche con la carta rigiocata (modifier ancora attivo), una 3a Base nella STESSA Country
	#    resta impossibile ("ma solo una volta" - rinforza, non rende la Country illimitata).
	b.active_mods = {"base_repeat_once": true}
	var elig_third: Array = b._eligible_allied("build_base")
	var s6: bool = elig_third.filter(func(x): return String(x.get("id", "")) == "sa_test_country").is_empty()
	print("[%s] Una 3a Base nella stessa Country resta esclusa (limite 'solo una volta')" % ["OK" if s6 else "FAIL"])
	if not s6: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Strengthen Alliance (Build a Base ripetuta): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
