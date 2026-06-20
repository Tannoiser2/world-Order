class_name PowerData
extends Resource
## Definizione di una potenza giocabile (USA, Cina, Russia, UE).

@export var power: WO.Power = WO.Power.USA
@export var display_name: String = ""

## Testo dell'abilita' speciale (es. Member of NATO, Global Superpower Status).
@export var special_ability_text: String = ""

## Monete iniziali.
@export var starting_money: int = 0

## Produzione iniziale per tipo di risorsa: ResourceType(int) -> livello.
@export var starting_production: Dictionary = {}

## Numero di Army token iniziali.
@export var starting_armies: int = 0
