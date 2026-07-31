class_name SaveGame
extends RefCounted
## Salvataggio e ripresa della partita (una partita dura 6 round: serve poterla interrompere).
##
## Il file sta in `user://` — su desktop/Android è una cartella vera, sul WEB (la build PWA su
## iPad) Godot la mappa su IndexedDB, quindi il salvataggio sopravvive alla chiusura della
## scheda. È un JSON leggibile: `gs` (lo stato di gioco già serializzabile, GameState.to_dict)
## + `view` (lo stato che vive nella Vista e non in GameState: mazzi Country/Market scoperti,
## carte Commercio girate, abilità 1x/round usate, Registro, stato dei bot...).
##
## SI SALVA SOLO IN UN PUNTO PULITO (vedi board_view._can_save): niente carta in risoluzione,
## niente popup/scelta aperta. Motivo: quelle scelte vivono come `Callable` (callback), che non
## sono serializzabili — salvarle a metà darebbe una ripresa monca. Fuori da quei momenti lo
## stato è interamente dati, quindi il round-trip è fedele.

const PATH := "user://savegame.json"
const FORMAT := 1


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func delete_save() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)   # DirAccess risolve da sé "user://"


## Scrive il salvataggio. `gs_dict` da GameState.to_dict(), `view` dalla Vista, `config` le
## potenze/bot scelti nel menu. Ritorna true se il file è stato scritto davvero.
static func save(gs_dict: Dictionary, view: Dictionary, config: Dictionary, app_version := "") -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Salvataggio non riuscito: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify({
		"format": FORMAT,
		"app_version": app_version,
		"saved_unix": Time.get_unix_time_from_system(),
		"gs": gs_dict,
		"view": view,
		"config": config,
	}))
	f.close()
	return true


## Legge il salvataggio. {} se assente, illeggibile o di un formato più recente (non si prova
## a interpretare a caso un file che non si capisce: meglio dirlo che ripartire corrotti).
static func load_save() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var d: Variant = JSON.parse_string(txt)
	if not (d is Dictionary):
		return {}
	var dd: Dictionary = d
	if int(dd.get("format", 0)) > FORMAT:
		push_warning("Salvataggio di una versione più recente del gioco: ignorato.")
		return {}
	if not (dd.get("gs") is Dictionary):
		return {}
	return dd


## Riga descrittiva per il menu ("Round 3 · 4 giocatori · v0.7.171"). "" se non c'è salvataggio.
static func describe() -> String:
	var d := load_save()
	if d.is_empty():
		return ""
	var gs: Dictionary = d.get("gs", {})
	var players: Array = gs.get("players", [])
	var names := []
	for p in players:
		names.append(String((p as Dictionary).get("power", "?")).to_upper())
	var parts := ["Round %d" % int(gs.get("round", 1))]
	if not names.is_empty():
		parts.append(", ".join(names))
	var av := String(d.get("app_version", ""))
	if av != "":
		parts.append(av)
	return "  ·  ".join(parts)
