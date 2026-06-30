extends SceneTree
## Carta Crescita "Vantaggio Operativo" (D&D, Liv.4):
##   - All'acquisto pesca 2 Orientamenti Strategici della tua potenza, tienine 1 (+VP);
##   - poi puoi attivare GRATIS 1 tuo Asset (i suoi op si risolvono nella carta in corso).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_growth_vantaggio.gd

var _fails := 0

func _init() -> void:
	var bp: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["eu", "usa"]
	GameConfig.automa_powers = []
	var b: Variant = bp.instantiate()
	get_root().add_child(b)
	await process_frame
	b._ui_phase = "Azione"; b.gs.phase = WO.Phase.ACTION
	b.active_seat = 0

	await _test_acquire_keep(b)
	await _test_free_activation(b)

	b.queue_free()
	await process_frame
	print("Verifica Vantaggio Operativo: %s" % ("OK" if _fails == 0 else "%d FALLITI" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", msg])
	if not ok: _fails += 1


func _vantaggio_card() -> Dictionary:
	var f := FileAccess.open("res://data/growth_cards.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for c in d["cards"]:
		if String(c.get("id", "")) == "growth_vantaggio_operativo":
			return c
	return {}


## Passo 1: acquisto -> pesca 2 Asset (UE), tiene 1 (+VP), poi "Non attivare".
func _test_acquire_keep(b: Variant) -> void:
	var p = b.gs.players[0]
	p.resources = {"energy": 0, "raw_materials": 0, "food": 0, "consumer_goods": 0, "services": 4, "diplomacy": 0}
	p.money = 15
	p.growth_cards = []
	p.strategic_assets = []
	p.used_strategic_assets = []
	p.victory_points = 0
	b.playing_card = {"display_name": "innesco", "effect_ops": []}
	b.play_queue = []
	b._plays_left = 1
	b._played_this_turn = false

	b._buy_growth_action(_vantaggio_card(), 4)
	await process_frame
	var vp_after_buy: int = p.victory_points
	_check(vp_after_buy == 5 and p.growth_cards.size() == 1, "Vantaggio: acquistata (+5 VP, growth=%d)" % p.growth_cards.size())
	var draw_popup: bool = b._popup_active() and b._popup_items.size() == 2
	_check(draw_popup, "Vantaggio: pesca 2 Asset Strategici (popup 2 opzioni)")
	# VP iniziali dell'Asset che terremo (indice 0).
	var keep_sa: Dictionary = (b._popup_items[0] as Dictionary).get("value", {})
	var keep_vp: int = int(keep_sa.get("starting_vp", 0))
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))
	await process_frame
	_check(p.strategic_assets.size() == 1 and String(p.strategic_assets[0].get("id", "")) == String(keep_sa.get("id", "")),
		"Vantaggio: tenuto 1 Asset (%s)" % keep_sa.get("display_name", "?"))
	_check(p.victory_points == 5 + keep_vp, "Vantaggio: +VP dell'Asset tenuto (totale %d, atteso %d)" % [p.victory_points, 5 + keep_vp])
	# Passo 2: popup attivazione ("Non attivare" + 1 Asset posseduto).
	var act_popup: bool = b._popup_active() and b._popup_items.size() == 2
	_check(act_popup, "Vantaggio: scelta di attivare gratis un Asset (popup 2 opzioni)")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 0))   # "Non attivare"
	await process_frame
	_check(b.playing_card.is_empty(), "Vantaggio: 'Non attivare' -> carta innesco risolta")


## Passo 2 isolato: attivazione gratuita di un Asset noto -> i suoi op si risolvono.
func _test_free_activation(b: Variant) -> void:
	var p = b.gs.players[0]
	p.money = 0
	p.strategic_assets = [{"id": "sa_demo", "display_name": "Demo", "effect_ops": [{"op": "gain_money", "amount": 20}]}]
	p.used_strategic_assets = []
	b.playing_card = {"display_name": "innesco2", "effect_ops": []}
	b.play_queue = []
	b._plays_left = 1
	b._played_this_turn = false

	b._operational_activate(p)
	await process_frame
	var act_popup: bool = b._popup_active() and b._popup_items.size() == 2
	_check(act_popup, "Attivazione: popup 'Non attivare' + 1 Asset")
	b.apply_command(GameCommands.popup_choice(0, b._next_seq(), 1))   # attiva "Demo"
	await process_frame
	_check(p.money == 20, "Attivazione: effetto dell'Asset risolto (gain_money 20 -> money=%d)" % p.money)
	_check("sa_demo" in p.used_strategic_assets.map(func(s): return String(s.get("id", ""))) and p.strategic_assets.is_empty(),
		"Attivazione: Asset girato a faccia in giù (usato)")
	_check(b.playing_card.is_empty(), "Attivazione: carta innesco risolta a fine catena")
