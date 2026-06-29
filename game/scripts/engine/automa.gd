class_name Automa
extends RefCounted
## Automa (bot) per il SOLO MODE di World Order: Diplomacy & Dominance.
## Riferimento completo delle regole: docs/automa-rules.md.
##
## Questo modulo implementa lo STATO dell'Automa e la parte DETERMINISTICA della sua logica
## gia' pienamente specificata dal regolamento e dai componenti universali (Automa board +
## Player card USA verificata). Le scelte di Regione/Country delle singole azioni
## (Improve Relations/Engage/Invest/Move/Build a Base) e l'integrazione nel flusso di
## gioco/UI arriveranno nei passi successivi (vedi piano in docs/automa-rules.md).

# --- Stato ---
var power: String = ""
var money: int = 0
var focus: int = WO.Focus.DOMESTIC
var vp: int = 10
var prosperity_level: int = 0
var allied_countries: Array = []       # carte Country alleate (come nel gioco)
var fdi: Dictionary = {}               # region -> numero FDI token
var bases: Dictionary = {}             # region -> numero Basi militari
var action_cubes: Dictionary = {}      # spazio azione (Automa board) -> numero cubi
var deck: Array = []                   # pila dei TIPI carta da pescare (si usa il TIPO, non l'effetto)
var card_types: Array = []             # i 12 tipi del mazzo Ability (per rimischiare quando finisce)
var difficulty_hard: bool = false


## Crea un Automa per `power` dai dati della Player card. difficulty: "normal"|"hard".
## I cubi azione partono come da setup (regolamento): 1 in Improve Relations, 1 in Invest,
## 1 in Build a Base. `card_types`: i tipi delle 12 carte Ability (per pescare il tipo a ogni
## turno); se vuoto, `pop_card_type` usa i 4 tipi in modo uniforme.
static func from_setup(power: String, difficulty: String = "normal", card_types: Array = []) -> Automa:
	var a := Automa.new()
	a.power = power
	var pdata: Dictionary = DataLoader.load_automa_players().get(power, {})
	a.money = int(pdata.get("starting_money", 0))
	a.focus = WO.Focus.DOMESTIC
	a.vp = 10
	a.difficulty_hard = (difficulty == "hard")
	a.action_cubes = {"improve_relations": 1, "invest": 1, "build_base": 1}
	a.card_types = card_types.duplicate()
	a.deck = card_types.duplicate()
	a.deck.shuffle()
	return a


## Pesca (consuma) il TIPO della prossima carta Ability del mazzo dell'Automa. Quando il mazzo
## e' vuoto lo rimischia dai 12 tipi originali (o, se ignoti, dai 4 tipi uniformi).
func pop_card_type() -> String:
	if deck.is_empty():
		deck = card_types.duplicate() if not card_types.is_empty() \
			else ["diplomatic", "economic", "military", "domestic"]
		deck.shuffle()
	return String(deck.pop_back())


# --- Preparazione: Focus & money ---

## Money ricevuto scegliendo `focus_value` al round `round_no` (round * moltiplicatore:
## Domestic x10, Diplomatic x5, Military x3).
static func focus_money(focus_value: int, round_no: int) -> int:
	var board := DataLoader.load_automa_board()
	var fm: Dictionary = board.get("focus_money", {})
	return int(fm.get(focus_key(focus_value), 0)) * round_no


static func focus_key(focus_value: int) -> String:
	match focus_value:
		WO.Focus.DIPLOMATIC: return "diplomatic"
		WO.Focus.MILITARY: return "military"
		_: return "domestic"


# --- Fase Azione: dal tipo di carta all'azione (Automa board) ---

