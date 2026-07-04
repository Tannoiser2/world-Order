extends SceneTree
## Bug: comprando la Growth "Industrial Development" ("Aumenta di 1 due delle tue Produzioni")
## non veniva mai offerta la scelta delle 2 Produzioni: _buy_growth_action non accodava mai
## l'effect_ops della Growth card (solo "Vantaggio Operativo" era gestito, con un caso apposito).
## In piu' l'op "increase_production" interpretava `count` come AMMONTARE su UNA risorsa,
## invece che "N risorse DISTINTE, ognuna +1" (bug visibile solo con count>1).
##
## Segnalazione successiva: l'aumento gratuito da una carta usava un elenco di bottoni nella
## barra scelte, disomogeneo rispetto al passo Aumento Produzione del Focus (che evidenzia le
## caselle sulla plancia). Unificato: ora anche questo usa _add_increase_overlays/
## _free_increase_pick - questo test verifica il flusso reale con quella stessa interfaccia.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_industrial_dev.gd

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
	p.money = 500
	p.resources = {"energy": 10, "raw_materials": 10, "food": 10, "consumer_goods": 10, "services": 10, "diplomacy": 10, "armies": 10}
	var e0 := int(p.production.get("energy", 0))
	var d0 := int(p.production.get("diplomacy", 0))
	var card := {"id": "probe", "display_name": "Growth Strategy Probe",
		"effect_ops": [{"op": "choice", "options": [[{"op": "get_growth"}], [{"op": "produce", "count": 3}]]}]}
	p.hand = [card]
	b._plays_left = 1
	b._play_card(card)
	await process_frame
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))   # "Carta Crescita"
	await process_frame

	var s1: bool = not b._growth_pick.is_empty()
	print("[%s] Get a Growth Card: selettore aperto" % ["OK" if s1 else "FAIL"])
	if not s1: fails += 1

	var target := {}
	for c in b._available_growth(p):
		if String(c.get("id", "")) == "growth_industrial_development":
			target = c
	var s2: bool = not target.is_empty()
	print("[%s] Industrial Development disponibile e abbordabile" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	b.apply_command(GameCommands.buy_growth(0, b._next_seq(), String(target.get("id", ""))))
	await process_frame

	# Ora deve aprirsi l'Aumento Produzione GRATUITO (2 distinte) - STESSA interfaccia del Focus:
	# niente più popup/bottoni, le caselle si evidenziano sulla plancia (_add_increase_overlays).
	var s3: bool = b._free_increase_remaining == 2 and b._free_increase_done.is_empty()
	print("[%s] Dopo l'acquisto: Aumento Produzione gratuito in corso (2 da scegliere, %d rimanenti)" % [
		"OK" if s3 else "FAIL", b._free_increase_remaining])
	if not s3: fails += 1

	# Verifica DAL VERO rendering: la plancia mostra le caselle evidenziate per TUTTE e 7 le
	# risorse (nessuna ancora scelta), col tooltip giusto (gratis, niente costo in money).
	var view: Control = b._build_plancia_view(p, true)
	get_root().add_child(view)
	await process_frame
	var energy_btn: Button = _find_button_tooltip(view, "Energia")
	var s3b: bool = energy_btn != null and "money" not in String(energy_btn.tooltip_text)
	print("[%s] la plancia evidenzia la casella Energia (gratis, tooltip='%s')" % [
		"OK" if s3b else "FAIL", String(energy_btn.tooltip_text) if energy_btn else "?"])
	if not s3b: fails += 1
	view.queue_free()

	# Tocco DAVVERO la casella Energia (chiamando la stessa funzione collegata al bottone reale).
	b._free_increase_pick("energy")
	await process_frame
	var s4: bool = int(p.production.get("energy", 0)) == e0 + 1 and b._free_increase_remaining == 1 \
		and ("energy" in b._free_increase_done)
	print("[%s] Energia +1 (%d->%d) e resta 1 Produzione DIVERSA da scegliere" % [
		"OK" if s4 else "FAIL", e0, int(p.production.get("energy", 0))])
	if not s4: fails += 1

	# Energia non deve più essere fra le caselle evidenziate (già scelta) - controllo dal vero
	# rendering, non solo dall'array _free_increase_done.
	var view2: Control = b._build_plancia_view(p, true)
	get_root().add_child(view2)
	await process_frame
	var has_energy_again: bool = _find_button_tooltip(view2, "Energia") != null
	print("[%s] Energia NON più evidenziata come 2a scelta (regolamento: 2 risorse diverse)" % ["OK" if not has_energy_again else "FAIL"])
	if has_energy_again: fails += 1
	view2.queue_free()

	# Provare a ri-scegliere Energia direttamente (bypassando la UI) non ha effetto: e' gia' nei
	# tipi fatti - autorità: non basta togliere il bottone dal rendering, il motore deve rifiutarla.
	var e_after_first := int(p.production.get("energy", 0))
	b._free_increase_pick("energy")
	var s4b: bool = int(p.production.get("energy", 0)) == e_after_first and b._free_increase_remaining == 1
	print("[%s] Il motore rifiuta di riscegliere Energia (produzione invariata=%d)" % ["OK" if s4b else "FAIL", int(p.production.get("energy", 0))])
	if not s4b: fails += 1

	b._free_increase_pick("diplomacy")
	await process_frame

	var s5: bool = int(p.production.get("diplomacy", 0)) == d0 + 1
	print("[%s] Diplomazia +1 (%d->%d)" % ["OK" if s5 else "FAIL", d0, int(p.production.get("diplomacy", 0))])
	if not s5: fails += 1

	var s6: bool = b.playing_card.is_empty() and b._plays_left == 0 and p.growth_cards.size() == 1 \
		and b._free_increase_remaining == 0
	print("[%s] Carta risolta e conclusa (playing_card vuota, plays_left=%d, growth_cards=%d, aumento concluso)" % [
		"OK" if s6 else "FAIL", b._plays_left, p.growth_cards.size()])
	if not s6: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica fix Growth Industrial Development: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)


func _find_button_tooltip(node: Node, needle: String) -> Button:
	if node is Button and needle in String((node as Button).tooltip_text):
		return node
	for c in node.get_children():
		var f := _find_button_tooltip(c, needle)
		if f != null:
			return f
	return null
