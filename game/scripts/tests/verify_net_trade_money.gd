extends SceneTree
## Commercio in rete tra GIOCATORI: verifica che (1) il money passi davvero dal compratore al
## venditore e (2) la carta prodotto del venditore si GIRI e lo stato sia sincronizzato su tutti
## (prima _commerce_flipped viveva solo nella Vista dell'host -> gli altri non la vedevano girata).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_trade_money.gd

func _init() -> void:
	var fails := 0
	var powers := ["usa", "china", "russia", "eu"]
	var host_net := NetSession.new()
	host_net.host_loopback()
	host_net.powers = powers
	get_root().add_child(host_net)
	var cnets := []
	for i in 3:
		var cn := NetSession.new()
		NetSession.link_loopback(host_net, cn)
		cn.powers = powers
		get_root().add_child(cn)
		cnets.append(cn)

	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = host_net
	GameConfig.powers = powers
	var host: Variant = board_packed.instantiate()
	get_root().add_child(host)
	await process_frame
	var clients := []
	for cn in cnets:
		GameConfig.net = cn
		var c: Variant = board_packed.instantiate()
		get_root().add_child(c)
		await process_frame
		clients.append(c)
	GameConfig.net = null
	var all := [host, clients[0], clients[1], clients[2]]

	# Trova una combinazione VALIDA: compratore B che importa la risorsa R dal venditore S
	# (relazione commerciale che include R) e S vende davvero R (carta prodotto scoperta).
	var buyer := -1; var seller := -1; var res := ""
	for b in 4:
		var td: Dictionary = host._trade_deal(powers[b])
		for s_pow in (td.get("import_from", {}) as Dictionary):
			var s_idx := powers.find(String(s_pow))
			if s_idx < 0 or s_idx == b:
				continue
			for R in (td["import_from"][s_pow] as Array):
				if host._commerce_faceup_for(String(s_pow), String(R)) > 0:
					buyer = b; seller = s_idx; res = String(R); break
			if res != "":
				break
		if res != "":
			break
	if res == "":
		print("[FAIL] nessuna combinazione compratore/venditore/risorsa trovata nei dati")
		quit(1)
		return
	print("[INFO] %s compra %s da %s" % [powers[buyer].to_upper(), res, powers[seller].to_upper()])

	# Prepara il Commercio direttamente sull'host (il compratore importa 1 unita' di R dal venditore).
	var cost: int = int(Actions.IMPORT_COST.get(res, 0))
	host.active_seat = buyer
	host.gs.players[buyer].money = 100
	host.gs.players[seller].money = 0
	host.gs.players[buyer].hand.clear()
	var card := {"display_name": "Carta Commercio", "effect_ops": [{"op": "trade"}], "effect_modifiers": []}
	host.gs.players[buyer].hand.append(card)
	host.playing_card = card
	host.play_queue = []
	host._trade_mode = true
	host._trade_sel = {"export": {}, "import": {res: 1}}
	host._trade_import_src = {res: powers[seller]}
	host._trade_armies = 0
	var flip0: int = (host._commerce_flipped.get(powers[seller], []) as Array).size()

	host._apply_trade()
	await process_frame
	await process_frame

	# 1) Money: il compratore paga, il venditore incassa (per le unita' vendute da lui).
	var buyer_ok: bool = host.gs.players[buyer].money == 100 - cost
	var seller_ok: bool = host.gs.players[seller].money == cost
	var m1: bool = buyer_ok and seller_ok
	print("[%s] money trasferito: %s -%d -> %s +%d (compratore=%d, venditore=%d)" % [
		"OK" if m1 else "FAIL", powers[buyer].to_upper(), cost, powers[seller].to_upper(), cost,
		host.gs.players[buyer].money, host.gs.players[seller].money])
	if not m1: fails += 1

	# 2) Carta prodotto del venditore GIRATA sull'host.
	var flip1: int = (host._commerce_flipped.get(powers[seller], []) as Array).size()
	var m2: bool = flip1 > flip0
	print("[%s] carta prodotto del venditore girata sull'host (%d -> %d)" % ["OK" if m2 else "FAIL", flip0, flip1])
	if not m2: fails += 1

	# 3) Stato carte girate + money SINCRONIZZATI su TUTTI i client.
	var synced := true
	for c in all:
		var cf: int = (c._commerce_flipped.get(powers[seller], []) as Array).size()
		var sm: int = int(c.gs.players[seller].money)
		if cf != flip1 or sm != cost:
			synced = false
	print("[%s] carte girate e money del venditore sincronizzati su tutte le finestre" % ["OK" if synced else "FAIL"])
	if not synced: fails += 1

	host.queue_free()
	for c in clients:
		c.queue_free()
	await process_frame
	print("Verifica Commercio in rete (money + carte prodotto): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
