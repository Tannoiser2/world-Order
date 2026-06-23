extends SceneTree
## Regressione: ANNULLA della giocata in corso (Move / scelta a popup) in rete.
## Prima «Annulla» chiamava _cancel_card() in LOCALE: il client usciva dalla risoluzione ma
## l'host restava in awaiting e continuava a ribroadcastarlo -> tutto bloccato. Ora passa
## dal command bus: l'host annulla e ribroadcasta, entrambe le finestre escono insieme.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_cancel.gd

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

	# Turno della Cina (client), giocata in corso: spostamento Armate (awaiting "move").
	host.active_seat = 1
	host.awaiting = "move"
	host.playing_card = {"display_name": "Carta in gioco"}
	host._move_ctx = {"free": true, "max": 2, "min": 0, "moved": 0, "source": null, "allowed": [], "exclude": []}
	host._net_sync()
	await process_frame

	var c0: bool = client.awaiting == "move" and not client.playing_card.is_empty()
	print("[%s] setup: il client è nella risoluzione (awaiting=%s)" % ["OK" if c0 else "FAIL", client.awaiting])
	if not c0: fails += 1

	# Il client annulla: deve uscire su ENTRAMBI (host non più in awaiting).
	var sent: bool = client.apply_command(GameCommands.cancel_card(1, 1))
	await process_frame
	var c1: bool = sent and host.awaiting == "" and host.playing_card.is_empty() \
		and client.awaiting == "" and client.playing_card.is_empty()
	print("[%s] «Annulla» dal client esce su ENTRAMBI (host.awaiting='%s', client.awaiting='%s')" % [
		"OK" if c1 else "FAIL", host.awaiting, client.awaiting])
	if not c1: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica annullo giocata in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