## Determina l'azione per una carta di tipo `card_type` ("diplomatic"/"economic"/"military"/
## "domestic") dato lo stato attuale dei cubi azione. Ritorna:
##   { action, cube_from, cube_to, cube_count }
## Regola (regolamento): se ci sono cubi nello spazio SINISTRO della riga, esegui QUELL'azione
## e sposta 1 cubo da sinistra a destra; altrimenti esegui l'azione DESTRA e sposta TUTTI i
## cubi da destra a sinistra. "domestic" non e' una riga: Get a Growth Card o +30 money.
func board_action_for_type(card_type: String) -> Dictionary:
	if card_type == "domestic":
		return {"action": "get_growth_or_money", "cube_from": "", "cube_to": "", "cube_count": 0}
	var rows: Dictionary = DataLoader.load_automa_board().get("action_rows", {})
	if not rows.has(card_type):
		return {"action": "", "cube_from": "", "cube_to": "", "cube_count": 0}
	var row: Dictionary = rows[card_type]
	var left := String(row["left"])
	var right := String(row["right"])
	if int(action_cubes.get(left, 0)) > 0:
		return {"action": left, "cube_from": left, "cube_to": right, "cube_count": 1}
	return {"action": right, "cube_from": right, "cube_to": left, "cube_count": int(action_cubes.get(right, 0))}


## Applica lo spostamento dei cubi indicato da una decisione di board_action_for_type.
func apply_cube_move(decision: Dictionary) -> void:
	var cf := String(decision.get("cube_from", ""))
	var ct := String(decision.get("cube_to", ""))
	var n := int(decision.get("cube_count", 0))
	if cf == "" or ct == "" or n <= 0:
		return
	action_cubes[cf] = maxi(0, int(action_cubes.get(cf, 0)) - n)
	action_cubes[ct] = int(action_cubes.get(ct, 0)) + n


# --- Fase Azione: scelte delle singole azioni (Stadio 2) ---
# Funzioni pure/deterministiche per decidere Regione/Country di ciascuna azione, secondo i
# criteri del regolamento. Lavorano sui dati delle carte Country (campi: value, exports,
# has_base_symbol, base_allowed_powers, region) e sullo stato dell'Automa (allied_countries,
# fdi, bases). L'integrazione col GameState/UI e la pesca delle Auto-Influence card arrivano
# nei passi successivi.

## Regione indicata dalla carta Auto-Influence per QUESTO Automa (la sua riga).
func auto_influence_region(card: Dictionary) -> String:
	return String(((card.get("rows", {}) as Dictionary).get(power, {}) as Dictionary).get("region", ""))

## Vero se la carta Auto-Influence indica un'Armata per questo Automa.
func auto_influence_army(card: Dictionary) -> bool:
	return bool(((card.get("rows", {}) as Dictionary).get(power, {}) as Dictionary).get("army", false))

## Numero di Country alleate dell'Automa in una Regione.
func allies_in_region(region: String) -> int:
	var n := 0
	for c in allied_countries:
		if String((c as Dictionary).get("region", "")) == region:
			n += 1
	return n

## Country alleate in una Regione che consentono all'Automa di costruire una Base.
func base_allies_in_region(region: String) -> int:
	var n := 0
	for c in allied_countries:
		var cc := c as Dictionary
		if String(cc.get("region", "")) == region and bool(cc.get("has_base_symbol", false)) \
				and power in cc.get("base_allowed_powers", []):
			n += 1
	return n

## Max FDI in una Regione = 1 + Country alleate di quella Regione. (Invest)
func invest_fdi_max(region: String) -> int:
	return 1 + allies_in_region(region)

## Vero se l'Automa puo' ancora INVESTIRE in `region` (ha alleati e non e' al massimo FDI).
func can_invest(region: String) -> bool:
	return allies_in_region(region) > 0 and int(fdi.get(region, 0)) < invest_fdi_max(region)

## Max Basi in una Regione = 1 + Country alleate che consentono la Base. (Build a Base)
func base_max(region: String) -> int:
	return 1 + base_allies_in_region(region)

## Vero se l'Automa puo' ancora costruire una BASE in `region`.
func can_build_base(region: String) -> bool:
	return base_allies_in_region(region) > 0 and int(bases.get(region, 0)) < base_max(region)

## Costo (money) per ENGAGE in una Regione: 5 per ogni Diplomazia richiesta
## (`diplomacy_required`), -5 per ogni Country alleata della Regione, -5 se Diplomatic Focus.
## Minimo 0.
func engage_cost(region: String, diplomacy_required: int) -> int:
	var cost := diplomacy_required * 5
	cost -= allies_in_region(region) * 5
	if focus == WO.Focus.DIPLOMATIC:
		cost -= 5
	return maxi(0, cost)

