extends SceneTree
## Regressione: Improve Relations (scelta della Country sul tabellone) in rete. Prima il
## click sulla carta nazione chiamava _on_country_pressed in LOCALE: il client "risolveva"
## da solo (carta sparita localmente, status "risolta") ma l'host no -> lo snapshot tornava
## indietro (carta di nuovo sulla mappa, turno bloccato). Ora passa dal command bus.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_improve.gd

func _ids(arr: Array) -> Array:
	var o := []
	for c in arr:
		o.append(String((c as Dictionary).get("id", "")))
	return o


func _init() -> void:
	var fails := 0

	var host_net := NetSession.new()
	host_net.host_loopback()
	var client_net := NetSession.new()
	NetSession.link_loopback(host_net, client_net)
	get_root().add_child(host_net)
	get_root().add_child(client_net)
	var powers := ["usa", "china"]
	host_net.powers = powers
	client_net.powers = powers

	var board_packed: PackedScene = load("res://scenes/board.tscn")

	GameConfig.net = host_net
	GameConfig.powers = powers
	var host: Variant = board_packed.instantiate()
	get_root().add_child(host)
	await process_frame

	GameConfig.net = client_net
	var client: Variant = board_packed.instantiate()
	get_root().add_child(client)
	await process_frame
	GameConfig.net = null

	# Turno della Cina (client). Niente alleati (nessuno sconto -> risolve subito); diplomazia
	# abbondante. Carta improve "giocata": awaiting board_country.
	host.active_seat = 1
	host.gs.players[1].resources["diplomacy"] = 100
	host.awaiting = "board_country"
	# Regione con una Country scoperta da alleare.
	var rid0 := ""
	for rid in host.region_countries:
		if not (host.region_countries[rid] as Dictionary).get("available", []).is_empty():
			rid0 = rid
			break
	var avail: Array = (host.region_countries.get(rid0, {}) as Dictionary).get("available", [])
	var target_id := String((avail[0] as Dictionary).get("id", ""))
	host._net_sync()
	await process_frame

	# Setup: il client vede awaiting board_country e la Country nella Regione.
	var s0: bool = client.awaiting == "board_country" and target_id in _ids(
		(client.region_countries.get(rid0, {}) as Dictionary).get("available", []))
	print("[%s] setup: client in scelta Country, %s presente in %s" % ["OK" if s0 else "FAIL", target_id, rid0])
	if not s0: fails += 1

	# Il client sceglie la Country: l'host risolve Improve Relations.
	var sent: bool = client.apply_command(GameCommands.pick_board_country(1, 1, rid0, target_id))
	await process_frame

	# 1) La Country sparisce dalla Regione su ENTRAMBI (host autorità, client specchia).
	var host_gone: bool = not (target_id in _ids((host.region_countries.get(rid0, {}) as Dictionary).get("available", [])))
	var client_gone: bool = not (target_id in _ids((client.region_countries.get(rid0, {}) as Dictionary).get("available", [])))
	var r1: bool = sent and host_gone and client_gone
	print("[%s] Country alleata sparisce dalla mappa su entrambi (host=%s, client=%s)" % [
		"OK" if r1 else "FAIL", str(host_gone), str(client_gone)])
	if not r1: fails += 1

	# 2) La risoluzione è COMPLETA (awaiting vuoto): niente blocco, si può chiudere il turno.
	var r2: bool = host.awaiting == "" and client.awaiting == ""
	print("[%s] risoluzione completata, niente blocco (host.awaiting='%s', client.awaiting='%s')" % [
		"OK" if r2 else "FAIL", host.awaiting, client.awaiting])
	if not r2: fails += 1

	# 3) La Cina è ora alleata della Country (è entrata in allied_countries, sincronizzato).
	var allied: bool = target_id in _ids(client.gs.players[1].allied_countries)
	print("[%s] la Country risulta alleata della Cina anche sul client" % ["OK" if allied else "FAIL"])
	if not allied: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Improve Relations in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
