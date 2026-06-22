extends Control
## Splash / menu principale: copertina del regolamento, scelta numero giocatori,
## selezione delle potenze (col vincolo del 2 giocatori), modalita' (Hot Seat /
## Online), Opzioni (placeholder) e avvio partita.

## Versione e changelog mostrati nello splash. Aggiornare a ogni rilascio.
const VERSION := "v0.7.41"
const CHANGELOG := [
	"v0.7.41 — Fix Influenza permanente: i cubi AGGIUNTI in gioco ora vanno sulle vere caselle permanenti (la riga «1 1 1 1» sotto), non più ammucchiati sulle caselle colorate del setup. Le Influenze INIZIALI restano correttamente sulle caselle colorate in alto. Coordinate prese dalla guida (box celesti) per tutte e 7 le Regioni.",
	"v0.7.40 — COMMERCIO ORA SULLA TUA PLANCIA (niente più finestra separata): si lavora direttamente sulla resource track della plancia. Tocchi un prodotto (anello evidenziato sul token) e compaiono le caselle valide 0-10: verso 0 VENDI, verso 10 COMPRI, col denaro su ogni casella; il token si sposta dove tocchi. In cima al cassetto una barra mostra il Δ money, le bandierine per scegliere da quale potenza comprare, e Conferma/Annulla.",
	"v0.7.39 — CARTE PRODOTTO MULTIPLE: ogni potenza ha 2 carte prodotto (Commerce), 3 per la Russia, ora mostrate tutte nel cassetto; quelle usate nel round appaiono girate/grigie. Comprando un prodotto da una potenza si gira la CARTA SPECIFICA che lo mostra, quindi può venderlo una volta per ogni carta scoperta (prima si poteva comprare quel prodotto da lei una sola volta a round). Il limite d'acquisto da una potenza dipende dalle sue carte ancora scoperte.",
	"v0.7.38 — COMMERCIO rifatto: niente più tabella di testo. Ogni risorsa ha la sua traccia 0-10; tocchi una casella per spostare la risorsa — verso 0 VENDI, verso 10 COMPRI — con il denaro guadagnato/speso scritto su ogni casella. Per comprare da un altro giocatore scegli la sua BANDIERINA tra le sorgenti a fianco (🏦 banca o le potenze che vendono quella risorsa), e il limite si adatta a quanto offre. (Il trascinamento drag&drop arriverà come passo successivo.)",
	"v0.7.37 — AUTO-INFLUENCE completo (partite a 2-3 giocatori): ora le potenze neutrali applicano DUE carte Auto-Influence per round (prima una sola), elencate nel riepilogo di fine round con dove piazzano Influenza/Armate. Il money del commercio (10) ora è CONDIZIONATO: una potenza neutrale lo dà a un giocatore solo se quel giocatore ha una Commerce card a faccia in su (che viene girata); se le ha già girate tutte, niente money.",
	"v0.7.36 — AFTERMATH ora INTERATTIVO: invece di applicare tutto in automatico, ogni giocatore ha un popup di scelte. L'INCREASE PROSPERITY è opzionale (decidi tu se spendere i Consumer Goods per avanzare). Puoi SCARTARE i tuoi Engage token per ottenere +5 money per Country alleata della Regione (Return on Investments) OPPURE +2 Difesa per Country alleata, applicata al THREAT di quella Regione. La quota FDI del Return on Investments resta automatica.",
	"v0.7.35 — L'anteprima ingrandita (flyover) delle carte al passaggio del mouse è ora ANCORATA A DESTRA e più contenuta: prima compariva grande al centro e copriva la board e i testi delle scelte nei popup.",
	"v0.7.34 — Research: ora puoi ESAURIRE le Country alleate (ancora ready) per aggiungere il loro valore ai punti Research, da spendere nel Market (come da regolamento: es. Singapore +2, Tajikistan +1). I pulsanti compaiono nella schermata Research.",
	"v0.7.33 — Schermata RESEARCH/MARKET rifatta e LEGGIBILE: le carte Market e Growth sono ora dimensionate per stare in una riga senza accavallarsi (le Growth mostrate in orizzontale), con il pannello scrollabile e adattato allo schermo. Aggiunte le regole del Market: comprando una carta ne compare una nuova a sinistra; puoi spendere 2 Research per scartare le 3 carte più a destra; a fine Research si scartano le carte più a destra (2 in 2 giocatori, 1 in 3, nessuna in 4).",
	"v0.7.32 — Regole allineate al regolamento (audit). Le ABILITÀ SPECIALI delle potenze ora contano davvero nello scoring: USA penalità se ha la maggioranza di Influenza in meno di 4 Regioni, Russia +VP per ogni Regione di zona con più Armate, Cina VP per le Regioni con FDI. A fine partita: +2 VP per ogni Strategic Asset non usato e +3 per l'Executive Order non usata. Spareggio del vincitore corretto (1° bonus Maggioranza → più cubi Influenza → vittoria condivisa). Azioni corrette: nel Trade il bene da 20 sono le Armate (la Diplomazia non si commercia) e la +1 Diplomazia si ha solo comprando da un altro giocatore; Engage richiede una Country alleata nella Regione; Invest/Build a Base una sola volta per Paese; Move solo in zona d'interesse o dove hai una Base; Build a Base muove fino al valore del Paese (non più 1 fisso); la Diplomazia in eccesso (>10) va persa. NATO USA↔EU validata sulle potenze in gioco.",
	"v0.7.31 — Plance ricalibrate dai template utente: i segnalini di Produzione, Prodotti, Prosperità e Focus sono ora centrati sulle caselle stampate di tutte e 4 le potenze (USA, EU, Russia, Cina), con la posizione del tracciato Materie Prime specifica per potenza.",
	"v0.7.30 — Tolto il flyover (anteprima ingrandita) sulle carte nazione sul tabellone: si leggono zoomando la mappa. Corretto lo sfarfallio quando si trascina la mappa ingrandita: su un asse dove la mappa è più piccola della viewport ora viene centrata stabilmente invece di rimbalzare.",
	"v0.7.29 — Bugfix: dopo aver spostato i carri, «Fine spostamento» (e quindi «Fine turno») non bloccano più la partita. Le barre di spostamento non si accumulano più nascoste sul tabellone.",
	"v0.7.28 — Classifica maggioranza rifinita: bandiere più piccole, distanziate e posate sulla riga dei numeri (non coprono più i box temporanei); i PV accanto a ogni bandiera. Le Regioni che non segnano ancora (permanenti non tutti pieni) mostrano la classifica provvisoria in trasparenza.",
	"v0.7.27 — Cubi Influenza iniziali ora sulle CASELLE COLORATE in alto (non più sulle caselle valore \u201c1\u201d). Nuovo: CLASSIFICA MAGGIORANZA in tempo reale — su ogni numero della traccia maggioranza compare la bandiera della potenza in quella posizione + i PV (regole del regolamento: Influenza, pareggi rotti dalle Armate, i local contano ma non segnano, conteggia solo a permanenti pieni). Segnalino ROUND ora sulla casella giusta della traccia round. Tutto calibrato a pixel dal template.",
	"v0.7.26 — Segnalini di gioco ora visibili: Engage token (stretta di mano della potenza, max 3) sulle Regioni dove fai Engage; token FDI (Invest) e Base militare (Build a Base) sulle carte delle nazioni alleate. Prima non erano implementati.",
	"v0.7.25 — Quando bisogna toccare la mappa (spostare Armate, piazzare/convertire Influenza, ecc.) il cassetto plancia ora si CHIUDE da solo così la mappa è cliccabile (prima restava aperto e la bloccava). MENA allineato al tabellone reale (3 permanenti / 5 temporanee) con i cubi iniziali eu+usa+local.",
	"v0.7.24 — Posizioni RICALIBRATE A PIXEL dal template: segnalini Ordine di Turno ora esattamente nelle caselle 1°-4°; cubi Influenza sulle caselle reali di ogni Regione (incluse le tracce più lunghe di MENA); ogni superpotenza ha la sua casella per i carri armati (4 per Regione, 2x2: EU alto-sx, Russia alto-dx, USA basso-sx, Cina basso-dx).",
	"v0.7.23 — Le carte 'prodotto' delle superpotenze nel Commercio ora usano l'arte ufficiale (es. Russia: barile/energia + roccia/materie prime) invece delle icone generiche. I carri armati (Armate) nelle Regioni sono ora centrati sull'area armate calibrata di ogni Regione (sopra le sagome stampate), non più nel centro generico del riquadro.",
	"v0.7.22 — Segnalini Ordine di Turno ricalibrati nelle caselle 1°-4° (erano spostati nella mappa). Cubi Influenza un po' più grandi. Le Growth card acquisite ora compaiono come carte vicino alla plancia (colonna accanto agli Strategic Asset), non più solo come testo.",
	"v0.7.21 — Cubi Influenza ora posati sulle CASELLE stampate di ogni Regione (slot permanenti sopra la linea, temporanei sotto) invece che ammucchiati nell'angolo: coordinate calibrate per tutte e 7 le Regioni. La mappa inoltre si ri-centra/adatta sempre alla viewport finché non la sposti a mano.",
	"v0.7.20 — UI tabellone e plancia: la plancia NON si deforma più (rapporto bloccato); la barra in alto è ora FUORI dalla mappa (mappa incastonata tra barra e linguette) e la mappa si trascina di nuovo col mouse. Ricalibrate le carte Country sulle Regioni, i cubi di Produzione e i token Risorse sulla plancia, e i segnalini Ordine di Turno (più grandi e centrati). Il cassetto è ora a colonne (plancia · nazioni amiche · Commercio con carte prodotto · Strategic Asset in verticale a destra), senza etichette e senza icone illeggibili.",
	"v0.7.19 — Fasi del round più fedeli: AFTERMATH ora include Return on Investments (incassi 2 money × valore Paese per ogni FDI da Invest). PREPARATION (dal 2° round) ora rivela/ruota le carte Country delle Regioni. Il FOCUS è tornato un passo di Preparation: si sceglie GRATIS una volta per round (non costa più un'azione), con ready/produce associati.",
	"v0.7.18 — Segnalini sul tabellone: PUNTI VITTORIA (bandiere sulla traccia perimetrale 0–99), ORDINE DI TURNO (bandiere nelle 4 caselle 1°–4° sotto il titolo) e segnalino ROUND. Tolta la riga in alto con VP/Prosperità che copriva la mappa (la barra ora mostra solo round/turno + denaro + Fine turno; la Prosperità è sulla plancia).",
	"v0.7.17 — Influenza: ora SCEGLI tu se mettere il cubetto in slot PERMANENTE (sopra, resta a fine partita) o TEMPORANEO (sotto, più VP ma spingibile), come da regolamento. Vale per Engage, Invest, Build a Base e gli effetti carta (quando un permanente è libero).",
	"v0.7.16 — Mappa: ora puoi TRASCINARLA col mouse anche da zoomata (le Regioni catturano il click solo quando devi sceglierne una). Influenza iniziale resa come CUBETTI colorati (con conteggio) invece di pallini.",
	"v0.7.15 — Chiusi 6 effetti carta che prima non facevano nulla: reset_influence (proteggi Influenza temporanea), increase_production (+N a una traccia), ready_country (prepara N nazioni), trash/discard (elimina/scarta carte), increase_prosperity. Ora 106/109 carte hanno tutti gli effetti eseguiti.",
	"v0.7.14 — Gioco a FACCIA IN GIÙ: toccando una carta scegli se giocarla per la sua azione, oppure a faccia in giù per +10 money o per attivare uno dei tuoi 2 STRATEGIC ASSET (le carte speciali del setup, usabili una volta). I Strategic Asset sono mostrati nel cassetto (grigi se usati).",
	"v0.7.13 — Setup: Armate iniziali = Produzione di Armate (in riserva). Modificatori di carta condizionali sul Trade: «conta Energia ×2» (e Energia/Materie Prime, es. Energy Titan) raddoppiano i simboli Export; bonus Influenza concesso solo se hai esportato Beni/Servizi (o 4 Energia).",
	"v0.7.12 — Focus completo: la Focus action ora PRODUCE il tipo del Focus (Domestic→Beni/Servizi, Diplomatic→Diplomazia, Military→Armate in riserva) e prepara il giusto numero di Country card (Domestic 1, Diplomatic 4, Military 2). AUTO-INFLUENCE: con meno di 4 giocatori, ogni fine round le potenze neutrali piazzano Influenza/Armate da una carta Auto-Influence (mostrata nel riepilogo), così contano per scoring e maggioranze.",
	"v0.7.11 — Azioni domestiche. PRODUCE rifatto: scegli quante risorse generare da PIÙ tracce nella stessa azione (primarie gratis, secondarie consumano le primarie; le Armate vanno nella riserva). GET A GROWTH CARD: le carte Sviluppo si scelgono come immagini (con flyover), non più da lista testuale; le non acquistabili sono in grigio.",
	"v0.7.10 — Azioni economiche (Invest): le nazioni amiche ESAURITE ora si vedono (grigie e ruotate, come una carta tapped), così distingui a colpo d'occhio quali puoi ancora usare per Invest/Build a Base.",
	"v0.7.9 — Azioni militari. Pedine ARMATA (tank colorati) disegnate sulla mappa, impilate al centro della Regione; riserva del giocatore in alto sulla plancia. MOVE rifatto: scegli SORGENTE (Riserva o una Regione con tue Armate) e DESTINAZIONE, spostamento libero su qualsiasi Regione (5 money/Armata). Tolto anche qui il tap-diretto: Invest/Build a Base richiedono di giocare la carta.",
	"v0.7.8 — Azioni diplomatiche: ora SERVE giocare la carta (tolto l'Engage/Improve rapido toccando mappa/nazione). Nuovo popup per esaurire le nazioni amiche della Regione e scontare il costo in Diplomazia (Engage e Improve Relations).",
	"v0.7.7 — Carta Commercio (Trade Deals) mostrata accanto alle nazioni amiche (clic = apre il Trade). Le carte della stessa nazione ora si IMPILANO (badge ×N): più carte = più simboli Export/Import, quindi più capacità di commercio con quella nazione.",
	"v0.7.6 — Denaro iniziale corretto per potenza: USA 30, UE 25, Cina 20, Russia 15 (nel setup).",
	"v0.7.5 — Denaro con le MONETE vere del gioco (asset TTS): la cifra è resa come pila di monete nei tagli 20/10/5/1 (scomposizione automatica), con il totale a fianco.",
	"v0.7.4 — Commercio tra giocatori: importando da un altro giocatore lui incassa il money e +1 Servizio, e la sua Commerce card si gira (1×/round). Abilità continuative completate: Focus action prepara le Country card (2 + bonus), e «extra_play_first_turn» dà +1 carta al primo turno. Ora il turno = 1 azione (giochi 1 carta o fai Focus).",
	"v0.7.3 — Azione TRADE interattiva: scegli Export/Import per risorsa con i cap dalle nazioni amiche (simboli Export/Import) e dalla carta Trade Deals (limite 2/3 transazioni, una risorsa per transazione). Export incassa money, Import lo spende; +1 Diplomazia comprando dagli altri. Δ money in tempo reale.",
	"v0.7.2 — Audit costi: ogni azione paga il suo costo; rifiutata con messaggio se non puoi. La produzione secondaria consuma le primarie. Trade muove davvero le risorse.",
	"v0.7.0 — Move multi-regione e abilità continuative (ongoing): pesca extra a inizio round, pannello once-per-round.",
	"v0.6.7 — Regole: ordine di turno corretto (più VP gioca per primo). Strategic Asset nel setup (pesca 3, tiene 2 → VP iniziali). Vedi TODO.md per lo stato regole↔meccanica.",
	"v0.6.6 — Cubi produzione ricalibrati (3 colonne: erano sbagliati materie prime/grano/diplomazia). Linguette potenze con BANDIERE su barra dedicata in basso (non coprono la mappa). Mano collassabile (toggle) così non copre mai la plancia.",
	"v0.6.5 — Setup iniziale esatto: produzioni di partenza corrette per ogni potenza, risorse iniziali = produzione, nazioni amiche iniziali complete (4-5 per potenza). Nazioni amiche a destra della plancia (griglia). Prosperità e risorse ricalibrate.",
	"v0.6.4 — Cassetto: plancia a sinistra, nazioni amiche, mano in basso. Segnalini ancorati alla plancia.",
	"v0.6.3 — FIX plancia gigante: all'immagine mancava expand_mode=IGNORE_SIZE, non scendeva sotto la dimensione nativa (1400px).",
	"v0.6.2 — Tentativo tetto massimo plancia (non bastava da solo).",
	"v0.6.1 — Tolte le scritte ridondanti nel cassetto (intestazione potenza, 'La tua mano'). Flyover anche su mano e nazioni amiche. (Se non vedi questa versione nello splash, svuota la cache.)",
	"v0.6.0 — Flyover: passa sopra una carta per ingrandirla. Plancia adattiva (niente più gigante su desktop). Mano del giocatore sempre visibile in basso; carte più grandi.",
	"v0.5.0 — Mazzi potenza completi (12 carte, doppioni inclusi). Nazioni amiche iniziali (dal salvataggio TTS). Plancia con cubi/token reali e Focus cliccabile direttamente sull'immagine.",
	"v0.4.0 — Carte nazione originali posate negli slot designati del tabellone (coordinate dal TTS). Market/Growth illustrate.",
	"v0.3.0 — Mappa con zoom e trascinamento. Plance reali con i segnalini.",
	"v0.2.0 — UI responsive, cassetti per potenza.",
]

