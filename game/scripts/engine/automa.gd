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


# --- Trade ---

## Money guadagnato da un Trade: 5 per ogni simbolo Export delle Country alleate.
static func trade_gain(export_symbols: int) -> int:
	return maxi(0, export_symbols) * 5


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
