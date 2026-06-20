class_name CountryCardData
extends CardData
## Carta Country: rappresenta un Paese con cui interagire.

## Regione di appartenenza.
@export var region: WO.Region = WO.Region.AMERICAS

## Valore del Paese (esagono in alto a sinistra): usato per costi/sconti.
@export var value: int = 1

## Costo in monete per fare Invest in questo Paese.
@export var invest_cost: int = 0

## Risorse che puoi esportare (vendere) grazie a questo Paese.
@export var exports: Array[WO.ResourceType] = []

## Risorse che puoi importare (comprare) grazie a questo Paese.
@export var imports: Array[WO.ResourceType] = []

## Potenze che NON possono migliorare le relazioni con questo Paese
## (bandiera barrata in alto a destra). Valori = WO.Power.
@export var no_relations_powers: Array[int] = []

## Potenze che possono costruire una Base qui (bandiera sotto il simbolo Base).
@export var base_allowed_powers: Array[int] = []

## Vero se la carta mostra il simbolo Base militare.
@export var has_base_symbol: bool = false

## Se e' un Paese iniziale di una potenza, quale (-1 = Paese della mappa).
@export var starting_for_power: int = -1
