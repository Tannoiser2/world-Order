extends SceneTree
## Regressione: stato di TABELLONE sincronizzato host<->client (loopback).
## Country card scoperte per Regione e carte Auto-Influence vivono nella Vista (non in gs)
## ed erano mescolate in modo indipendente in ogni istanza: host e client mostravano carte
## DIVERSE, le carte nazione non cambiavano quando l'host le prendeva, e le Auto-Influence
## comparivano in un'istanza e non nell'altra. Ora l'host è autorità e il client specchia.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_board_state.gd

func _ids(arr: Array) -> Array:
	var o := []
	for c in arr:
		o.append(String((c as Dictionary).get("id", "")))
	return o


func _regions_match(host: Variant, client: Variant) -> bool:
	for rid in host.region_countries:
		var ha: Array = (host.region_countries[rid] as Dictionary).get("available", [])
		var ca: Array = (client.region_countries.get(rid, {}) as Dictionary).get("available", [])
		if _ids(ha) != _ids(ca):
			return false
	return true


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

	# Prima del sync: i mescolamenti sono indipendenti -> molto probabilmente DIVERSI.
	var diverged_before: bool = not _regions_match(host, client)

	host._net_sync()
	await process_frame

	# 1) Dopo il sync il client specchia le Country card scoperte dell'host in OGNI Regione.
	var m1: bool = _regions_match(host, client)
	print("[%s] Country card scoperte sincronizzate in tutte le Regioni (divergevano prima=%s)" % [
		"OK" if m1 else "FAIL", str(diverged_before)])
	if not m1: fails += 1

	# 2) Auto-Influence: l'host pesca le 2 carte del round; il client le riceve identiche.
	host._draw_auto_influence()
	host._net_sync()
	await process_frame
	var m2: bool = host._auto_inf_shown.size() == 2 and _ids(client._auto_inf_shown) == _ids(host._auto_inf_shown)
	print("[%s] Auto-Influence sincronizzate (%d carte, ids uguali)" % [
		"OK" if m2 else "FAIL", client._auto_inf_shown.size()])
	if not m2: fails += 1

	# 3) "La carta nazione non cambia quando viene presa": l'host toglie una carta scoperta
	#    da una Regione; il client deve vederla sparire (specchia l'host).
	var rid0 := ""
	for rid in host.region_countries:
		if not (host.region_countries[rid] as Dictionary).get("available", []).is_empty():
			rid0 = rid
			break
	var taken_id := ""
	if rid0 != "":
		var avail: Array = (host.region_countries[rid0] as Dictionary).get("available", [])
		taken_id = String((avail[0] as Dictionary).get("id", ""))
		avail.erase(avail[0])
		host._net_sync()
		await process_frame
	var client_avail: Array = (client.region_countries.get(rid0, {}) as Dictionary).get("available", [])
	var m3: bool = rid0 != "" and not (taken_id in _ids(client_avail)) and _regions_match(host, client)
	print("[%s] carta presa (%s in %s) sparisce anche sul client" % ["OK" if m3 else "FAIL", taken_id, rid0])
	if not m3: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica stato tabellone in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
