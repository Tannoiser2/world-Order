extends SceneTree
## Audit dati: 5 effetti erano DEFINITI NEI DATI ma nessuno li leggeva, quindi le carte non
## facevano ciò che promettono. Corretti in v0.7.170; qui la regressione per ciascuno.
##   1. "Global Currency" (USA) — modifier `gain_5_money_per_import`: «Trade. Poi, guadagna
##      5 money per ogni TIPO di risorsa che hai Importato» -> faceva solo un Trade normale.
##   2. "EU Neighborhood Policy" / "Main UN Funding Contributor" — `engage_without_allied`:
##      l'Engage senza Country alleata nella Regione falliva (il motore accettava già
##      bypass_ally_check, ma nessuno glielo passava).
##   3. "The World's Factory" (Cina) — `produce_max:2`: produceva l'INTERA produzione di Beni
##      di Consumo invece di «fino a 2».
##   4. "Minimize Bureaucracy" — `trash` con `source:"self"`: chiedeva quale carta della mano
##      eliminare invece di eliminare SE STESSA.
##   5. "Belt and Road Initiative" (Cina) — op `spend_then`: pagavi i money e i sotto-op
##      interattivi (Invest) venivano "differiti" e persi in silenzio.
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_card_modifiers_fix.gd

var _fails := 0

