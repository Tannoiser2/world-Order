extends SceneTree
## Runner headless dei test del motore.
## Uso: godot --headless --path game --script res://scripts/tests/run_tests.gd

func _init() -> void:
	var r := EngineTests.run_all()
	print("== World Order — Engine tests ==")
	for line in r["log"]:
		print(line)
	print("Passati: %d  Falliti: %d" % [r["passed"], r["failed"]])
	quit(1 if r["failed"] > 0 else 0)
