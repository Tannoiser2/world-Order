extends SceneTree
## Regressione: fase RESEARCH di fine round in rete (host <-> client via loopback).
## La Research è per-giocatore (in ordine di turno): il client deve VEDERE il pannello
## Market (ricostruito dallo stato sincronizzato) e poter Comprare/Cambiare/«Continua»
## tramite il command bus (prima i pulsanti chiamavano funzioni locali -> il client
## avanzava da solo o si bloccava). L'attribuzione resta corretta (agisce solo il suo turno).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_research.gd

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

	# Ordine Research: prima China (client, seggio 1), poi USA (host, seggio 0).
	host.gs.turn_order.assign([1, 0])
	host._begin_research()
	await process_frame

	# 1) Il client RICOSTRUISCE il pannello Research (prima non lo vedeva) sul proprio turno.
	var r0: bool = client._ui_phase == "Research" and client.active_seat == 1 \
		and client.market_content != null and client.market_content.get_child_count() > 0
	print("[%s] client vede il pannello Research sul proprio turno (controlli=%d, seggio=%d)" % [
		"OK" if r0 else "FAIL", client.market_content.get_child_count() if client.market_content != null else -1, client.active_seat])
	if not r0: fails += 1

	# 2) Il Market scoperto è sincronizzato (il client non usa il proprio mazzo locale).
	var r1: bool = client.market_display.size() == host.market_display.size()
	print("[%s] Market sincronizzato host<->client (%d carte)" % ["OK" if r1 else "FAIL", client.market_display.size()])
	if not r1: fails += 1

	# 3) Il client chiude il PROPRIO passo Research: comando accettato (avanza al giocatore dopo).
	var sent_ok: bool = client.apply_command(GameCommands.research_continue(1, 1))
	await process_frame
	var r2: bool = sent_ok and host._research_idx == 1 and host.active_seat == 0 and client.active_seat == 0
	print("[%s] client «Continua» Research: accettato (idx host=%d, active host=%d, client=%d)" % [
		"OK" if r2 else "FAIL", host._research_idx, host.active_seat, client.active_seat])
	if not r2: fails += 1

	# 4) Attribuzione: ora è il Research di USA; il client (china) non può avanzarlo.
	var sent_wrong: bool = client.apply_command(GameCommands.research_continue(0, 2))
	await process_frame
	var r3: bool = (not sent_wrong) and host._research_idx == 1
	print("[%s] client non avanza il Research altrui (inviato=%s, idx host=%d)" % [
		"OK" if r3 else "FAIL", str(sent_wrong), host._research_idx])
	if not r3: fails += 1

	# 5) Difesa lato host: un comando spacciato per USA ma dal client (seggio 1) viene scartato.
	host._on_net_command(1, GameCommands.research_continue(0, 3))
	await process_frame
	var r4: bool = host._research_idx == 1
	print("[%s] host scarta il «Continua» Research spacciato per USA (idx host=%d)" % [
		"OK" if r4 else "FAIL", host._research_idx])
	if not r4: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica Research in rete: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
