class_name WO
extends RefCounted
## Enumerazioni condivise del dominio di gioco di World Order.
## Usato come namespace: es. WO.Power.USA, WO.ResourceType.ENERGY.

## Le quattro potenze giocabili.
enum Power { USA, CHINA, RUSSIA, EU }

## I 7 tipi di risorsa: 3 primarie + 4 secondarie.
enum ResourceType {
	ENERGY,          ## primaria
	RAW_MATERIALS,   ## primaria
	FOOD,            ## primaria
	CONSUMER_GOODS,  ## secondaria
	SERVICES,        ## secondaria
	DIPLOMACY,       ## secondaria
	ARMIES,          ## secondaria
}

## Focus scelto a inizio round.
enum Focus { DOMESTIC, DIPLOMATIC, MILITARY }

## Le 8 azioni della fase di Azione.
enum ActionType {
	IMPROVE_RELATIONS,  ## Diplomatic
	ENGAGE,             ## Diplomatic
	TRADE,              ## Economic
	INVEST,             ## Economic
	MOVE,               ## Military
	BUILD_BASE,         ## Military
	GET_GROWTH,         ## Domestic
	PRODUCE,            ## Domestic
}

## Colore/tipo della carta Ability (bordo laterale).
enum CardColor { DIPLOMATIC, ECONOMIC, MILITARY, DOMESTIC }

## Le Regioni del tabellone (i nomi esatti vanno confermati in trascrizione).
enum Region {
	AMERICAS,
	EUROPE,
	MIDDLE_EAST_NORTH_AFRICA,
	AFRICA,
	CENTRAL_ASIA,
	SOUTH_ASIA,
	EAST_ASIA_PACIFIC,
}

## Le 3 fasi di ogni round.
enum Phase { PREPARATION, ACTION, AFTERMATH }