const POWERS := ["usa", "eu", "russia", "china"]
const POWER_NAME := {"usa": "USA", "eu": "UE", "russia": "Russia", "china": "Cina"}
const POWER_COLOR := {
	"usa": Color(0.45, 0.62, 0.9), "eu": Color(0.95, 0.82, 0.2),
	"russia": Color(0.9, 0.9, 0.9), "china": Color(0.9, 0.3, 0.3),
}

var _player_count := 2
var _count_buttons: Array[Button] = []
var _mode := "hotseat"
var _mode_buttons: Array[Button] = []
var _seat_powers: Array = []          # potenza scelta per seggio
var _seats_box: VBoxContainer
var _warn: Label


func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/cover.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.5)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(460, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "WORLD ORDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	var ver := Label.new()
	ver.text = VERSION
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	box.add_child(ver)

	_build_changelog()

	box.add_child(_section_label("Numero di giocatori"))
	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 10)
	box.add_child(counts)
	for n in [2, 3, 4]:
		var b := Button.new()
		b.text = str(n)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(56, 40)
		b.pressed.connect(_on_count.bind(n))
		counts.add_child(b)
		_count_buttons.append(b)

	box.add_child(_section_label("Potenze"))
	_seats_box = VBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 6)
	box.add_child(_seats_box)

	box.add_child(_section_label("Modalità"))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10)
	box.add_child(modes)
	var hot := Button.new()
	hot.text = "Hot Seat"
	hot.toggle_mode = true
	hot.custom_minimum_size = Vector2(140, 40)
	hot.pressed.connect(_on_mode.bind("hotseat"))
	modes.add_child(hot)
	_mode_buttons.append(hot)
	var online := Button.new()
	online.text = "Online (presto)"
	online.disabled = true
	online.custom_minimum_size = Vector2(140, 40)
	modes.add_child(online)

	var opts := Button.new()
	opts.text = "Opzioni (prossimamente)"
	opts.disabled = true
	box.add_child(opts)

	_warn = Label.new()
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	box.add_child(_warn)

	var play := Button.new()
	play.text = "▶  Avvia partita"
	play.custom_minimum_size = Vector2(0, 50)
	play.add_theme_font_size_override("font_size", 22)
	play.pressed.connect(_on_play)
	box.add_child(play)

	_update_selection(_count_buttons, 0)
	_update_selection(_mode_buttons, 0)
	_set_count(2)


