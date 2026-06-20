class_name RegionData
extends Resource
## Definizione di una Regione del tabellone.

@export var region: WO.Region = WO.Region.AMERICAS
@export var display_name: String = ""

## Potenze la cui zona di interesse include questa Regione (bandiere sul board).
@export var zone_of_interest: Array[int] = []  # WO.Power

## Costo in Diplomacy per l'azione Engage qui.
@export var engage_cost: int = 0

## Valori VP degli slot Influenza PERMANENTI (sopra la linea), da sinistra.
@export var permanent_slots: Array[int] = []

## Valori VP degli slot Influenza TEMPORANEI (sotto la linea), da sinistra.
@export var temporary_slots: Array[int] = []

## Influenza locale iniziale (cubi neri) presente nella Regione, se presente.
@export var starting_local_influence: int = 0
