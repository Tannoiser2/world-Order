extends SceneTree
## Demo headless: simula una partita e stampa il resoconto.
## Uso: godot --headless --path game --script res://scripts/tests/demo_game.gd

func _init() -> void:
	print("== World Order — demo simulazione ==")
	var r := GameRunner.run_game_logged(["usa", "china", "russia", "eu"], 7)
	for line in r["log"]:
		print(line)
	quit(0)
