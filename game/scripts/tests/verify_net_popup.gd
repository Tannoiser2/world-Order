extends SceneTree
## Regressione: scelte a POPUP (es. "quante Armate", "quanto money") in rete.
## La callback dell'opzione non è serializzabile: la tiene l'host; il client vede prompt +
## etichette (sincronizzati) e rimanda l'INDICE scelto, che l'host esegue chiamando la callback.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_popup.gd

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

	# Turno della Cina (client): durante la risoluzione l'host mostra una scelta a popup.
	host.active_seat = 1
	var got := {"v": -1}
	host._show_popup("Quante Armate?", [
		{"label": "1 Armata", "value": 1},
		{"label": "2 Armate", "value": 2},
		{"label": "3 Armate", "value": 3},
	], func(v): got["v"] = int(v))
	await process_frame

	# 1) Il client VEDE la scelta a popup (prompt + etichette) ricostruita dallo snapshot.
	var p1: bool = client._popup_active() and client._popup_items.size() == 3 \
		and String((client._popup_items[2] as Dictionary).get("label", "")) == "3 Armate"
	print("[%s] client vede il popup (%d opzioni)" % ["OK" if p1 else "FAIL", client._popup_items.size()])
	if not p1: fails += 1

	# 2) Il client sceglie l'opzione 3 (indice 2): l'host esegue la callback col value 3.
	var sent: bool = client.apply_command(GameCommands.popup_choice(1, 1, 2))
	await process_frame
	var p2: bool = sent and int(got["v"]) == 3
	print("[%s] scelta del client eseguita dall'host (callback ricevuto value=%d)" % ["OK" if p2 else "FAIL", int(got["v"])])
	if not p2: fails += 1

	# 3) Il popup si chiude su ENTRAMBI dopo la scelta.
	var p3: bool = host._popup_active() == false and client._popup_active() == false
	print("[%s] popup chiuso su entrambi (host=%s, client=%s)" % [
		"OK" if p3 else "FAIL", str(host._popup_active()), str(client._popup_active())])
	if not p3: fails += 1

	# 4) La BARRA di scelta si SVUOTA sul client dopo la scelta (il bug: restava appesa,
	#    "finita l'azione è rimasta la barra di stato così").
	var p4: bool = client.choice_flow.get_child_count() == 0
	print("[%s] barra di scelta svuotata sul client dopo la scelta (controlli=%d)" % [
		"OK" if p4 else "FAIL", client.choice_flow.get_child_count()])
	if not p4: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica scelte a popup in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
