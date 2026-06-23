extends SceneTree
## DIAGNOSTICA: misura la DIMENSIONE di uno snapshot reale e ne verifica la FEDELTA' dopo
## la serializzazione usata dal trasporto REALE (var_to_bytes per la LAN, Marshalls per il
## relay). Il loopback dei test NON serializza: se uno snapshot e' troppo grande (oltre il
## buffer del WebSocket) o non sopravvive al round-trip, i test passano ma il gioco vero si
## blocca. Questo test rende visibile quel divario.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_snapsize.gd

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
	GameConfig.net = null

	# Snapshot reale come quello inviato in partita.
	var snap: Dictionary = {"gs": host.gs.state_for_seat(1), "ui": host._ui_snapshot()}
	var msg: Dictionary = {"t": "snapshot", "state": snap}

	# 1) Dimensione del pacchetto LAN (var_to_bytes) e del payload relay (base64).
	var bytes: PackedByteArray = var_to_bytes(msg)
	var b64: String = Marshalls.variant_to_base64(msg)
	print("[INFO] snapshot LAN var_to_bytes = %d byte | relay base64 = %d char" % [bytes.size(), b64.length()])
	# board_data da solo (la parte STATICA ripetuta a ogni snapshot).
	var bd_bytes: int = var_to_bytes(host.gs.board_data).size()
	print("[INFO] board_data (statico, ripetuto a ogni snapshot) = %d byte" % bd_bytes)

	# Buffer di default del WebSocketMultiplayerPeer: 65535 byte in/out. Oltre -> pacchetti persi.
	var WS_BUF := 65535
	var d1: bool = bytes.size() <= WS_BUF
	print("[%s] lo snapshot LAN sta nel buffer WebSocket di default (%d <= %d)" % [
		"OK" if d1 else "FAIL", bytes.size(), WS_BUF])
	if not d1: fails += 1

	# 2) Fedelta' del round-trip LAN: il dict ricevuto deve essere identico a quello inviato.
	var back: Variant = bytes_to_var(bytes)
	var d2: bool = (back is Dictionary) and _deep_eq(back, msg)
	print("[%s] round-trip var_to_bytes -> bytes_to_var fedele" % ["OK" if d2 else "FAIL"])
	if not d2: fails += 1

	# 3) Fedelta' del round-trip RELAY (base64/Marshalls).
	var back2: Variant = Marshalls.base64_to_variant(b64)
	var d3: bool = (back2 is Dictionary) and _deep_eq(back2, msg)
	print("[%s] round-trip Marshalls base64 fedele" % ["OK" if d3 else "FAIL"])
	if not d3: fails += 1

	host.queue_free()
	await process_frame

	print("Diagnostica dimensione/fedelta' snapshot: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)


## Uguaglianza profonda (Dictionary/Array/valori) per confronto pre/post serializzazione.
func _deep_eq(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k):
				return false
			if not _deep_eq(a[k], b[k]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _deep_eq(a[i], b[i]):
				return false
		return true
	return a == b
