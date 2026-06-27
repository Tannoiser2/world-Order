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
var deck: Array = []                   # mazzo Ability (12): si usa il TIPO, non l'effetto
var difficulty_hard: bool = false


## Crea un Automa per `power` dai dati della Player card. difficulty: "normal"|"hard".
static func from_setup(power: String, difficulty: String = "normal") -> Automa:
	var a := Automa.new()
	a.power = power
	var pdata: Dictionary = DataLoader.load_automa_players().get(power, {})
	a.money = int(pdata.get("starting_money", 0))
	a.focus = WO.Focus.DOMESTIC
	a.vp = 10
	a.difficulty_hard = (difficulty == "hard")
	return a


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
