extends SceneTree
## Ultimi 8 Orientamenti Strategici (Diplomacy & Dominance) — effetti complessi:
##   - Cambio di Regime (Russia/USA, regime_change): prendi 1 Nazione Alleata altrui.
##   - BRICS (Russia, brics): 2 di 3 Regioni, poi la Cina può prendere la terza.
##   - Agenzia Centrale di Intelligence (USA, swap_influence): scambia Influenza temp/perm.
##   - Aiuti Economici e Militari (USA, aid_econ_military): esaurisci 2 alleati, +Influenza x2.
##   - Surplus Commerciale (China, surplus_regional_influence): +Influenza per Regione da Export.
##   - Consenso di Pechino (China, china_prosperity_engage): +Prosperità poi Engage libero.
##   - Politica Estera di Sicurezza Comune (UE, eu_foreign_policy): esaurisci per Produrre, poi Engage/Base.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_strategic_assets_dd2.gd

var _fails := 0

func _init() -> void:
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "eu", "russia", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame

	await _test_regime_change(b)
	await _test_brics(b)
	await _test_swap_influence(b)
	await _test_aid_econ_military(b)
	await _test_surplus_regional_influence(b)
	await _test_china_prosperity_engage(b)
	await _test_eu_foreign_policy(b)

	b.queue_free()
	await process_frame
	print("Verifica ultimi 8 Orientamenti Strategici: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1


func _idx(b: Variant, items_label: String) -> int:
	for i in b._popup_items.size():
		if items_label in String((b._popup_items[i] as Dictionary).get("label", "")):
			return i
	return -1


## Prepara una nuova "giocata" per il seggio indicato (bypassa la mano: come verify_action_cards.gd).
func _prime(b: Variant, seat: int) -> void:
	b.active_seat = seat
	b.playing_card = {"display_name": "orientamento", "effect_ops": []}
	b.play_queue = []
	b.awaiting = ""
	b._plays_left = 1


func _choose(b: Variant, label_part: String) -> int:
	var idx := _idx(b, label_part)
	b.apply_command(GameCommands.popup_choice(b.active_seat, b._next_seq(), idx))
	return idx


# --- Cambio di Regime (russia esclude china; usa la stessa op per usa/eu con exclude diverso) ---

func _test_regime_change(b: Variant) -> void:
	var russia = b.gs.players[2]
	var eu = b.gs.players[1]
	russia.resources["services"] = 1
	russia.armies_available = 1
	russia.money = 50
	eu.allied_countries.append({"id": "test_ally_1", "display_name": "Nazione Test", "value": 1, "region": "europe"})
	eu.exhausted = {}
	var russia_before: int = russia.allied_countries.size()
	var inf0: int = b.gs.regions["europe"]["track"].count("russia")
	_prime(b, 2)
	b._op_regime_change({"exclude": "china"})
	await process_frame
	var idx := _idx(b, "Nazione Test")
	_check(b._popup_active() and idx >= 0, "Cambio di Regime: popup con la Nazione Alleata altrui (non iniziale, valore 1)")
	b.apply_command(GameCommands.popup_choice(2, b._next_seq(), idx))
	await process_frame
	var still_eu := false
	for c in eu.allied_countries:
		if String(c.get("id", "")) == "test_ally_1": still_eu = true
	var moved: bool = not still_eu and russia.allied_countries.size() == russia_before + 1 \
		and not bool(russia.exhausted.get("test_ally_1", true))
	var paid: bool = russia.money == 45 and russia.armies_available == 0 and int(russia.resources["services"]) == 0
	var inf1: int = b.gs.regions["europe"]["track"].count("russia")
	_check(moved and paid, "Cambio di Regime: Nazione spostata a Russia (=%s), pagati 1 Servizi+1 Armata+5 money (=%s)" % [str(moved), str(paid)])
	_check(inf1 == inf0 + 1, "Cambio di Regime: +1 Influenza russa in Europa (%d -> %d)" % [inf0, inf1])


# --- BRICS (russia sceglie 2 di 3 Regioni; poi la Cina puo' prendere la terza) ---

func _test_brics(b: Variant) -> void:
	var russia = b.gs.players[2]
	var china = b.gs.players[3]
	russia.money = 100
	china.money = 50
	var inf0_am: int = b.gs.regions["americas"]["track"].count("russia")
	var inf0_af: int = b.gs.regions["africa"]["track"].count("russia")
	var inf0_sa: int = b.gs.regions["south_asia"]["track"].count("china")
	_prime(b, 2)
	b._op_brics({})
	await process_frame
	_check(b._popup_active() and b._popup_items.size() == 3, "BRICS: popup con 3 Regioni per la 1a scelta")
	_choose(b, "Americas")
	await process_frame
	_check(b._popup_active() and b._popup_items.size() == 2, "BRICS: popup con 2 Regioni rimaste per la 2a scelta")
	_choose(b, "Africa")
	await process_frame
	_check(russia.money == 70, "BRICS: -30 money (100->%d)" % russia.money)
	_check(b.awaiting == "influence_cell", "BRICS: scelta slot Influenza (map-click) per Americhe")
	b._cmd_pick_influence_cell("americas", "permanent")
	await process_frame
	_check(b.awaiting == "influence_cell", "BRICS: scelta slot Influenza (map-click) per Africa")
	b._cmd_pick_influence_cell("africa", "permanent")
	await process_frame
	var inf1_am: int = b.gs.regions["americas"]["track"].count("russia")
	var inf1_af: int = b.gs.regions["africa"]["track"].count("russia")
	_check(inf1_am == inf0_am + 1 and inf1_af == inf0_af + 1, "BRICS: +1 Influenza russa in Americhe e Africa")
	_check(b._popup_active() and _idx(b, "Cina") >= 0, "BRICS: popup per la Cina sulla terza Regione (Asia meridionale)")
	_choose(b, "Sì")
	await process_frame
	_check(china.money == 30, "BRICS: la Cina paga 20 money (50->%d)" % china.money)
	b._cmd_pick_influence_cell("south_asia", "permanent")
	await process_frame
	var inf1_sa: int = b.gs.regions["south_asia"]["track"].count("china")
	_check(inf1_sa == inf0_sa + 1, "BRICS: +1 Influenza cinese in Asia meridionale (terza Regione)")


# --- Agenzia Centrale di Intelligence (scambia 1 temp propria con 1 perm altrui, stessa Regione) ---

func _test_swap_influence(b: Variant) -> void:
	var usa = b.gs.players[0]
	usa.money = 50
	usa.resources["services"] = 1
	var track: InfluenceTrack = b.gs.regions["central_asia"]["track"]
	var track2: InfluenceTrack = b.gs.regions["africa"]["track"]
	# Forza 1 Influenza permanente russa e 1 temporanea USA in Asia Centrale E in Africa
	# (2 Regioni idonee: cosi' si puo' verificare anche il 2° scambio facoltativo).
	for i in track.perm.size():
		if track.perm[i] == null:
			track.perm[i] = "russia"
			break
	for i in track.temp.size():
		if track.temp[i] == null:
			track.temp[i] = "usa"
			break
	for i in track2.perm.size():
		if track2.perm[i] == null:
			track2.perm[i] = "china"
			break
	for i in track2.temp.size():
		if track2.temp[i] == null:
			track2.temp[i] = "usa"
			break
	_prime(b, 0)
	b._op_swap_influence({})
	await process_frame
	var idx := _idx(b, "central asia")
	_check(b._popup_active() and idx >= 0, "Agenzia Centrale: popup con la Regione idonea (Asia Centrale)")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx))
	await process_frame
	_check(usa.money == 40, "Agenzia Centrale: -10 money (50->%d)" % usa.money)
	var swapped: bool = track.temp.has("russia") and track.perm.has("usa")
	_check(swapped, "Agenzia Centrale: scambio riuscito (Russia ora temporanea, USA ora permanente)")
	# Secondo scambio facoltativo, in un'altra Regione idonea (Africa), costo 1 Servizi.
	# (Africa ha ora 2 proprietari permanenti non-USA: "china" del setup di test e "russia"
	# aggiunta dal test BRICS sopra -> segue un'ulteriore scelta di CON CHI scambiare.)
	var idx2 := _idx(b, "africa")
	_check(b._popup_active() and idx2 >= 0, "Agenzia Centrale: offre il 2° scambio facoltativo (Africa)")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx2))
	await process_frame
	var idx_owner := _idx(b, "CHINA")
	_check(b._popup_active() and idx_owner >= 0, "Agenzia Centrale: 2 proprietari non-USA in Africa -> chiede con chi scambiare")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx_owner))
	await process_frame
	_check(int(usa.resources["services"]) == 0, "Agenzia Centrale: 2° scambio pagato con 1 Servizi (non money)")
	var swapped2: bool = track2.temp.has("china") and track2.perm.has("usa")
	_check(swapped2, "Agenzia Centrale: 2° scambio riuscito in Africa (China ora temporanea, USA ora permanente)")
	_check(not b._popup_active(), "Agenzia Centrale: carta conclusa dopo il 2° scambio")


