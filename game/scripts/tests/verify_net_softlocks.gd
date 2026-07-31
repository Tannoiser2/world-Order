extends SceneTree
## Audit multiplayer: soft-lock e buchi di autorizzazione trovati e corretti in v0.7.169.
##   1. Aftermath: dopo la sotto-scelta Engage token (money/Difesa) sul CLIENT il latch
##      _aftermath_subchoice restava attivo per sempre -> barra vuota, round bloccato.
##   2. Research: l'host poteva agire nel passo Research del client (guardie _i_acting mancanti).
##   3. Abilità Growth 1x/round: _used_ongoing non era nello snapshot -> sul client la carta
##      restava "Usabile" per sempre.
##   4. use_ongoing / prep_ready_pick senza guardia: l'host poteva consumare abilità o
##      riattivazioni del client aprendo la sua linguetta.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_net_softlocks.gd

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

	# ================= 1) Aftermath: latch della sotto-scelta si auto-azzera =================
	host._ui_phase = "Aftermath"
	var china_h = host.gs.players[1]
	china_h.engage_tokens = ["africa"]
	china_h.allied_countries = [{"id": "af1", "display_name": "Alleata Africa", "region": "africa"}]
	china_h.money = 0
	host._aftermath_idx = 1
	host._show_aftermath_choices(china_h)
	await process_frame

	# Il CLIENT tocca il proprio Engage token sulla mappa: si apre la sotto-scelta locale.
	var china_c = client._aftermath_choice_p
	client._on_aftermath_token(china_c, "africa")
	var s1: bool = client._aftermath_subchoice == "africa" and client.choice_flow.get_child_count() > 0
	print("[%s] client: sotto-scelta Engage token aperta (latch='%s')" % ["OK" if s1 else "FAIL", client._aftermath_subchoice])
	if not s1: fails += 1

	# Sceglie "+money": il comando va all'host, che applica e ribroadcasta.
	client._cmd_aftermath_token_money(china_c, "africa")
	await process_frame
	var s2: bool = china_h.money == 5 and "africa" not in china_h.engage_tokens
	print("[%s] host ha applicato la scelta (+5 money, token scartato)" % ["OK" if s2 else "FAIL"])
	if not s2: fails += 1

	# IL NOCCIOLO del soft-lock: sul client il latch si azzera da solo (il token non esiste
	# più) e la barra principale con «Continua» TORNA - prima restava vuota per sempre.
	client._refresh()
	await process_frame
	var cont: Button = _find_button(client.choice_bar, "Continua")
	var s3: bool = client._aftermath_subchoice == "" and cont != null
	print("[%s] client: latch auto-azzerato e barra «Continua» tornata (latch='%s')" % [
		"OK" if s3 else "FAIL", client._aftermath_subchoice])
	if not s3: fails += 1

	# Il client chiude il proprio Aftermath: nessun blocco.
	client.apply_command(GameCommands.aftermath_continue(1, client._next_seq()))
	await process_frame
	var s4: bool = host._aftermath_idx == 2
	print("[%s] client chiude il proprio Aftermath (idx host=%d)" % ["OK" if s4 else "FAIL", host._aftermath_idx])
	if not s4: fails += 1
	host._aftermath_choice_p = null
	host._after_change()
	await process_frame

	# ================= 2) Research: l'host NON agisce nel passo del client =================
	host._ui_phase = "Research"
	host._research_idx = 1
	host.active_seat = 1
	host._net_sync()
	await process_frame
	var idx_pre: int = host._research_idx
	host._cmd_research_continue()      # l'host prova a chiudere il Research del CLIENT
	await process_frame
	var s5: bool = host._research_idx == idx_pre
	print("[%s] host bloccato dalla guardia: non chiude il Research del client (idx=%d)" % [
		"OK" if s5 else "FAIL", host._research_idx])
	if not s5: fails += 1

	client._cmd_research_continue()    # il CLIENT invece può: è il suo passo
	await process_frame
	var s6: bool = host._research_idx != idx_pre
	print("[%s] client chiude il PROPRIO Research (idx %d -> %d)" % ["OK" if s6 else "FAIL", idx_pre, host._research_idx])
	if not s6: fails += 1

	# ================= 3) _used_ongoing sincronizzato al client =================
	host._used_ongoing = {"china": ["once_per_round:reaction_force"]}
	host._net_sync()
	await process_frame
	var s7: bool = client._ongoing_used("china", "once_per_round:reaction_force")
	print("[%s] client vede l'abilità 1x/round come GIÀ USATA (snapshot sincronizzato)" % ["OK" if s7 else "FAIL"])
	if not s7: fails += 1

	# ================= 4) Guardie use_ongoing / prep_ready_pick =================
	# Il research_continue di sopra ha fatto partire l'Aftermath sull'host: lo si azzera per
	# tornare a un turno di AZIONE pulito del client (altrimenti _acting_seat() resta il
	# giocatore Aftermath e il gating scatterebbe per il motivo sbagliato).
	host._aftermath_choice_p = null
	host._ui_phase = "Azione"; host.gs.phase = WO.Phase.ACTION
	host.active_seat = 1               # turno del CLIENT
	host._used_ongoing = {}
	host._net_sync()
	await process_frame
	host._cmd_use_ongoing("once_per_round:redraw_hand")   # l'host prova a usare l'abilità del client
	await process_frame
	var s8: bool = host._used_ongoing.is_empty()
	print("[%s] host bloccato: non consuma l'abilità 1x/round del client" % ["OK" if s8 else "FAIL"])
	if not s8: fails += 1

	host._ui_phase = "Preparazione"
	china_h.exhausted = {"af1": true}
	host._prep_ready_remaining = 1
	host._net_sync()
	await process_frame
	host._cmd_prep_ready_pick({"id": "af1"})              # l'host prova a riattivare per il client
	await process_frame
	var s9: bool = bool(china_h.exhausted.get("af1", false))
	print("[%s] host bloccato: non riattiva le Nazioni del client" % ["OK" if s9 else "FAIL"])
	if not s9: fails += 1

	client._cmd_prep_ready_pick({"id": "af1"})            # il CLIENT invece può
	await process_frame
	var s10: bool = not bool(china_h.exhausted.get("af1", false))
	print("[%s] client riattiva la PROPRIA Nazione (percorso legittimo intatto)" % ["OK" if s10 else "FAIL"])
	if not s10: fails += 1

	host.queue_free()
	client.queue_free()
	await process_frame

	print("Verifica soft-lock/autorizzazioni multiplayer: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and text in (node as Button).text:
		return node
	for c in node.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null