## Sceglie la Country da alleare (Improve Relations) tra le `available` di una Regione,
## secondo i criteri del regolamento, considerando SOLO quelle che puo' permettersi
## (costo = value * 5 money). `starting_ids`: id delle Starting Country dell'Automa.
## Ritorna {} se non puo' permettersi nessuna (il chiamante eseguira' un Trade).
## Criteri (in ordine, restringendo): 1) Starting Country; 2) dove puo' costruire una Base;
## 3) valore piu' alto; 4) la carta piu' a SINISTRA (prima in lista).
func improve_relations_pick(available: Array, starting_ids: Array) -> Dictionary:
	var pool := []
	for c in available:
		if money >= int((c as Dictionary).get("value", 0)) * 5:
			pool.append(c)
	if pool.is_empty():
		return {}
	var f1 := pool.filter(func(c): return String((c as Dictionary).get("id", "")) in starting_ids)
	if not f1.is_empty():
		pool = f1
	if pool.size() == 1:
		return pool[0]
	var f2 := pool.filter(func(c):
		var cc := c as Dictionary
		return bool(cc.get("has_base_symbol", false)) and power in cc.get("base_allowed_powers", []))
	if not f2.is_empty():
		pool = f2
	if pool.size() == 1:
		return pool[0]
	var best := 0
	for c in pool:
		best = maxi(best, int((c as Dictionary).get("value", 0)))
	pool = pool.filter(func(c): return int((c as Dictionary).get("value", 0)) == best)
	if pool.size() == 1:
		return pool[0]
	return pool[0]


# --- Trade ---

## Money guadagnato da un Trade: 5 per ogni simbolo Export delle Country alleate.
static func trade_gain(export_symbols: int) -> int:
	return maxi(0, export_symbols) * 5

## Money da un Trade calcolato dalle Country alleate dell'Automa (somma dei simboli Export).
func trade_gain_from_allies() -> int:
	var ex := 0
	for c in allied_countries:
		ex += ((c as Dictionary).get("exports", []) as Array).size()
	return Automa.trade_gain(ex)


# --- Stadio 3: Research / Market e Aftermath (Adding Influence) ---

## Punti Research (money) per prendere una carta dal Market: il money dalle 2 carte rivelate
## (sezione Bonus, `bonus_money`) + 1 ogni 3 Country alleate + 2 se l'Automa ha Domestic Focus.
static func research_points(bonus_money: int, allied_count: int, domestic_focus: bool) -> int:
	return bonus_money + int(allied_count / 3) + (2 if domestic_focus else 0)


## Carta scelta dal Market dall'Automa: la piu' COSTOSA che puo' permettersi; a parita' di
## costo usa la `market_priority` per tipo; a parita' ancora la piu' RECENTE (per convenzione
## l'array `market` e' ordinato con index 0 = aggiunta piu' di recente / piu' vicina al mazzo
## Ability). Ogni carta: { ..., "cost": int, "type": "diplomatic|economic|military|domestic" }.
## Ritorna {} se nessuna carta e' accessibile.
static func pick_market_card(market: Array, money: int, market_priority: Array) -> Dictionary:
	var pool := []
	for c in market:
		if int((c as Dictionary).get("cost", 1 << 30)) <= money:
			pool.append(c)
	if pool.is_empty():
		return {}
	var maxc := 0
	for c in pool:
		maxc = maxi(maxc, int((c as Dictionary).get("cost", 0)))
	pool = pool.filter(func(c): return int((c as Dictionary).get("cost", 0)) == maxc)
	if pool.size() == 1:
		return pool[0]
	var best_prio := 1 << 30
	for c in pool:
		var pr: int = market_priority.find(String((c as Dictionary).get("type", "")))
		if pr == -1:
			pr = 1 << 29
		best_prio = mini(best_prio, pr)
	pool = pool.filter(func(c):
		var pr: int = market_priority.find(String((c as Dictionary).get("type", "")))
		if pr == -1:
			pr = 1 << 29
		return pr == best_prio)
	# pool conserva l'ordine di `market`: il primo e' il piu' recente.
	return pool[0]


