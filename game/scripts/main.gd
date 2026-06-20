extends Node
## Scena di avvio (Fase 0/1): esegue i test del motore e un riepilogo del dataset.
## Verra' sostituita dalla vera scena di gioco nelle fasi successive.

func _ready() -> void:
	# Smoke test del motore (esempi del regolamento).
	var r := EngineTests.run_all()
	print("== World Order — Engine tests ==")
	for line in r["log"]:
		print(line)
	print("Passati: %d  Falliti: %d" % [r["passed"], r["failed"]])

	# Riepilogo carte dal manifest.
	var path := "res://data/cards_manifest.json"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) == TYPE_DICTIONARY:
			print("Carte nel manifest: %d" % int(data.get("count", 0)))
