extends SceneTree
## Verifica headless del NUCLEO DI RETE (NetSession) in LOOPBACK (senza socket):
## protocollo lobby/start + relay comando -> host -> snapshot REDATTO al client.
## Uso: godot --headless --path game --script res://scripts/tests/verify_net.gd

func _init() -> void:
	var fails := {"n": 0}
	var check := func(name: String, cond: bool) -> void:
		print("[%s] %s" % ["OK" if cond else "FAIL", name])
		if not cond:
			fails["n"] += 1

	# Stato di gioco AUTOREVOLE (lato host): mani note per verificare la redazione.
	var gs := GameSetup.new_game(["usa", "china", "russia", "eu"])
	(gs.players[0] as PlayerState).hand = [{"id": "h0a"}, {"id": "h0b"}]            # host, seggio 0
	(gs.players[1] as PlayerState).hand = [{"id": "h1a"}, {"id": "h1b"}, {"id": "h1c"}]  # client, seggio 1

	var host := NetSession.new()
	host.host_loopback()
	var client := NetSession.new()
	NetSession.link_loopback(host, client)
	check.call("client: seggio assegnato = 1", client.my_seat == 1)

	# HOST: alla ricezione di un comando lo applicherebbe (board.apply_command) e poi
	# ribroadcasta lo stato redatto. Nel test ribroadcasta soltanto (relay + redazione).
	host.command_received.connect(func(_seat, _cmd):
		host.broadcast_snapshots(func(s): return gs.state_for_seat(s)))
	var last := {"state": {}}
	client.snapshot_received.connect(func(state): last["state"] = state)

	# START dall'host.
	var started_seat := {"v": -1}
	client.started.connect(func(seat, _pw): started_seat["v"] = seat)
	host.start_game(["usa", "china", "russia", "eu"])
	check.call("client: riceve START con seggio 1", started_seat["v"] == 1)
	check.call("client: potenze ricevute", (client.powers as Array).size() == 4)

	# CLIENT invia un comando -> HOST applica+broadcast -> CLIENT riceve lo snapshot redatto.
	client.send_command(GameCommands.end_turn(1, 1))
	var st: Dictionary = last["state"]
	check.call("client: snapshot ricevuto", not st.is_empty())
	check.call("snapshot redatto per il MIO seggio (viewer=1)", int(st.get("viewer_seat", -1)) == 1)
	var p0: Dictionary = st["players"][0]
	var p1: Dictionary = st["players"][1]
	check.call("la MIA mano (seggio 1) e' visibile (3)", (p1["hand"] as Array).size() == 3)
	check.call("la mano avversaria (host) e' COPERTA ma contata (2)",
		(p0["hand"] as Array).is_empty() and int(p0.get("hand_count", -1)) == 2)

	print("Verifica rete (loopback): %s" % ("OK" if fails["n"] == 0 else "FALLITA (%d)" % fails["n"]))
	host.free()
	client.free()
	quit()
