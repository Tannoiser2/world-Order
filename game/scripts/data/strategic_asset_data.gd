class_name StrategicAssetData
extends CardData
## Carta Strategic Asset: asset unico, effetto potente, usabile una sola volta.

## Potenza proprietaria.
@export var power: WO.Power = WO.Power.USA

## Punti vittoria iniziali (sommati nel setup per la posizione di partenza).
@export var starting_vp: int = 0

## Effetto della carta, come passi del micro-DSL.
@export var effect: Array[EffectStep] = []