## Slot dove l'Automa aggiunge Influenza: se e' disponibile UN SOLO tipo, quello; se ENTRAMBI,
## decide la Decision card (`decision_perm` = true -> permanente, false -> temporaneo).
## Ritorna "permanent" | "temporary" | "" (nessuno disponibile).
static func influence_slot_choice(perm_available: bool, temp_available: bool, decision_perm: bool) -> String:
	if perm_available and not temp_available:
		return "permanent"
	if temp_available and not perm_available:
		return "temporary"
	if perm_available and temp_available:
		return "permanent" if decision_perm else "temporary"
	return ""


## Vero se aggiungere Influenza TEMPORANEA spingerebbe fuori un cubo dell'Automa stesso:
## accade quando la fila temporanea e' piena e il cubo piu' a sinistra (primo a uscire, FIFO)
## e' dell'Automa.
func temp_pushes_own(track: InfluenceTrack) -> bool:
	for o in track.temp:
		if o == null:
			return false   # c'e' ancora spazio: nessuno viene spinto fuori
	return track.temp.size() > 0 and String(track.temp[0]) == power


## Decisione completa di Adding Influence (Aftermath) tenendo conto della regola "non spingere
## fuori una propria Influenza temporanea". Ritorna:
##   "permanent" | "temporary" | "permanent_forced" (Hard: permanente anche senza slot) |
##   "redraw" (Normal: scegli un'altra Regione) | "" (niente slot disponibile)
func add_influence_decision(perm_available: bool, temp_available: bool, decision_perm: bool, would_push_own: bool) -> String:
	var choice := Automa.influence_slot_choice(perm_available, temp_available, decision_perm)
	if choice == "temporary" and would_push_own:
		return "permanent_forced" if difficulty_hard else "redraw"
	return choice


# --- Get a Growth Card ---

## VP guadagnati prendendo una Growth card: i VP della carta + VP pari al suo Livello.
static func growth_vp(card_vp: int, level: int) -> int:
	return card_vp + level


# --- Aftermath ---

## Return on Investments: +5 money per ogni FDI token. Ritorna il money guadagnato.
func return_on_investments() -> int:
	var total := 0
	for r in fdi:
		total += int(fdi[r])
	var gained := total * 5
	money += gained
	return gained


## Increase Prosperity: se l'Automa ha il money richiesto dal prossimo spazio della sua
## Prosperity track, lo spende, avanza e guadagna i VP. Ritorna i VP guadagnati (0 se non
## avanza).
func increase_prosperity() -> int:
	var pros: Array = DataLoader.load_automa_players().get(power, {}).get("prosperity", [])
	if prosperity_level >= pros.size():
		return 0
	var step: Dictionary = pros[prosperity_level]
	var cost := int(step.get("cost", 999999))
	if money < cost:
		return 0
	money -= cost
	prosperity_level += 1
	var gained := int(step.get("vp", 0))
	vp += gained
	return gained


# --- Stadio 4b: ESECUZIONE di un turno d'Azione sul GameState condiviso ---
# L'Automa applica le sue azioni DIRETTAMENTE su `gs` (influenza nelle Regioni, Armate sulla
# mappa) e sul PlayerState del suo seggio (money/VP/Country alleate), mentre tiene su di se'
# lo stato extra (cubi azione, FDI/Basi per Regione). Il money e' la fonte di verita' sul
# PlayerState (`p.money`): qui lo si sincronizza in `self.money` per gli helper, e ogni spesa
# aggiorna ENTRAMBI. Semplificazioni dichiarate (vedi docs/automa-rules.md):
#   - Move/Build: scelta della Regione preferendo la zona di interesse, poi una valida (NON il
#     calcolo completo THREAT/Difesa del regolamento).
#   - Improve Relations non aggiunge Influenza (come per i giocatori umani in questo motore).
#   - Get a Growth dell'Automa: per ora +30 money (la conversione costo->money delle Growth e
#     i VP arriveranno con lo step Research/Aftermath dell'Automa).
#   - Trade: solo il guadagno da Export (la Decision card per il commercio reciproco e' a parte).

