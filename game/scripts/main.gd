extends Node
## Scena di avvio provvisoria (Fase 0): smoke test che carica il manifest delle
## carte estratte e ne stampa il conteggio per tipo. Verra' sostituita dalla
## vera scena di gioco nelle fasi successive.

const MANIFEST_PATH := "res://data/cards_manifest.json"

func _ready() -> void:
	var path := MANIFEST_PATH
	if not FileAccess.file_exists(path):
		push_warning("Manifest non trovato: %s" % path)
		return
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Manifest non valido")
		return
	var by_type := {}
	for card in data.get("cards", []):
		var t: String = card.get("type", "?")
		by_type[t] = int(by_type.get(t, 0)) + 1
	print("World Order — carte nel manifest: %d" % int(data.get("count", 0)))
	for t in by_type:
		print("  %s: %d" % [t, by_type[t]])