# --- Aiuti Economici e Militari (esaurisci 2 alleati in Regioni diverse) ---

func _test_aid_econ_military(b: Variant) -> void:
	var usa = b.gs.players[0]
	usa.money = 50
	usa.armies_available = 2
	usa.resources["diplomacy"] = 0
	usa.allied_countries = [
		{"id": "a1", "display_name": "Alfa", "region": "americas"},
		{"id": "a2", "display_name": "Beta", "region": "africa"},
	]
	usa.exhausted = {}
	var inf0_am: int = b.gs.regions["americas"]["track"].count("usa")
	var inf0_af: int = b.gs.regions["africa"]["track"].count("usa")
	_prime(b, 0)
	b._op_aid_econ_military({})
	await process_frame
	var idx1 := _idx(b, "Alfa")
	_check(b._popup_active() and idx1 >= 0, "Aiuti Econ.: popup per la 1a Nazione Alleata")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx1))
	await process_frame
	var idx2 := _idx(b, "Beta")
	_check(b._popup_active() and idx2 >= 0, "Aiuti Econ.: popup per la 2a Nazione Alleata (Regione diversa)")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), idx2))
	await process_frame
	_check(usa.money == 35 and usa.armies_available == 0, "Aiuti Econ.: -15 money e -2 Armate")
	_check(bool(usa.exhausted.get("a1", false)) and bool(usa.exhausted.get("a2", false)), "Aiuti Econ.: entrambe le Nazioni esaurite")
	_check(int(usa.resources["diplomacy"]) == 2, "Aiuti Econ.: +2 Diplomazia")
	_check(b.awaiting == "influence_cell", "Aiuti Econ.: scelta slot Influenza (Americhe)")
	b._cmd_pick_influence_cell("americas", "permanent")
	await process_frame
	_check(b.awaiting == "influence_cell", "Aiuti Econ.: scelta slot Influenza (Africa)")
	b._cmd_pick_influence_cell("africa", "permanent")
	await process_frame
	var inf1_am: int = b.gs.regions["americas"]["track"].count("usa")
	var inf1_af: int = b.gs.regions["africa"]["track"].count("usa")
	_check(inf1_am == inf0_am + 1 and inf1_af == inf0_af + 1, "Aiuti Econ.: +1 Influenza in ciascuna delle 2 Regioni")


