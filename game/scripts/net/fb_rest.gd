## Collegamento a Firebase (Realtime Database) per il gioco online.
## Usa solo le chiamate web standard (REST), quindi funziona sia nell'app sia nella versione web.
## Accesso anonimo: ogni dispositivo riceve un identificativo, senza registrazione.
##
## Stesso modulo usato da Ultimo chilometro, Snow Tails e STATUS (stesso progetto Firebase):
## qui serve solo come trasporto REST per NetSession (vedi net_session.gd, trasporto FIREBASE).
class_name FbRest
extends Node

# Configurazione pubblica del progetto Firebase del gioco (non è un segreto: la protezione la fanno
# le regole del database, in firebase/database.rules.json).
const API_KEY := "AIzaSyCf1NQodB-J3OrdU_gHYQ1I6VJtXBk1ciU"
const DB_URL := "https://flammerouge-f8669-default-rtdb.europe-west1.firebasedatabase.app"
const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key="
const CODE_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"
## Radice del gioco nel database (gli altri giochi usano rooms, snowtails/rooms, status/rooms).
const ROOT := "worldorder/rooms"

var db_url := DB_URL
var auth_url := AUTH_URL + API_KEY
var refresh_url := REFRESH_URL + API_KEY
var uid := ""
var id_token := ""
var refresh_token := ""
var token_at := 0.0
var last_error := ""
var last_room := {}

func _init() -> void:
	# per le prove automatiche si può puntare a un finto Firebase locale
	var test_db := OS.get_environment("WO_DB_URL")
	if OS.has_feature("web"):
		# nella versione web: ?wodb=<indirizzo> nella pagina
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('wodb') || ''")
		test_db = str(q) if q != null else ""
		if test_db != "":
			var base := test_db.get_base_dir()
			OS.set_environment("WO_AUTH_URL", base + "/signup")
			OS.set_environment("WO_REFRESH_URL", base + "/refresh")
	if test_db != "":
		db_url = test_db
		auth_url = OS.get_environment("WO_AUTH_URL")
		refresh_url = OS.get_environment("WO_REFRESH_URL")

const RESULT_NAMES := {
	HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: "risposta incompleta",
	HTTPRequest.RESULT_CANT_CONNECT: "connessione rifiutata",
	HTTPRequest.RESULT_CANT_RESOLVE: "indirizzo del server non trovato",
	HTTPRequest.RESULT_CONNECTION_ERROR: "connessione interrotta o bloccata",
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "errore di sicurezza TLS",
	HTTPRequest.RESULT_NO_RESPONSE: "nessuna risposta",
	HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: "risposta troppo grande",
	HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: "risposta compressa illeggibile",
	HTTPRequest.RESULT_REQUEST_FAILED: "richiesta bloccata (CORS o rete)",
	HTTPRequest.RESULT_TIMEOUT: "tempo scaduto",
}

## Una richiesta HTTP: restituisce {code, data}. code 0 = rete non raggiungibile.
## Se la rete fa le bizze riprova una volta; last_error dice quale passo è fallito e perché.
func _request(method: int, url: String, body = null, form := false) -> Dictionary:
	var r := await _request_once(method, url, body, form)
	if r["code"] == 0:
		await get_tree().create_timer(1.0).timeout
		r = await _request_once(method, url, body, form)
	return r