## Esegue UN turno d'Azione. `card_type` = tipo della carta pescata (diplomatic/economic/
## military/domestic); `region_hints` = Regioni suggerite dalle Auto-Influence card (in ordine
## di pesca, per la ripesca); `country_pool` = tutte le carte Country (per Improve Relations).
## Applica gli effetti e ritorna { action, region, vp, spent, note } per il log.
func take_action(gs, card_type: String, region_hints: Array, country_pool: Array) -> Dictionary:
	var p = gs.player_by_power(power)
	if p == null:
		return {"action": "", "note": "no player"}
	money = int(p.money)
	allied_countries = p.allied_countries
	var dec := board_action_for_type(card_type)
	match String(dec.get("action", "")):
		"improve_relations":
			return _act_improve(gs, p, region_hints, country_pool, dec)
		"engage":
			return _act_engage(gs, p, region_hints, dec)
		"invest":
			return _act_invest(gs, p, region_hints, dec)
		"trade":
			return _act_trade(gs, p, dec)
		"build_base":
			return _act_build(gs, p, dec)
		"move":
			return _act_move(gs, p, dec)
		"get_growth_or_money":
			return _act_domestic(gs, p)
	return {"action": "", "note": "tipo carta sconosciuto: %s" % card_type}


## Spende `amount` money su PlayerState e Automa (mantenendoli allineati).
func _spend(p, amount: int) -> void:
	p.money = int(p.money) - amount
	money = int(p.money)


## Aggiunge `gain` money su PlayerState e Automa.
func _earn(p, gain: int) -> void:
	p.money = int(p.money) + gain
	money = int(p.money)


## Regioni da provare per le azioni con Auto-Influence: prima i suggerimenti (validi), poi le
## restanti Regioni del tabellone (ordine stabile), senza duplicati.
func _ordered_regions(gs, region_hints: Array) -> Array:
	var out := []
	for r in region_hints:
		if gs.regions.has(r) and r not in out:
			out.append(r)
	for r in gs.regions.keys():
		if r not in out:
			out.append(r)
	return out


## Sceglie una Regione tra quelle che soddisfano `ok` (Callable(region)->bool), preferendo la
## zona di interesse dell'Automa; "" se nessuna. (Semplificazione dei criteri THREAT.)
func _pick_region(gs, ok: Callable) -> String:
	var valid := []
	for r in gs.regions.keys():
		if ok.call(r):
			valid.append(r)
	if valid.is_empty():
		return ""
	for r in valid:
		if power in gs.regions[r].get("zone", []):
			return r
	return String(valid[0])


## Aggiunge 1 cubo Influenza dell'Automa nella Regione (slot scelto da InfluenceTrack: permanente
## se libero, altrimenti temporaneo). Accredita i VP immediati al PlayerState. Ritorna i VP.
func _add_influence(gs, p, region: String) -> int:
	if not gs.regions.has(region):
		return 0
	var v: int = gs.regions[region]["track"].add(power, "")
	p.victory_points += v
	return v


# --- Singole azioni ---

func _act_improve(gs, p, region_hints: Array, country_pool: Array, dec: Dictionary) -> Dictionary:
	for r in _ordered_regions(gs, region_hints):
		var cands := _improvable_in(r, country_pool)
		var pick := improve_relations_pick(cands, [])
		if not pick.is_empty():
			var cost := int(pick.get("value", 0)) * 5
			_spend(p, cost)
			var c: Dictionary = (pick as Dictionary).duplicate()
			p.allied_countries.append(c)
			p.exhausted[c.get("id", "")] = false
			apply_cube_move(dec)
			return {"action": "improve_relations", "region": r, "vp": 0, "spent": cost,
				"note": String(c.get("display_name", c.get("id", "")))}
	return _fallback_trade(p, "nessuna Country disponibile")


## Country della Regione che l'Automa puo' allearsi: non gia' alleate, non vietate, e con
## money sufficiente (value*5). Se ha meno di 15 money, considera solo quelle accessibili
## (gia' garantito dal filtro money).
func _improvable_in(region: String, country_pool: Array) -> Array:
	var allied_ids := {}
	for c in allied_countries:
		allied_ids[String((c as Dictionary).get("id", ""))] = true
	var out := []
	for c in country_pool:
		var cc := c as Dictionary
		if String(cc.get("region", "")) != region:
			continue
		if allied_ids.has(String(cc.get("id", ""))):
			continue
		if power in cc.get("no_relations_powers", []):
			continue
		out.append(cc)
	return out