# --- Surplus Commerciale (dopo il Trade, +Influenza per Regione con >= soglia money esportati) ---

func _test_surplus_regional_influence(b: Variant) -> void:
	var china = b.gs.players[3]
	china.allied_countries = [
		{"id": "c1", "display_name": "Gamma", "region": "europe", "exports": ["energy", "energy", "energy", "energy", "energy", "energy", "energy", "energy"]},
		{"id": "c2", "display_name": "Delta", "region": "africa", "exports": ["energy", "energy"]},
	]
	b._trade_exported = {"energy": 10}   # 10 x 5 money (EXPORT_GAIN) = 50: europe 8/10=40, africa 2/10=10
	var inf0: int = b.gs.regions["europe"]["track"].count("china")
	_prime(b, 3)
	b._op_surplus_regional_influence({"threshold": 35})
	await process_frame
	_check(b.awaiting == "influence_cell", "Surplus Commerciale: scelta slot Influenza per la Regione sopra soglia (Europa)")
	b._cmd_pick_influence_cell("europe", "permanent")
	await process_frame
	var inf1: int = b.gs.regions["europe"]["track"].count("china")
	_check(inf1 == inf0 + 1, "Surplus Commerciale: +1 Influenza in Europa (40 >= 35 di soglia)")
	_check(not b._popup_active() and b.awaiting == "", "Surplus Commerciale: nessuna Influenza extra per l'Africa (10 < 35)")
	b._trade_exported = {}


