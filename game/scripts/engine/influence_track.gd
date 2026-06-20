class_name InfluenceTrack
extends RefCounted
## Gestione dell'Influenza di una Regione: slot permanenti (sopra la linea) e
## temporanei (sotto la linea, FIFO da sinistra). Logica validata contro gli
## esempi del regolamento. Owner = String (colore potenza, es. "usa", o "local").

var perm_values: Array[int] = []     # VP di ciascuno slot permanente
var temp_values: Array[int] = []     # VP di ciascuno slot temporaneo
var perm: Array = []                 # owner (String) oppure null
var temp: Array = []                 # owner (String) oppure null, FIFO da sinistra


func _init(permanent_values: Array, temporary_values: Array) -> void:
	for v in permanent_values:
		perm_values.append(int(v))
		perm.append(null)
	for v in temporary_values:
		temp_values.append(int(v))
		temp.append(null)


## Aggiunge 1 Influenza. slot_type: "permanent", "temporary" o "" (auto).
## Ritorna i VP immediati guadagnati.
func add(owner: String, slot_type: String = "") -> int:
	if slot_type == "" or slot_type == "permanent":
		for i in perm.size():
			if perm[i] == null:
				perm[i] = owner
				return perm_values[i]
		if slot_type == "permanent":
			# effetto che forza un permanente anche senza slot disponibile
			perm.append(owner)
			perm_values.append(0)
			return 0
		# auto: nessun permanente libero -> passa ai temporanei
	# slot temporaneo: primo libero da sinistra
	for i in temp.size():
		if temp[i] == null:
			temp[i] = owner
			return temp_values[i]
	# tutti pieni: rimuovi il piu' a sinistra, shift, aggiungi a destra (0 VP)
	temp.pop_front()
	temp.append(owner)
	return 0


## Converte una Influenza temporanea dell'owner in permanente (senza VP).
## I cubi temporanei a destra scorrono di uno verso sinistra.
func convert_temp_to_permanent(owner: String) -> bool:
	var idx := temp.find(owner)
	if idx == -1:
		return false
	temp.remove_at(idx)   # i cubi a destra scorrono a sinistra
	temp.append(null)     # mantiene la dimensione della fila
	# colloca in permanente (slot libero, altrimenti forza oltre la linea)
	for i in perm.size():
		if perm[i] == null:
			perm[i] = owner
			return true
	perm.append(owner)
	perm_values.append(0)
	return true


## Reset: "protegge" un cubo temporaneo spostandolo all'ultima posizione libera.
func reset_temporary(owner: String) -> bool:
	var idx := temp.find(owner)
	if idx == -1:
		return false
	# se non c'e' nulla a destra, il reset non ha effetto
	var has_right := false
	for i in range(idx + 1, temp.size()):
		if temp[i] != null:
			has_right = true
			break
	if not has_right:
		return false
	temp.remove_at(idx)
	temp.append(null)
	# reinserisci nel primo slot libero da sinistra
	for i in temp.size():
		if temp[i] == null:
			temp[i] = owner
			return true
	return true


## Vero se tutti gli slot permanenti sono occupati (requisito per lo scoring).
func all_permanent_filled() -> bool:
	for o in perm:
		if o == null:
			return false
	return true


## Conta l'Influenza totale (permanente + temporanea) di un owner.
func count(owner: String) -> int:
	var n := 0
	for o in perm:
		if o == owner:
			n += 1
	for o in temp:
		if o == owner:
			n += 1
	return n


## Insieme di tutti gli owner presenti (inclusi i "local").
func owners() -> Array:
	var s := {}
	for o in perm:
		if o != null:
			s[o] = true
	for o in temp:
		if o != null:
			s[o] = true
	return s.keys()
