extends SceneTree
## Riproduce il BLOCCO visto dal vivo (host risolve, client fermo un passo indietro) e verifica
## che l'HEARTBEAT lo recuperi. Gli snapshot sono inviati una volta sola: se il client ne PERDE
## uno resta bloccato per sempre. L'host ribroadcasta a intervalli; il client deduplica per hash
## (stato identico = nessun ridisegno) ma quando era rimasto indietro si riallinea e si sblocca.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_heartbeat.gd

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

	# Turno della Cina (client). Carta Improve Relations in mano, diplomazia alta.
	host.active_seat = 1
	host._plays_left = 1
	host._played_this_turn = false
	host.gs.players[1].resources["diplomacy"] = 100
	host.gs.players[1].hand.clear()
	host.gs.players[1].hand.append({"display_name": "Test Improve", "effect_ops": [{"op": "improve_relations"}], "effect_modifiers": []})
	host._net_sync()
	await process_frame

	# Il client gioca la carta: l'host attende la Country, il client vede board_country.
	client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame
	var s0: bool = host.awaiting == "board_country" and client.awaiting == "board_country"
	print("[%s] preludio: entrambi in attesa della Country" % ["OK" if s0 else "FAIL"])
	if not s0: fails += 1

	# Country target dal tabellone.
	var rid0 := ""
	for rid in host.region_countries:
		if not (host.region_countries[rid] as Dictionary).get("available", []).is_empty():
			rid0 = rid
			break
	var target_id := String(((host.region_countries.get(rid0, {}) as Dictionary).get("available", [])[0] as Dictionary).get("id", ""))

	# SIMULA LO SNAPSHOT PERSO solo nella direzione host->client: tolgo il client dalla lista di
	# consegna del broadcast. I comandi client->host (e la loro attribuzione per connessione)
	# restano integri - come nella realta', dove perdere uno snapshot non cambia il mittente.
	host_net._loop_clients.erase(client_net)

	# Il client sceglie la Country: il comando ARRIVA all'host, che risolve... ma lo snapshot
	# di ritorno si PERDE. Esattamente lo screenshot: host avanti, client fermo.
	client.apply_command(GameCommands.pick_board_country(1, 2, rid0, target_id))
	await process_frame

	var host_done: bool = host.playing_card.is_empty() and host.awaiting == "" and (host._played_this_turn or host._plays_left <= 0)
	var client_stuck: bool = client.awaiting == "board_country" and not client.playing_card.is_empty()
	var s1: bool = host_done and client_stuck
	print("[%s] BLOCCO riprodotto: host risolto (aw='%s' play=%s), client fermo (aw='%s' play=%s)" % [
		"OK" if s1 else "FAIL", host.awaiting, str(not host.playing_card.is_empty()),
		client.awaiting, str(not client.playing_card.is_empty())])
	if not s1: fails += 1

	# RIPRISTINO la consegna e batto il HEARTBEAT: l'host ribroadcasta lo stato corrente.
	host_net._loop_clients.append(client_net)
	host._net_sync()
	await process_frame

	# Il client si e' RIALLINEATO: niente carta in gioco, niente attesa, Country sparita.
	var gone: bool = not (target_id in _ids((client.region_countries.get(rid0, {}) as Dictionary).get("available", [])))
	var client_ok: bool = client.playing_card.is_empty() and client.awaiting == "" and gone
	print("[%s] heartbeat: il client si riallinea e si SBLOCCA (aw='%s' play=%s, Country via=%s)" % [
		"OK" if client_ok else "FAIL", client.awaiting, str(not client.playing_card.is_empty()), str(gone)])
	if not client_ok: fails += 1

	# DEDUP: un secondo battito con stato IDENTICO non deve riapplicare nulla (anti-sfarfallio).
	var sig_before: int = client._last_snapshot_sig
	host._net_sync()
	await process_frame
	var s3: bool = client._last_snapshot_sig == sig_before and sig_before != 0
	print("[%s] dedup: battito con stato identico ignorato (sig stabile=%d)" % ["OK" if s3 else "FAIL", sig_before])
	if not s3: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica heartbeat di recupero in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