func _request_once(method: int, url: String, body = null, form := false) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	# nel browser la risposta arriva già decompressa: se Godot ci riprova fallisce (errore 8)
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded" if form else "Content-Type: application/json"])
	var payload := ""
	if body != null:
		payload = body if form else JSON.stringify(body)
	var where := _where(url)
	var err := http.request(url, headers, method, payload)
	if err != OK:
		http.queue_free()
		last_error = "%s: richiesta non partita, errore %d" % [where, err]
		push_warning("Net " + last_error)
		return {"code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else null
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		last_error = "%s: %s [%d]" % [where, RESULT_NAMES.get(res[0], "rete non raggiungibile"), res[0]]
		push_warning("Net " + last_error)
		return {"code": 0, "data": null}
	if code >= 300:
		var msg := text.substr(0, 160)
		if data is Dictionary and data.get("error") is Dictionary:
			msg = str(data["error"].get("message", msg))
		elif data is Dictionary and data.has("error"):
			msg = str(data["error"])
		last_error = "%s: errore %d, %s" % [where, code, msg]
		push_warning("Net " + last_error)
	return {"code": code, "data": data}

## Nome breve del passo, per i messaggi d'errore.
func _where(url: String) -> String:
	if url.begins_with(auth_url.get_slice("?", 0)):
		return "accesso anonimo"
	if url.begins_with(refresh_url.get_slice("?", 0)):
		return "rinnovo accesso"
	return "database"

const SESSION_FILE := "user://online_firebase.cfg"
## Prefisso delle chiavi del browser (sessionStorage), distinto da quello di Ultimo chilometro.
const WEB_PREFIX := "wo_"

## Accesso anonimo (una volta per sessione). L'identità si conserva sul dispositivo:
## chi ricarica la pagina o riapre il gioco resta lo stesso giocatore e può rientrare nella sua stanza.
func sign_in() -> bool:
	if id_token != "":
		return await _fresh()
	var saved := load_session()
	if saved.get("refresh", "") != "":
		var rr := await _request(HTTPClient.METHOD_POST, refresh_url, "grant_type=refresh_token&refresh_token=" + str(saved["refresh"]).uri_encode(), true)
		if rr["code"] == 200 and rr["data"] is Dictionary and rr["data"].get("id_token", "") != "":
			id_token = rr["data"]["id_token"]
			refresh_token = rr["data"].get("refresh_token", saved["refresh"])
			uid = rr["data"].get("user_id", saved.get("uid", ""))
			token_at = Time.get_unix_time_from_system()
			_save({"refresh": refresh_token, "uid": uid})
			return true
	var r := await _request(HTTPClient.METHOD_POST, auth_url, {"returnSecureToken": true})
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return false
	id_token = r["data"].get("idToken", "")
	refresh_token = r["data"].get("refreshToken", "")
	uid = r["data"].get("localId", "")
	token_at = Time.get_unix_time_from_system()
	_save({"refresh": refresh_token, "uid": uid})
	return id_token != ""

## Dati salvati sul dispositivo: identità, ultima stanza (codice e posto), nome.
## Nel browser identità e stanza stanno nella scheda (sessionStorage): sopravvivono al ricaricamento,
## ma due schede aperte sono due giocatori diversi. Il nome resta per tutte.
const TAB_KEYS := ["refresh", "uid", "room", "seat"]

func _session_file() -> String:
	var f := OS.get_environment("WO_SESSION")
	return f if f != "" else SESSION_FILE

func load_session() -> Dictionary:
	var out := {}
	var c := ConfigFile.new()
	if c.load(_session_file()) == OK and c.has_section("s"):
		for k in c.get_section_keys("s"):
			out[k] = c.get_value("s", k)
	if OS.has_feature("web"):
		for k in TAB_KEYS:
			out.erase(k)
			var v = JavaScriptBridge.eval("sessionStorage.getItem('%s%s') || ''" % [WEB_PREFIX, k])
			if v != null and str(v) != "":
				out[k] = int(str(v)) if k == "seat" else str(v)
	return out

func _save(values: Dictionary) -> void:
	var c := ConfigFile.new()
	c.load(_session_file())
	for k in values:
		if OS.has_feature("web") and k in TAB_KEYS:
			JavaScriptBridge.eval("sessionStorage.setItem('%s%s', %s)" % [WEB_PREFIX, k, JSON.stringify(str(values[k]))])
		else:
			c.set_value("s", k, values[k])
	c.save(_session_file())

## Ricorda la stanza in cui si sta giocando (per rientrare), oppure la dimentica con code = "".
func remember_room(code: String, seat := -1) -> void:
	_save({"room": code, "seat": seat})

## Il gettone d'accesso dura un'ora: lo si rinnova dopo 50 minuti.
func _fresh() -> bool:
	if refresh_token == "" or Time.get_unix_time_from_system() - token_at < 3000:
		return true
	var r := await _request(HTTPClient.METHOD_POST, refresh_url, "grant_type=refresh_token&refresh_token=" + refresh_token.uri_encode(), true)
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return false
	id_token = r["data"].get("id_token", id_token)
	refresh_token = r["data"].get("refresh_token", refresh_token)
	token_at = Time.get_unix_time_from_system()
	_save({"refresh": refresh_token})
	return true

func _url(path: String) -> String:
	return "%s/%s.json?auth=%s" % [db_url, path, id_token]

func db_get(path: String) -> Dictionary:
	await _fresh()
	return await _request(HTTPClient.METHOD_GET, _url(path))

func db_put(path: String, value) -> Dictionary:
	await _fresh()
	return await _request(HTTPClient.METHOD_PUT, _url(path), value)

func db_patch(path: String, value: Dictionary) -> Dictionary:
	await _fresh()
	return await _request(HTTPClient.METHOD_PATCH, _url(path), value)

func db_delete(path: String) -> Dictionary:
	await _fresh()
	return await _request(HTTPClient.METHOD_DELETE, _url(path))

## Firebase restituisce gli elenchi con chiavi numeriche come array (con buchi a null): li riporta a dizionario.
static func _as_dict(v) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			if v[k] != null:
				out[str(k)] = v[k]
	elif v is Array:
		for i in v.size():
			if v[i] != null:
				out[str(i)] = v[i]
	return out
