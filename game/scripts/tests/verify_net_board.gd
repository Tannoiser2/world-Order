extends SceneTree
## Verifica di INTEGRAZIONE della rete a livello di BOARD (host <-> client via loopback):
## - l'host applica/sincronizza lo stato e il client riceve lo snapshot REDATTO e
##   ricostruisce il proprio GameState (vede money di tutti, ma NON la mano avversaria);
## - un comando inviato dal client raggiunge l'host (command_received -> _on_net_command).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_board.gd

func _init() -> void:
	var fails := 0

	# --- Sessioni loopback: host (seggio 0) + client (seggio 1) ---
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

	# --- Board HOST (gioca la Preparazione, possiede lo stato) ---
	GameConfig.net = host_net
	GameConfig.powers = powers
	var host_board: Variant = board_packed.instantiate()
	get_root().add_child(host_board)
	await process_frame

	# --- Board CLIENT (attende l'host, non gioca la Preparazione) ---
	GameConfig.net = client_net
	var client_board: Variant = board_packed.instantiate()
	get_root().add_child(client_board)
	await process_frame
	GameConfig.net = null   # ripristina lo stato globale per gli altri test

	# 1) Il client all'avvio NON ha eseguito la Preparazione locale: è in attesa.
	var waiting_ok: bool = client_board.net != null and client_board.net.is_client()
	print("[%s] client: sessione client e in attesa dell'host" % ["OK" if waiting_ok else "FAIL"])
	if not waiting_ok: fails += 1

	# 2) HOST -> CLIENT: l'host modifica lo stato e sincronizza; il client lo riceve.
	host_board.gs.players[0].money = 4242   # usa (host / seggio 0)
	host_board.gs.players[1].money = 777     # china (client / seggio 1)
	host_board._net_sync()                    # loopback: consegna sincrona
	await process_frame

	var m0: int = int(client_board.gs.players[0].money)
	var m1: int = int(client_board.gs.players[1].money)
	var money_ok: bool = m0 == 4242 and m1 == 777
	print("[%s] client riceve lo snapshot: money host=%d, mio=%d" % ["OK" if money_ok else "FAIL", m0, m1])
	if not money_ok: fails += 1

	# 3) REDAZIONE: la mano dell'avversario (host, seggio 0) è COPERTA per il client,
	#    mentre la PROPRIA mano (seggio 1) resta visibile.
	var opp_hidden: bool = (client_board.gs.players[0].hand as Array).is_empty()
	var mine_visible: bool = (client_board.gs.players[1].hand as Array).size() == (host_board.gs.players[1].hand as Array).size()
	print("[%s] redazione: mano host coperta, mia mano visibile (%d)" % [
		"OK" if (opp_hidden and mine_visible) else "FAIL", (client_board.gs.players[1].hand as Array).size()])
	if not (opp_hidden and mine_visible): fails += 1

	# 4) CLIENT -> HOST: un comando del client raggiunge l'host (command_received).
	var got := {"seat": -1, "type": ""}
	host_net.command_received.connect(func(seat: int, cmd: Dictionary):
		got["seat"] = seat
		got["type"] = String(cmd.get("type", "")))
	client_board.apply_command(GameCommands.end_turn(1, 0))
	await process_frame
	var cmd_ok: bool = int(got["seat"]) == 1 and String(got["type"]) == "end_turn"
	print("[%s] comando del client ricevuto dall'host (seat=%s, type=%s)" % [
		"OK" if cmd_ok else "FAIL", str(got["seat"]), str(got["type"])])
	if not cmd_ok: fails += 1

	# 5) PAYLOAD end-to-end: il client invia un Move, l'host lo applica e ribroadcasta;
	#    il risultato compare nello stato dell'host E nello snapshot ricevuto dal client.
	host_board.active_seat = 1            # tocca al client (seggio 1 = china)
	host_board.awaiting = "move"
	host_board._move_ctx = {"free": true, "max": 2, "min": 0, "moved": 0, "source": null, "allowed": [], "exclude": []}
	host_board.gs.players[1].armies_available = 2
	host_board.gs.regions["europe"]["armies"]["china"] = 0
	client_board.apply_command(GameCommands.move_army(1, 99, "_reserve", "europe"))
	await process_frame
	var host_moved: bool = int(host_board.gs.regions["europe"]["armies"].get("china", 0)) == 1 \
		and int(host_board.gs.players[1].armies_available) == 1
	print("[%s] host applica il Move del client (riserva 2->1, Europa china=1)" % ["OK" if host_moved else "FAIL"])
	if not host_moved: fails += 1
	var client_sees: bool = int(client_board.gs.regions["europe"]["armies"].get("china", 0)) == 1
	print("[%s] il client vede il Move nello snapshot ribroadcastato" % ["OK" if client_sees else "FAIL"])
	if not client_sees: fails += 1

	host_board.queue_free()
	client_board.queue_free()
	await process_frame

	print("Verifica rete (board host<->client): %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
