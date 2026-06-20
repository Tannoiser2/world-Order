class_name GrowthCardData
extends CardData
## Carta Growth: miglioramenti all'infrastruttura, con abilita' continuative
## che si attivano al round pari al loro Livello.

## Livello (1..N): determina quando l'abilita' diventa attiva.
@export var level: int = 1

## Costo come mappa risorsa->quantita' e/o monete.
## Es. { "money": 15, "consumer_goods": 3 }.
@export var cost: Dictionary = {}

## Punti vittoria guadagnati al momento dell'acquisto.
@export var victory_points: int = 0

## Bonus immediato all'acquisto (es. guadagna risorse), come passi del DSL.
@export var on_acquire: Array[EffectStep] = []

## Testo dell'abilita' continuativa (da codificare in regole nel motore).
@export var ability_text: String = ""