# --- Numero giocatori / potenze ---

func _on_count(n: int) -> void:
	_set_count(n)
	_update_selection(_count_buttons, [2, 3, 4].find(n))


func _set_count(n: int) -> void:
	_player_count = n
	# default sensati e validi (rispettano il vincolo del 2 giocatori).
	_seat_powers = GameConfig.powers_for_count_n(n).duplicate()
	_rebuild_seats()


## Potenze ammesse per un seggio (vincolo del 2 giocatori).
func _allowed_for_seat(seat: int) -> Array:
	if _player_count == 2:
		return ["usa", "eu"] if seat == 0 else ["russia", "china"]
	return POWERS.duplicate()


func _rebuild_seats() -> void:
	for c in _seats_box.get_children():
		c.queue_free()
	for seat in _player_count:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		var lbl := Label.new()
		lbl.text = "Giocatore %d:" % (seat + 1)
		lbl.custom_minimum_size = Vector2(96, 0)
		row.add_child(lbl)
		for power in _allowed_for_seat(seat):
			var b := Button.new()
			b.text = POWER_NAME[power]
			b.toggle_mode = true
			b.button_pressed = (_seat_powers[seat] == power)
			b.custom_minimum_size = Vector2(72, 36)
			b.add_theme_color_override("font_color", POWER_COLOR[power])
			# disabilita se gia' scelta da un altro seggio
			b.disabled = (power in _seat_powers and _seat_powers[seat] != power)
			b.pressed.connect(_on_pick_power.bind(seat, power))
			row.add_child(b)
		_seats_box.add_child(row)
	_validate()


