class_name EffectExecutor
extends RefCounted
## Esegue l'effetto di una carta come sequenza di operazioni (micro-DSL).
## Ogni op = { "op": String, ... }. I target che richiedono una scelta del
## giocatore (Paese, Regione, slot, quantita') sono gia' risolti nei parametri
## dell'op: in partita li riempie la UI (input umano) o il bot; nei test sono
## forniti direttamente. Cosi' il motore resta puro e deterministico.

## Esegue una lista di op per un giocatore. Ritorna un riepilogo (vp guadagnati).
static func run(gs: GameState, owner: String, ops: Array) -> Dictionary:
	var p := gs.player_by_power(owner)
	var summary := {"vp": 0, "ok": true}
	if p == null:
		summary["ok"] = false
		return summary
	for op in ops:
		_exec_one(gs, p, op, summary)
	return summary


static func _exec_one(gs: GameState, p: PlayerState, op: Dictionary, summary: Dictionary) -> void:
	match String(op.get("op", "")):
		"improve_relations":
			Actions.execute_improve_relations(gs, p.power, op.get("country", {}), op.get("exhaust_values", []))
		"engage":
			var vp := Actions.execute_engage(gs, p.power, String(op.get("region", "")),
				op.get("exhaust_values", []), p.focus == WO.Focus.DIPLOMATIC, String(op.get("slot", "")))
			if vp > 0: summary["vp"] += vp
		"invest":
			var vp := Actions.execute_invest(gs, p.power, op.get("country", {}), String(op.get("slot", "")))
			if vp > 0: summary["vp"] += vp
		"trade":
			var gain := Actions.export_gain(op.get("exports", []))
			var cost := Actions.import_cost(op.get("imports", []))
			p.money += gain - cost
		"move":
			Actions.execute_move(gs, p.power, op.get("moves", []))
		"build_base":
			var vp := Actions.execute_build_base(gs, p.power, op.get("country", {}),
				int(op.get("armies", 0)), String(op.get("slot", "")))
			if vp > 0: summary["vp"] += vp
		"get_growth":
			Actions.execute_get_growth(p, op.get("card", {}), int(op.get("next_level", 1)))
		"produce":
			for rtype in op.get("types", []):
				Actions.execute_produce(p, String(rtype), int(op.get("amount", -1)))
		"gain_money":
			p.money += int(op.get("amount", 0))
		"gain_resource":
			p.gain_resource(String(op.get("type", "")), int(op.get("amount", 0)), int(op.get("import_cost", 0)))
		"gain_armies":
			p.armies_available += int(op.get("amount", 0))
		"gain_vp":
			p.victory_points += int(op.get("amount", 0))
			summary["vp"] += int(op.get("amount", 0))
		"choice":
			# il giocatore (UI/bot) ha gia' scelto: op["chosen"] = sotto-effetto.
			var chosen: Variant = op.get("chosen", null)
			if chosen is Array:
				for sub in chosen:
					_exec_one(gs, p, sub, summary)
			elif chosen is Dictionary:
				_exec_one(gs, p, chosen, summary)
		_:
			push_warning("EffectExecutor: op sconosciuta '%s'" % op.get("op", ""))
