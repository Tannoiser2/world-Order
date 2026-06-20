class_name GameState
extends RefCounted
## Stato di gioco completo e serializzabile (nessun nodo di scena).
## Scheletro della Fase 1: i campi rispecchiano §4 della ROADMAP.
## L'obiettivo e' un motore di regole PURO, testabile e riproducibile,
## separato dalla UI (la scena fa solo da renderer + input).

## Numero di giocatori (2-4).
var player_count: int = 2

## Round corrente (1..6).
var round: int = 1

## Fase corrente.
var phase: WO.Phase = WO.Phase.PREPARATION

## Indice del giocatore di turno nell'ordine corrente.
var active_seat: int = 0

## Ordine di turno: lista di indici giocatore.
var turn_order: Array[int] = []

## Stato per giocatore (vedi PlayerState piu' avanti nello sviluppo).
var players: Array = []

## Riserva comune (supply): monete, basi, FDI, cubi influenza, ecc.
var supply: Dictionary = {}

## Market: carte attualmente disponibili all'acquisto.
var market: Array = []

## Stato delle Regioni (influenza, armate, token).
var regions: Dictionary = {}


## Avanza la macchina a stati delle fasi/round.
## Da implementare in Fase 1 (vedi ROADMAP §5).
func advance_phase() -> void:
	push_warning("GameState.advance_phase(): da implementare in Fase 1")


## Restituisce le mosse legali per il giocatore di turno.
## Sara' usato sia dalla UI sia dal bot (Fase 4).
func legal_moves() -> Array:
	push_warning("GameState.legal_moves(): da implementare in Fase 1")
	return []


## Applica una mossa validata e ritorna se ha avuto successo.
func apply_move(_move: Dictionary) -> bool:
	push_warning("GameState.apply_move(): da implementare in Fase 1")
	return false