func _on_pick_power(seat: int, power: String) -> void:
	_seat_powers[seat] = power
	_rebuild_seats()


func _validate() -> bool:
	var chosen := {}
	for p in _seat_powers:
		if p == "" or chosen.has(p):
			_warn.text = "Assegna una potenza diversa a ogni giocatore."
			return false
		chosen[p] = true
	_warn.text = ""
	return true


# --- Modalita' / avvio ---

func _on_mode(m: String) -> void:
	_mode = m
	_update_selection(_mode_buttons, 0)


func _on_play() -> void:
	if not _validate():
		return
	GameConfig.player_count = _player_count
	GameConfig.mode = _mode
	GameConfig.powers = _seat_powers.duplicate()
	get_tree().change_scene_to_file("res://scenes/board.tscn")


# --- helper UI ---

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	return l


## Pannello changelog ancorato in basso a destra, scrollabile.
func _build_changelog() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -340
	panel.offset_top = -210
	panel.offset_right = -12
	panel.offset_bottom = -12
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.09, 0.85)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var head := Label.new()
	head.text = "Novità — %s" % VERSION
	head.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	vb.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size = Vector2(310, 0)
	scroll.add_child(list)
	for entry in CHANGELOG:
		var e := Label.new()
		e.text = "• " + String(entry)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(310, 0)
		e.add_theme_font_size_override("font_size", 12)
		e.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
		list.add_child(e)


func _update_selection(buttons: Array, idx: int) -> void:
	for i in buttons.size():
		buttons[i].button_pressed = (i == idx)