func _act_engage(gs, p, region_hints: Array, dec: Dictionary) -> Dictionary:
	for r in _ordered_regions(gs, region_hints):
		if allies_in_region(r) <= 0:
			continue
		var cost := engage_cost(r, int(gs.regions[r].get("engage_cost", 0)))
		if money >= cost:
			_spend(p, cost)
			var vp := _add_influence(gs, p, r)
			apply_cube_move(dec)
			return {"action": "engage", "region": r, "vp": vp, "spent": cost, "note": ""}
	return _fallback_trade(p, "nessuna Regione per Engage")


func _act_invest(gs, p, region_hints: Array, dec: Dictionary) -> Dictionary:
	for r in _ordered_regions(gs, region_hints):
		if can_invest(r) and money >= 15:
			_spend(p, 15)
			fdi[r] = int(fdi.get(r, 0)) + 1
			var vp := _add_influence(gs, p, r)
			apply_cube_move(dec)
			return {"action": "invest", "region": r, "vp": vp, "spent": 15, "note": ""}
	# Fallback: se ha money ma e' al massimo FDI ovunque -> Improve Relations; se manca il
	# money -> Trade (regolamento).
	if money < 15:
		return _fallback_trade(p, "money insufficiente per Invest")
	return _act_improve(gs, p, region_hints, DataLoader.load_countries(), dec)


func _act_trade(gs, p, _dec: Dictionary) -> Dictionary:
	var gain := trade_gain_from_allies()
	_earn(p, gain)
	return {"action": "trade", "region": "", "vp": 0, "spent": -gain, "note": "+%d money" % gain}


func _fallback_trade(p, why: String) -> Dictionary:
	# Trade come ripiego: sposta i cubi da Trade a Invest (regolamento) e guadagna dall'Export.
	var n := int(action_cubes.get("trade", 0))
	if n > 0:
		apply_cube_move({"cube_from": "trade", "cube_to": "invest", "cube_count": n})
	var gain := trade_gain_from_allies()
	_earn(p, gain)
	return {"action": "trade", "region": "", "vp": 0, "spent": -gain, "note": "ripiego (%s), +%d money" % [why, gain]}


func _act_build(gs, p, dec: Dictionary) -> Dictionary:
	if money < 10:
		return _fallback_trade(p, "money insufficiente per Build")
	var r := _pick_region(gs, func(reg): return can_build_base(reg))
	if r == "":
		# Nessuna Regione costruibile -> Improve Relations (regolamento).
		return _act_improve(gs, p, [], DataLoader.load_countries(), dec)
	_spend(p, 10)
	bases[r] = int(bases.get(r, 0)) + 1
	var a: Dictionary = gs.regions[r]["armies"]
	a[power] = int(a.get(power, 0)) + 1     # 1 Armata nella Regione (Armate gratuite per l'Automa)
	var vp := _add_influence(gs, p, r)
	apply_cube_move(dec)
	return {"action": "build_base", "region": r, "vp": vp, "spent": 10, "note": "+1 Armata"}


func _act_move(gs, p, dec: Dictionary) -> Dictionary:
	if money < 5:
		return _fallback_trade(p, "money insufficiente per Move")
	var r := _pick_region(gs, func(reg): return Actions.move_dest_valid(gs, p, reg))
	if r == "":
		return _fallback_trade(p, "nessuna destinazione valida per Move")
	_spend(p, 5)
	var a: Dictionary = gs.regions[r]["armies"]
	a[power] = int(a.get(power, 0)) + 1
	apply_cube_move(dec)
	return {"action": "move", "region": r, "vp": 0, "spent": 5, "note": "+1 Armata"}


func _act_domestic(_gs, p) -> Dictionary:
	# Get a Growth Card se possibile, altrimenti +30 money. Per ora: +30 money (la presa di
	# una Growth card con conversione costo->money arriva con lo step Research dell'Automa).
	_earn(p, 30)
	return {"action": "domestic", "region": "", "vp": 0, "spent": -30, "note": "+30 money"}