# --- Consenso di Pechino (aumenta Prosperità -> +1 Diplomazia, poi Engage senza alleati) ---

func _test_china_prosperity_engage(b: Variant) -> void:
	var china = b.gs.players[3]
	china.prosperity_level = 0
	china.resources["consumer_goods"] = 2
	china.resources["diplomacy"] = 5
	china.allied_countries = []   # nessuna Nazione Alleata: l'Engage libero deve funzionare comunque
	var inf0: int = b.gs.regions["east_asia_pacific"]["track"].count("china")
	_prime(b, 3)
	b._op_china_prosperity_engage({})
	await process_frame
	_check(b._popup_active(), "Consenso di Pechino: popup per aumentare la Prosperità")
	_choose(b, "Sì")
	await process_frame
	_check(china.prosperity_level == 1 and int(china.resources["consumer_goods"]) == 0, "Consenso di Pechino: Prosperità 0->1 (-2 Beni di Consumo)")
	_check(int(china.resources["diplomacy"]) == 6, "Consenso di Pechino: +1 Diplomazia dall'aumento di Prosperità")
	_check(b.awaiting == "region", "Consenso di Pechino: ora chiede una Regione per l'Engage libero")
	b.apply_command(GameCommands.pick_region(3, b._next_seq(), "east_asia_pacific"))
	await process_frame
	var inf1: int = b.gs.regions["east_asia_pacific"]["track"].count("china")
	_check(inf1 == inf0 + 1, "Consenso di Pechino: Engage riuscito in Asia Orientale-Pacifico SENZA Nazioni Alleate lì")


# --- Politica Estera di Sicurezza Comune (esaurisci per Produrre, poi Engage o Base) ---

func _test_eu_foreign_policy(b: Variant) -> void:
	var eu = b.gs.players[1]
	eu.allied_countries = [
		{"id": "e1", "display_name": "Stato Uno", "region": "europe", "has_base_symbol": true, "base_allowed_powers": ["eu"]},
		{"id": "e2", "display_name": "Stato Due", "region": "europe"},
	]
	eu.exhausted = {}
	eu.resources["diplomacy"] = 0
	eu.armies_available = 0
	_prime(b, 1)
	b._op_eu_foreign_policy({})
	await process_frame
	var idx1 := _idx(b, "Stato Uno")
	_check(b._popup_active() and idx1 >= 0, "Politica Estera: popup per esaurire il 1° Stato membro (+1 Diplomazia)")
	b.apply_command(GameCommands.popup_choice(1, b._next_seq(), idx1))
	await process_frame
	var idx2 := _idx(b, "Stato Due")
	_check(b._popup_active() and idx2 >= 0, "Politica Estera: popup per esaurire il 2° Stato membro (+1 Armata)")
	b.apply_command(GameCommands.popup_choice(1, b._next_seq(), idx2))
	await process_frame
	_check(int(eu.resources["diplomacy"]) == 1 and eu.armies_available == 1, "Politica Estera: +1 Diplomazia e +1 Armata dai 2 Stati esauriti")
	_check(bool(eu.exhausted.get("e1", false)) and bool(eu.exhausted.get("e2", false)), "Politica Estera: entrambi gli Stati esauriti")
	_check(b._popup_active(), "Politica Estera: popup per l'azione finale (Engage o Base)")
	_choose(b, "Costruisci")
	await process_frame
	_check(b.awaiting == "allied_country", "Politica Estera: instrada verso Build a Base (Nazione Alleata idonea)")
