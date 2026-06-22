class_name GameConfig
extends RefCounted
## Configurazione della partita scelta nel menu, letta dalla scena di gioco.
## Static = condivisa tra le scene (semplice; in futuro un Autoload o un
## oggetto passato esplicitamente).

static var player_count: int = 2
static var mode: String = "hotseat"   # "hotseat" | "online"
## Sessione di rete attiva (lobby online): la board la prende per host/client.
## È un Node tenuto in get_tree().root così sopravvive al cambio scena. null = locale.
static var net: NetSession = null
## Potenze in gioco. In 2 giocatori il regolamento impone: una tra USA/EU e una
## tra Russia/China. Default coerente; la scelta esplicita verra' aggiunta dopo.
static var powers: Array = ["usa", "china", "russia", "eu"]


## Ritorna le potenze per il numero di giocatori scelto (default sensati,
## coerenti col vincolo del 2 giocatori: seggio 0 USA/UE, seggio 1 Russia/Cina).
static func powers_for_count() -> Array:
	return powers_for_count_n(player_count)


static func powers_for_count_n(n: int) -> Array:
	match n:
		2: return ["usa", "china"]
		3: return ["usa", "china", "russia"]
		_: return ["usa", "china", "russia", "eu"]
