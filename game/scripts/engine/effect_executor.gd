class_name EffectExecutor
extends RefCounted
## Esegue l'effetto di una carta come sequenza di operazioni (micro-DSL).
## Ogni op = { "op": String, ... }. I target che richiedono una scelta del
## giocatore (Paese, Regione, slot, quantita') sono risolti nei parametri
## dell'op: in partita li riempie la UI/bot; nei test sono forniti direttamente.
## Le op contestuali senza target risolto vengono differite (no-op sicuro) e
## conteggiate in summary["deferred"], cosi' l'esecuzione non fallisce mai.

## Op riconosciute (per il conteggio di copertura/deferred).
const KNOWN := [
	"improve_relations", "engage", "invest", "trade", "move", "build_base",
	"get_growth", "produce", "gain_money", "gain_resource", "gain_armies",
	"gain_vp", "choice", "choose_n", "draw", "play_another", "trash",
	"ready_country", "reset_influence", "convert_influence", "increase_production",
	"add_influence", "sell_armies", "place_armies", "spend", "noop", "ongoing",
	"gain_money_per_fdi", "move_free", "move_to_regions", "repeat", "spend_for_gain",
	"spend_then", "discard", "research_free", "increase_prosperity",
	"remove_enemy_army", "deploy_force", "invest_foreign", "copy_opponent_card",
	"regime_change", "brics", "swap_influence", "aid_econ_military",
	"surplus_regional_influence", "china_prosperity_engage", "eu_foreign_policy",
]


static func run(gs: GameState, owner: String, ops: Array) -> Dictionary:
	var p := gs.player_by_power(owner)
	var summary := {"vp": 0, "ok": true, "extra_plays": 0, "ongoing": [], "deferred": 0, "unknown": 0}
	if p == null:
		summary["ok"] = false
		return summary
	for op in ops:
		_exec_one(gs, p, op, summary)
	return summary


static func _exec_one(gs: GameState, p: PlayerState, op: Dictionary, summary: Dictionary) -> void:
	var name := String(op.get("op", ""))
	if name not in KNOWN:
		summary["unknown"] += 1
		return
	match name:
		"improve_relations":
			Actions.execute_improve_relations(gs, p.power, op.get("country", {}), op.get("exhaust_values", []))
		"engage":
			if op.has("region"):
				var vp := Actions.execute_engage(gs, p.power, String(op["region"]),
					op.get("exhaust_values", []), p.focus == WO.Focus.DIPLOMATIC, String(op.get("slot", "")))
				if vp > 0: summary["vp"] += vp
			else:
				summary["deferred"] += 1
		"invest":
			if op.has("country"):
				var vp := Actions.execute_invest(gs, p.power, op["country"], String(op.get("slot", "")))
				if vp > 0: summary["vp"] += vp
			else:
				summary["deferred"] += 1
		"trade":
			# Export: cedi la risorsa (solo quella che hai) e incassi money.
			var gain := 0
			for t in (op.get("exports", []) as Array):
				var ty := String(t["type"])
				var q: int = mini(int(t["qty"]), int(p.resources.get(ty, 0)))
				p.resources[ty] = int(p.resources.get(ty, 0)) - q
				gain += int(Actions.EXPORT_GAIN.get(ty, 0)) * q
			p.money += gain
			# Import: paghi money (se basta) e ricevi la risorsa.
			for t in (op.get("imports", []) as Array):
				var ty := String(t["type"])
				var q := int(t["qty"])
				var c: int = int(Actions.IMPORT_COST.get(ty, 0)) * q
				if p.money >= c:
					p.money -= c
					p.gain_resource(ty, q, 0)
		"move":
			if op.has("moves"):
				Actions.execute_move(gs, p.power, op["moves"])
			else:
				summary["deferred"] += 1
		"build_base":
			if op.has("country"):
				var vp := Actions.execute_build_base(gs, p.power, op["country"], int(op.get("armies", 0)), String(op.get("slot", "")))
				if vp > 0: summary["vp"] += vp
			else:
				summary["deferred"] += 1
		"get_growth":
			if op.has("card"):
				Actions.execute_get_growth(p, op["card"], int(op.get("next_level", 1)))
			else:
				summary["deferred"] += 1
		"produce":
			if op.has("types"):
				for rtype in op["types"]:
					Actions.execute_produce(p, String(rtype), int(op.get("amount", -1)))
			else:
				summary["deferred"] += 1  # "Produce N tipi": scelta dei tipi a runtime
		"gain_money":
			p.money += int(op.get("amount", 0))
		"gain_resource":
			p.gain_resource(String(op.get("type", "")), int(op.get("amount", 0)), int(op.get("import_cost", 0)))
		"gain_armies":
			p.armies_available += int(op.get("amount", 0))
		"gain_vp":
			p.victory_points += int(op.get("amount", 0))
			summary["vp"] += int(op.get("amount", 0))
		"spend":
			var cost := {}
			for k in ["money", "energy", "raw_materials", "food", "consumer_goods", "services", "diplomacy"]:
				if op.has(k): cost[k] = int(op[k])
			p.spend(cost)
		"draw":
			p.draw_cards(int(op.get("n", 1)))
		"play_another":
			summary["extra_plays"] += 1
		"ongoing":
			summary["ongoing"].append(String(op.get("tag", "")))
		"sell_armies":
			var n := int(op.get("n", 0))
			if p.armies_available >= n:
				p.armies_available -= n
				p.money += int(op.get("money", 0))
		"gain_money_per_fdi":
			# Guadagna `amount` money per ogni segnalino FDI sulle Country alleate.
			p.money += int(op.get("amount", 0)) * p.fdi_countries.size()
		"add_influence":
			if op.has("region") and gs.regions.has(op["region"]):
				var slot := "permanent" if bool(op.get("permanent", false)) else ""
				var vp: int = gs.regions[op["region"]]["track"].add(p.power, slot)
				p.victory_points += vp
				summary["vp"] += vp
			else:
				summary["deferred"] += 1
		"place_armies":
			if op.has("region") and gs.regions.has(op["region"]):
				var a: Dictionary = gs.regions[op["region"]]["armies"]
				a[p.power] = int(a.get(p.power, 0)) + int(op.get("n", 0))
			else:
				summary["deferred"] += 1
		"choice", "choose_n":
			var chosen: Variant = op.get("chosen", null)
			if chosen is Array:
				for sub in chosen: _exec_one(gs, p, sub, summary)
			elif chosen is Dictionary:
				_exec_one(gs, p, chosen, summary)
			else:
				summary["deferred"] += 1  # scelta non ancora risolta
		"repeat":
			var times := int(op.get("times", 1))
			for _i in times:
				for sub in op.get("body", []):
					_exec_one(gs, p, sub, summary)
		"spend_then":
			p.spend({"money": int(op.get("money", 0))})
			for sub in op.get("then", []):
				_exec_one(gs, p, sub, summary)
		_:
			# op riconosciuta ma contestuale/avanzata: differita (gestita da UI/regole dedicate).
			summary["deferred"] += 1
