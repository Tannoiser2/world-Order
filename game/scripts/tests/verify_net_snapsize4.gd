extends SceneTree
## DIAGNOSTICA 4 giocatori: misura quanto pesano gli snapshot inviati IN UN COLPO a 3 client.
## Se la somma supera il buffer del WebSocket (default 65535 byte), i pacchetti oltre il primo
## vengono SCARTATI: il primo client si sincronizza, gli altri (Russia/Europa) no. Conferma il
## bug dal vivo e giustifica l'aumento dei buffer.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_snapsize4.gd

func _init() -> void:
	var powers := ["usa", "china", "russia", "eu"]
	var host_net := NetSession.new()
	host_net.host_loopback()
	host_net.powers = powers
	get_root().add_child(host_net)
	for i in 3:
		var cn := NetSession.new()
		NetSession.link_loopback(host_net, cn)
		get_root().add_child(cn)

	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = host_net
	GameConfig.powers = powers
	var host: Variant = board_packed.instantiate()
	get_root().add_child(host)
	await process_frame
	GameConfig.net = null

	var WS_DEF := 65535
	var total_b64 := 0
	var total_bin := 0
	for seat in [1, 2, 3]:
		var snap: Dictionary = {"gs": host.gs.state_for_seat(seat), "ui": host._ui_snapshot()}
		var msg: Dictionary = {"t": "snapshot", "state": snap}
		var bin := var_to_bytes(msg).size()
		var b64 := Marshalls.variant_to_base64(msg).length()
		total_bin += bin
		total_b64 += b64
		print("[INFO] snapshot seggio %d: %d byte (LAN) | %d char (relay base64)" % [seat, bin, b64])
	print("[INFO] TOTALE inviato in un frame a 3 client: %d byte LAN | %d char relay" % [total_bin, total_b64])
	print("[%s] il totale a 3 client SUPERA il buffer default %d (LAN=%s, relay=%s) -> serve buffer piu' grande" % [
		"CONFERMATO" if (total_bin > WS_DEF or total_b64 > WS_DEF) else "no",
		WS_DEF, str(total_bin > WS_DEF), str(total_b64 > WS_DEF)])

	host.queue_free()
	await process_frame
	quit(0)
