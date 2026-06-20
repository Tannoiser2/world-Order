class_name CardData
extends Resource
## Classe base di tutte le carte. Le sottoclassi aggiungono i campi specifici.

## Identificatore stabile (corrisponde all'id nel manifest, es. "ability_007").
@export var id: String = ""

## Nome visualizzato della carta (es. "Optimization Program").
@export var display_name: String = ""

## Percorso dell'immagine della carta (res:// verso game/assets/cards/...).
@export var art_path: String = ""
