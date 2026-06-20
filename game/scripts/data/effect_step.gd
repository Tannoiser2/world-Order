class_name EffectStep
extends Resource
## Un singolo "passo" dell'effetto di una carta, in forma di micro-DSL eseguibile
## dal motore di regole. La logica Lua del prototipo Tabletop Simulator e' la
## guida di riferimento per il set di operazioni e i comportamenti corretti.
##
## Esempi (come dati):
##   { op = "produce", params = { count = 1, choose = true } }
##   { op = "gain_money", params = { amount = 10 } }
##   { op = "add_influence", params = { region = "current", amount = 1 } }
##   { op = "get_growth_card", params = {} }

## Operazione (verbo) del passo. Vedi docs/effects.md per il vocabolario completo.
@export var op: String = ""

## Parametri dell'operazione (chiavi/valori dipendono da `op`).
@export var params: Dictionary = {}