func _init() -> void:
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.active_seat = 0

	await _test_global_currency(b)
	await _test_engage_without_allied(b)
	await _test_produce_max(b)
	await _test_trash_self(b)
	await _test_spend_then(b)

	b.queue_free()
	await process_frame
	print("Verifica modifier/op delle carte (audit dati): %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1


func _prime(b: Variant) -> void:
	b.active_seat = 0
	b.playing_card = {"display_name": "test", "effect_ops": []}
	b.play_queue = []
	b.awaiting = ""
	b._plays_left = 1


# 1) Global Currency: +5 money per TIPO importato (non per unità).
func _test_global_currency(b: Variant) -> void:
	var p = b.gs.players[0]
	p.money = 100
	p.resources["energy"] = 0
	p.resources["food"] = 0
	p.allied_countries = [{"id": "gc", "region": "africa", "value": 1,
		"exports": [], "imports": ["energy", "food"]}]
	b.trade_deals = {"cards": [{"power": p.power, "exports": 2, "imports": 2, "import_from": {}}]}
	_prime(b)
	b.active_mods = {"gain_5_money_per_import": true}
	b._open_trade_ui()
	b._trade_adjust("energy", "import", 1)
	b._trade_adjust("food", "import", 1)      # 2 TIPI importati
	var m0: int = p.money
	var cost := Actions.IMPORT_COST["energy"] + Actions.IMPORT_COST["food"]
	b._apply_trade()
	await process_frame
	# money = m0 - costo import + 5*2 (due tipi)
	_check(p.money == m0 - cost + 10,
		"Global Currency: +5 money per tipo importato (2 tipi -> +10; money %d -> %d)" % [m0, p.money])

	# Senza il modifier lo stesso Trade NON dà il bonus (isola la causa).
	p.money = 100
	p.resources["energy"] = 0
	p.resources["food"] = 0
	_prime(b)
	b.active_mods = {}
	b._open_trade_ui()
	b._trade_adjust("energy", "import", 1)
	b._trade_adjust("food", "import", 1)
	var m1: int = p.money
	b._apply_trade()
	await process_frame
	_check(p.money == m1 - cost, "Senza il modifier: nessun bonus (money %d -> %d)" % [m1, p.money])
	b.trade_deals = DataLoader.load_trade_deals()


# 2) engage_without_allied: Engage in una Regione SENZA Country alleate lì.
func _test_engage_without_allied(b: Variant) -> void:
	var p = b.gs.players[0]
	p.allied_countries = []                       # nessuna alleata da nessuna parte
	p.resources["diplomacy"] = 20
	p.engage_tokens = []
	var region := "africa"
	var inf0: int = b.gs.regions[region]["track"].count(p.power)

	# SENZA il modifier: l'Engage deve fallire (regolamento pag. 13).
	_prime(b)
	b.active_mods = {}
	b._resolve_engage_slot(region, [], "permanent")
	await process_frame
	var inf_no: int = b.gs.regions[region]["track"].count(p.power)
	_check(inf_no == inf0, "Senza modifier: Engage senza alleati fallisce (influenza invariata=%d)" % inf_no)

	# CON il modifier: riesce.
	_prime(b)
	b.active_mods = {"engage_without_allied": true}
	b._resolve_engage_slot(region, [], "permanent")
	await process_frame
	var inf_yes: int = b.gs.regions[region]["track"].count(p.power)
	_check(inf_yes == inf0 + 1,
		"engage_without_allied: Engage riesce senza Country alleate (influenza %d -> %d)" % [inf0, inf_yes])


# 3) produce_max:2 — produce FINO A 2, non tutta la produzione.
func _test_produce_max(b: Variant) -> void:
	var p = b.gs.players[0]
	p.production["consumer_goods"] = 5            # produzione alta: il tetto deve mordere
	p.resources["consumer_goods"] = 0
	p.resources["raw_materials"] = 20
	p.resources["energy"] = 20
	_prime(b)
	b.active_mods = Modifiers.parse(["produce_max:2"])
	b.play_queue = [{"op": "produce", "types": ["consumer_goods"]}]
	b._advance_play()
	await process_frame
	_check(int(p.resources["consumer_goods"]) == 2,
		"produce_max:2: prodotti 2 Beni di Consumo su 5 di produzione (=%d)" % int(p.resources["consumer_goods"]))

	# Senza il modifier: produce tutto (comportamento normale, non deve rompersi).
	p.resources["consumer_goods"] = 0
	_prime(b)
	b.active_mods = {}
	b.play_queue = [{"op": "produce", "types": ["consumer_goods"]}]
	b._advance_play()
	await process_frame
	_check(int(p.resources["consumer_goods"]) == 5,
		"Senza tetto: produce l'intera produzione (=%d)" % int(p.resources["consumer_goods"]))


# 4) trash source "self": elimina SE STESSA, senza chiedere quale carta della mano.
func _test_trash_self(b: Variant) -> void:
	var p = b.gs.players[0]
	var other := {"id": "keep", "display_name": "Da tenere", "effect_ops": [{"op": "noop"}]}
	var self_card := {"id": "mb", "display_name": "Minimize Bureaucracy",
		"effect_ops": [{"op": "trash", "source": "self"}]}
	p.hand = [other, self_card]
	p.played = []
	p.discard = []
	b.playing_card = {}
	b.play_queue = []
	b.awaiting = ""
	b._plays_left = 1
	b._played_this_turn = false
	b._play_card(self_card)
	await process_frame
	var gone: bool = not (self_card in p.hand) and not (self_card in p.played) and not (self_card in p.discard)
	_check(gone and (other in p.hand) and not b._popup_active(),
		"trash source=self: la carta esce DAL GIOCO senza chiedere nulla (mano=%d, niente popup)" % p.hand.size())


# 5) spend_then: paga e i sotto-op interattivi si risolvono davvero (non "differiti").
func _test_spend_then(b: Variant) -> void:
	var p = b.gs.players[0]
	p.money = 100
	p.resources["energy"] = 0
	_prime(b)
	b.active_mods = {}
	# `then` con un op AUTO (gain_resource) per verificare che venga eseguito davvero.
	b.play_queue = [{"op": "spend_then", "money": 10, "then": [{"op": "gain_resource", "type": "energy", "amount": 2}]}]
	b._advance_play()
	await process_frame
	_check(p.money == 90 and int(p.resources["energy"]) == 2,
		"spend_then: pagati 10 money (=%d) E il 'then' eseguito (+2 Energia =%d)" % [p.money, int(p.resources["energy"])])

	# `then` con un op INTERATTIVO (invest): deve mettersi in attesa del target, non sparire.
	p.money = 100
	p.allied_countries = [{"id": "st1", "display_name": "Paese", "region": "africa", "invest_cost": 5, "value": 2}]
	p.fdi_countries = []
	_prime(b)
	b.play_queue = [{"op": "spend_then", "money": 10, "then": [{"op": "invest"}]}]
	b._advance_play()
	await process_frame
	_check(p.money == 90 and b.awaiting == "allied_country",
		"spend_then: con un 'then' INTERATTIVO (Invest) l'azione si apre davvero (awaiting='%s')" % b.awaiting)
