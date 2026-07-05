extends SceneTree
## Verifica di rete per l'ottimizzazione UI "meno popup, più interattività": Aiuti Economici e
## Militari/Collaborazione (scelta Nazione Alleata da esaurire, riusando l'infrastruttura di
## Invest/Build a Base: awaiting=="allied_country") e Vantaggio Operativo (attivazione gratuita
## di un Asset Strategico toccando la carta già in mano) passano ora dal command bus invece che
## da un popup - qui si verifica che funzionino DAVVERO col flusso client -> host -> broadcast
## (stesso audit già fatto per free_increase_pick).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_allied_reuse.gd

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

	# Turno della CINA (seggio 1, il CLIENT): Aiuti Economici e Militari (2 Nazioni Alleate).
	host._ui_phase = "Azione"; host.gs.phase = WO.Phase.ACTION
	host.active_seat = 1
	var china = host.gs.players[1]
	china.money = 50
	china.armies_available = 2
	china.resources["diplomacy"] = 0
	china.allied_countries = [
		{"id": "a1", "display_name": "Alfa", "region": "americas"},
		{"id": "a2", "display_name": "Beta", "region": "africa"},
	]
	china.exhausted = {}
	host._op_aid_econ_military({})
	await process_frame

	var s1: bool = host.awaiting == "allied_country" and String(host.awaiting_op.get("op", "")) == "aid_first" \
		and client.awaiting == "allied_country" and String(client.awaiting_op.get("op", "")) == "aid_first"
	print("[%s] client sincronizzato: in attesa della 1a Nazione Alleata (host=%s, client=%s)" % [
		"OK" if s1 else "FAIL", host.awaiting_op, client.awaiting_op])
	if not s1: fails += 1

	# Il CLIENT tocca la 1a Nazione Alleata (Alfa) - deve passare dall'host.
	client.apply_command(GameCommands.pick_allied_country(1, 1, "a1"))
	await process_frame
	var s2: bool = String(host.awaiting_op.get("op", "")) == "aid_second" \
		and String(host.awaiting_op.get("exclude_region", "")) == "americas" \
		and String(client.awaiting_op.get("op", "")) == "aid_second"
	print("[%s] l'host ha applicato la scelta del client: ora attende la 2a (Regione diversa da americas)" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	client.apply_command(GameCommands.pick_allied_country(1, 2, "a2"))
	await process_frame
	var s3: bool = int(china.resources["diplomacy"]) == 2 and china.armies_available == 0 \
		and bool(china.exhausted.get("a1", false)) and bool(china.exhausted.get("a2", false))
	print("[%s] Aiuti Econ. risolto ovunque (+2 Diplomazia=%d, Armate=%d, entrambe esaurite)" % [
		"OK" if s3 else "FAIL", int(china.resources["diplomacy"]), china.armies_available])
	if not s3: fails += 1

	# Chiudo lo slot Influenza rimasto in sospeso (2 Regioni), per liberare il turno.
	client.apply_command(GameCommands.pick_influence_cell(1, 3, "americas", "permanent"))
	await process_frame
	client.apply_command(GameCommands.pick_influence_cell(1, 4, "africa", "permanent"))
	await process_frame

	# Vantaggio Operativo (stesso giocatore, Cina): attivazione gratuita di un Asset via comando.
	china.strategic_assets = [{"id": "sa_demo", "display_name": "Demo", "effect_ops": [{"op": "gain_money", "amount": 20}]}]
	china.used_strategic_assets = []
	china.money = 0
	host.playing_card = {"display_name": "innesco", "effect_ops": []}
	host.play_queue = []
	host._plays_left = 1
	host._operational_activate(china)
	await process_frame
	var s4: bool = host._free_activate_asset and client._free_activate_asset
	print("[%s] client sincronizzato: Vantaggio Operativo in attesa dell'attivazione (host=%s, client=%s)" % [
		"OK" if s4 else "FAIL", str(host._free_activate_asset), str(client._free_activate_asset)])
	if not s4: fails += 1

	client.apply_command(GameCommands.activate_free_asset(1, 5, "sa_demo"))
	await process_frame
	var s5: bool = china.money == 20 and china.strategic_assets.is_empty() \
		and not host._free_activate_asset and not client._free_activate_asset and host.playing_card.is_empty()
	print("[%s] l'host ha applicato l'attivazione del client (money=%d, Asset usato, carta risolta)" % ["OK" if s5 else "FAIL", china.money])
	if not s5: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica riuso interattivo (Aiuti/Collaborazione + Vantaggio Operativo) in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
