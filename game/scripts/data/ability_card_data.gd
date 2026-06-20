class_name AbilityCardData
extends CardData
## Carta Ability: il mezzo principale per eseguire azioni.
## Include sia le carte iniziali (per potenza) sia quelle del Market.

## Colore/tipo (Diplomatic / Economic / Military / Domestic).
@export var color: WO.CardColor = WO.CardColor.DOMESTIC

## Costo in monete per acquistarla dal Market (0 per le carte iniziali).
@export var market_cost: int = 0

## Effetto della carta, come sequenza di passi del micro-DSL.
@export var effect: Array[EffectStep] = []

## Bonus di Research mostrato in basso (usato nella fase Research).
@export var research_bonus: int = 0

## Bonus superiore guadagnato quando rivelata in Research (es. monete/risorse).
## Modellato come passi per uniformita'.
@export var research_top_bonus: Array[EffectStep] = []

## Se appartiene al mazzo iniziale di una potenza, quale.
## (-1 = carta del Market, non legata a una potenza)
@export var starting_for_power: int = -1

## Vero se e' una delle carte iniziali "suggerite" (freccia prima del nome).
@export var suggested_starting: bool = false
