extends SceneTree
## Move (Military) standard: lo spostamento delle Armate e' consentito SOLO verso Regioni della
## propria zona di interesse (bandiera della potenza) o dove si ha una Base (regolamento pag. 14).
## Le varianti "free" (Strategic Asset) non sono soggette a questo limite. Verifica sia il
## predicato della UI (_move_valid_dest) sia il controllo di autorita' (_apply_move_step).
##
## Uso: godot --headless --path game --script res://scripts/tests/verify_move_zone.gd

func _init() -> void:
	var fails := 0
	var board_packed: PackedScene = load("res://scenes/board.tscn")
	GameConfig.net = null
	GameConfig.powers = ["usa", "china"]
	var b: Variant = board_packed.instantiate()
	get_root().add_child(b)
	await process_frame
	b._begin_action_phase()

	var p = b.gs.players[0]   # usa
	# Trova una Regione nella zona di interesse di usa e una FUORI (senza Base).
	var in_zone := ""
	var out_zone := ""
	for rid in b.gs.regions:
		var zone: Array = b.gs.regions[rid].get("zone", [])
		if "usa" in zone and in_zone == "":
			in_zone = rid
		elif not ("usa" in zone) and out_zone == "":
			out_zone = rid
	print("[INFO] in_zone=%s  out_zone=%s" % [in_zone, out_zone])

	# Predisponi il Move standard (a pagamento) dalla Riserva.
	b.active_seat = 0
	p.money = 100
	p.armies_available = 5
	p.bases = []
	p.allied_countries = []
	b.awaiting = "move"
	b._move_ctx = {"free": false, "max": 5, "min": 0, "moved": 0, "source": null, "allowed": [], "exclude": []}

	# 1) Predicato UI: la Regione in zona e' valida, quella fuori NO.
	var s1: bool = b._move_valid_dest(in_zone) and not b._move_valid_dest(out_zone)
	print("[%s] _move_valid_dest: in-zona valida, fuori-zona no (in=%s, out=%s)" % [
		"OK" if s1 else "FAIL", str(b._move_valid_dest(in_zone)), str(b._move_valid_dest(out_zone))])
	if not s1: fails += 1

	# 2) Autorita': spostare FUORI zona viene RIFIUTATO (niente Armata, niente money speso).
	var money0: int = p.money
	var ok_out: bool = b._apply_move_step("_reserve", out_zone)
	var placed_out: int = int((b.gs.regions[out_zone]["armies"] as Dictionary).get("usa", 0))
	var s2: bool = (not ok_out) and placed_out == 0 and p.money == money0
	print("[%s] Move fuori zona rifiutato (ok=%s, armate=%d, money %d->%d)" % [
		"OK" if s2 else "FAIL", str(ok_out), placed_out, money0, p.money])
	if not s2: fails += 1

	# 3) Autorita': spostare IN zona riesce (1 Armata piazzata, -5 money).
	var ok_in: bool = b._apply_move_step("_reserve", in_zone)
	var placed_in: int = int((b.gs.regions[in_zone]["armies"] as Dictionary).get("usa", 0))
	var s3: bool = ok_in and placed_in == 1 and p.money == money0 - Actions.MOVE_COST
	print("[%s] Move in zona riuscito (ok=%s, armate=%d, money=%d)" % [
		"OK" if s3 else "FAIL", str(ok_in), placed_in, p.money])
	if not s3: fails += 1

	# 4) Con una BASE nella Regione fuori zona, lo spostamento li' diventa valido.
	p.allied_countries.append({"id": "base_test", "display_name": "Base Test", "region": out_zone, "value": 1})
	p.bases.append("base_test")
	var ok_base: bool = b._apply_move_step("_reserve", out_zone)
	var placed_base: int = int((b.gs.regions[out_zone]["armies"] as Dictionary).get("usa", 0))
	var s4: bool = b._move_valid_dest(out_zone) and ok_base and placed_base == 1
	print("[%s] Move dove hai una Base riuscito anche fuori zona (ok=%s, armate=%d)" % [
		"OK" if s4 else "FAIL", str(ok_base), placed_base])
	if not s4: fails += 1

	# 5) Variante FREE (Strategic Asset): nessun limite di zona/Base.
	b._move_ctx = {"free": true, "max": 5, "min": 0, "moved": 0, "source": null, "allowed": [], "exclude": []}
	p.allied_countries = []; p.bases = []   # niente Base
	var free_region := ""
	for rid in b.gs.regions:
		if not ("usa" in b.gs.regions[rid].get("zone", [])):
			free_region = rid
			break
	var ok_free: bool = b._move_valid_dest(free_region) and b._apply_move_step("_reserve", free_region)
	print("[%s] Move 'free' consentito anche fuori zona (regione=%s, ok=%s)" % [
		"OK" if ok_free else "FAIL", free_region, str(ok_free)])
	if not ok_free: fails += 1

	b.queue_free()
	await process_frame
	print("Verifica Move nelle zone d'influenza / Base: %s" % ("OK" if fails == 0 else "%d FALLITI" % fails))
	quit(1 if fails > 0 else 0)
