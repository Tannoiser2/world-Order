extends SceneTree
## Bug di rete: _free_increase_pick (Aumento Produzione GRATUITO da una carta: Growth Industrial
## Development/Market Boost Production/China Rapid Industrialization) mutava lo stato DIRETTAMENTE
## in locale invece di passare dal command bus (apply_command) - se il giocatore di turno era un
## CLIENT, il tocco sulla casella evidenziata non arrivava mai all'host (autorità): l'host restava
## fermo e il prossimo snapshot ribroadcast dall'host avrebbe sovrascritto la scelta del client,
## bloccando la partita. Corretto con un nuovo comando "free_increase_pick" nel command bus, come
## _cmd_increase_production & co. Questo test verifica il flusso REALE client -> host -> broadcast.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_free_increase.gd

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

	# Turno della CINA (seggio 1, il CLIENT): gioca una carta con "Aumenta 2 Produzioni".
	host._ui_phase = "Azione"; host.gs.phase = WO.Phase.ACTION
	host.active_seat = 1
	var china = host.gs.players[1]
	china.production["energy"] = 1
	china.production["diplomacy"] = 1
	var card := {"id": "probe", "display_name": "Probe", "effect_ops": [{"op": "increase_production", "count": 2}]}
	china.hand = [card]
	host._plays_left = 1
	host._after_change()
	await process_frame

	var s0: bool = client.active_seat == 1 and (client.gs.players[1].hand as Array).size() == 1
	print("[%s] client sincronizzato: turno Cina, carta in mano" % ["OK" if s0 else "FAIL"])
	if not s0: fails += 1

	client.apply_command(GameCommands.play_card(1, 1, 0))
	await process_frame

	var s1: bool = host._free_increase_remaining == 2 and client._free_increase_remaining == 2
	print("[%s] dopo la carta: Aumento gratuito in corso (2), sincronizzato (host=%d, client=%d)" % [
		"OK" if s1 else "FAIL", host._free_increase_remaining, client._free_increase_remaining])
	if not s1: fails += 1

	# Il CLIENT tocca la casella Energia (STESSA funzione collegata al bottone reale sulla
	# plancia) - deve passare dall'host: se mutasse solo in locale, host.production/
	# host._free_increase_remaining non cambierebbero MAI (il bug prima di questo fix).
	client._free_increase_pick("energy")
	await process_frame

	var s2: bool = int(host.gs.players[1].production.get("energy", 0)) == 2 and host._free_increase_remaining == 1
	print("[%s] l'host (autorità) ha applicato la scelta del client (Energia host=%d, rimanenti=%d)" % [
		"OK" if s2 else "FAIL", int(host.gs.players[1].production.get("energy", 0)), host._free_increase_remaining])
	if not s2: fails += 1

	var s3: bool = int(client.gs.players[1].production.get("energy", 0)) == 2 and client._free_increase_remaining == 1
	print("[%s] il client vede lo stato ribroadcast dall'host (Energia client=%d, rimanenti=%d)" % [
		"OK" if s3 else "FAIL", int(client.gs.players[1].production.get("energy", 0)), client._free_increase_remaining])
	if not s3: fails += 1

	client._free_increase_pick("diplomacy")
	await process_frame

	var s4: bool = int(host.gs.players[1].production.get("diplomacy", 0)) == 2 and host._free_increase_remaining == 0 \
		and host.playing_card.is_empty() and client._free_increase_remaining == 0
	print("[%s] Diplomazia +1 e carta risolta ovunque (host diplomazia=%d, rimanenti=%d)" % [
		"OK" if s4 else "FAIL", int(host.gs.players[1].production.get("diplomacy", 0)), host._free_increase_remaining])
	if not s4: fails += 1

	# L'HOST (USA, non di turno) non può scegliere al posto del CLIENT di turno (Cina):
	# _i_acting() deve bloccarlo, esattamente come per pick_region/pick_influence_cell & co.
	china.hand = [{"id": "probe2", "display_name": "Probe2", "effect_ops": [{"op": "increase_production", "count": 2}]}]
	host._plays_left = 1
	client.apply_command(GameCommands.play_card(1, 2, 0))
	await process_frame
	var before := int(host.gs.players[1].production.get("energy", 0))
	host._free_increase_pick("energy")   # l'host tenta di scegliere al posto del client di turno
	await process_frame
	var s5: bool = int(host.gs.players[1].production.get("energy", 0)) == before and host._free_increase_remaining == 2
	print("[%s] l'host NON può scegliere al posto del client di turno (produzione invariata=%d)" % [
		"OK" if s5 else "FAIL", int(host.gs.players[1].production.get("energy", 0))])
	if not s5: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Aumento Produzione gratuito in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
