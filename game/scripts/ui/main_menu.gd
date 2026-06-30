extends Control
## Splash / menu principale: copertina del regolamento, scelta numero giocatori,
## selezione delle potenze (col vincolo del 2 giocatori), modalita' (Hot Seat /
## Online), Opzioni (placeholder) e avvio partita.

## Versione e changelog mostrati nello splash. Aggiornare a ogni rilascio.
const VERSION := "v0.7.147"
const CHANGELOG := [
	"v0.7.147 - ESPANSIONE: OBIETTIVI Superpotenze ATTIVI in partita! Al setup ogni potenza riceve 2 dei suoi Obiettivi (scartando quelli che citano una potenza non in gioco). Nei round di Scoring (3 e 6) ogni Obiettivo dà VP in base a quante delle sue 3 condizioni sono soddisfatte (1/2/3 -> ricompensa a 3 livelli), con soglie più alte al round 6. Nuovo pannello 'Obiettivi' nella plancia del giocatore: mostra ogni condizione con ✓/✗ allo stato attuale e i VP che otterresti ora. +1 test (verify_objectives_game, 8 check). Suite motore 138/138.",
	"v0.7.146 - ESPANSIONE: OBIETTIVI Superpotenze — fondamenta (dati + motore di valutazione). Tutti i 32 Obiettivi (8 per potenza) trascritti in data/objectives.json: ogni carta ha 3 condizioni (con soglie distinte per il round 3 e il round 6) e una ricompensa a 3 livelli (1/2/3 condizioni soddisfatte). Nuovo motore Objectives che valuta ~40 tipi di condizione (influenza/maggioranze per Regione, armate, alleati, IDE, produzione, export/import, prosperità, money, carte...). +1 test (verify_objectives, 33 check). L'assegnazione al setup e il punteggio nei round 3/6 arrivano nel prossimo aggiornamento.",
	"v0.7.145 - ESPANSIONE: 4 CARTE AZIONE aggiuntive (carte Market, con arte vera dal PDF) e relative interazioni fra giocatori. 'Nuovi Accordi Finanziari' (economica): investi in una Nazione Alleata altrui con IDE pagando +5 money. 'Dimostrazione di Forza' (militare): Base + disloca 1 Armata; se lo fai, gli altri esauriscono 1 alleato in quella Regione. 'Distensione Diplomatica' (diplomatica): Impegnati e, spendendo 1 Diplomazia, sposti 1 Armata nemica fuori dalla Regione. 'Intelligence di Acquisizione' (nazionale): guarda la mano di un avversario e copia l'effetto di una sua carta. +1 test (verify_action_cards, 8 check).",
	"v0.7.144 - BOT ONLINE: i Bot ora giocano anche nelle partite in rete! Li guida l'HOST (autoritativo) e i client li ricevono già risolti via snapshot, vedendo le loro mosse nel banner e nel Registro come per gli umani. Nel menu Online spunta 'Riempi i posti liberi con i Bot': i seggi senza un giocatore collegato vengono affidati ai Bot (serve almeno l'host umano), con scelta della difficolta'. +1 test (verify_net_bot, 6 check). I 138 test del motore e tutti i test di rete restano verdi.",
	"v0.7.143 - ESPANSIONE: ULTIMA CARTA CRESCITA 'Vantaggio Operativo' (Liv.4, 5 VP, costa 4 Servizi + 15 money). Modulo Carte Crescita COMPLETO (10 su 10)! All'acquisto peschi 2 nuove carte Orientamento Strategico della tua potenza, ne tieni 1 (+ i suoi VP iniziali); poi puoi attivare GRATIS 1 tuo Asset Strategico (i suoi effetti si risolvono subito e la carta si gira a faccia in giù). +1 test (verify_growth_vantaggio, 10 check).",
	"v0.7.142 - ESPANSIONE: CARTA CRESCITA 'Efficienza delle Risorse' (Liv.3, 3 VP; ora 9 delle 10). Costa 3 Servizi + 5 Risorse QUALSIASI (nuovo tipo di costo: paghi 5 unità di risorse a piacere). 1x/round: pesca 1 carta, poi scartane 1 e ottieni risorse dal suo tipo — Diplomatico +2 Diplomazia, Militare +1 Armata, Economico +1 Beni di consumo, Nazionale +1 Servizi (le carte miste rendono Beni + Servizi). +1 test (verify_growth_efficiency, 8 check).",
	"v0.7.141 - ESPANSIONE: altre 2 CARTE CRESCITA (ora 8 delle 10). 'Forza di Reazione Rapida' (Liv.1, 2 VP, costa 1 Servizi + 1 Armata): 1x/round, in base al Focus — con Nazionale/Diplomatico spendi 5 money per +1 Armata in riserva, con Militare dispieghi 1 Armata gratis in una Regione a scelta. 'Collaborazione con gli Alleati' (Liv.2, 3 VP, costa 2 Servizi + 1 Diplomazia): 1x/round esaurisci 1 Nazione Alleata pronta per guardare in cima al mazzo tante carte quanto il suo valore, pescarne 1 e lasciare le altre in cima. Bottone 'Usa' nel pannello Abilita' continuative. +1 test (verify_growth_reaction_scry, 10 check).",
	"v0.7.140 - ESPANSIONE: primi 4 ORIENTAMENTI STRATEGICI (Asset Strategici) di Diplomacy & Dominance, con arte a piena risoluzione. 'Test Nucleari' (Russia, 2 VP): spendi 1 Servizi + 25 money, collochi 1 Armata in Europa, 1 in Asia centrale e 1 in Asia or.-Pacifico, poi aggiungi 1 Influenza a UNA di quelle 3 Regioni. 'Polo Produttivo Globale' (Cina, 2 VP): Commercia e Produci (limitato a energia/materie/beni). 'Iniziativa Global Gateway' (UE, 1 VP): Investi in 1 Nazione, e puoi Investire in 1 Nazione aggiuntiva spendendo 10 money. 'Gigante Economico' (UE, 2 VP): scegli 2 azioni fra Commercia / Produci 2 tipi / Investi. Le scelte multiple (2 di 3) ora funzionano davvero. +1 test (verify_strategic_orientamenti, 18 check).",
	"v0.7.139 - ESPANSIONE: Carta CRESCITA 'Affermazione di Predominio' (Liv.4, 4 Servizi + 2 Diplomazia). Quando la ottieni guadagni 2 VP per ogni round GIA' completato (es. al round 4 = +6 VP). Inoltre, alla fine di OGNI turno in cui hai aggiunto Influenza ad almeno una Regione, ottieni +1 VP. Ora 6 delle 10 Carte Crescita aggiuntive. +1 test (verify_growth_predominio).",
	"v0.7.138 - ESPANSIONE: Carta CRESCITA 'Ottimizzazione delle Entrate' (Liv.1, 1 VP, 1 Servizio + 10 money). Durante il passo Ricerca ottieni di NUOVO il bonus superiore (in alto) di 2 delle tue carte migliori — money/diplomazia/armata raddoppiati per le 2 carte di bonus piu' alto. Ora 5 delle 10 Carte Crescita aggiuntive. +1 check (verify_growth_expansion).",
	"v0.7.137 - ESPANSIONE: altre 2 Carte CRESCITA (le piu' potenti, Liv.5). 'Autorità Inconfutabile' (6 VP): nel calcolo del punteggio vinci i PAREGGI di maggioranza per numero di cubetti Influenza, a prescindere dalle Armate nella Regione. 'Programma Nucleare' (8 VP, costa anche 2 Armate dalla riserva): hai +1 MINACCIA e +1 Difesa in TUTTE le Regioni, anche dove non hai Armate. Ora sono 4 delle 10 Carte Crescita aggiuntive. +2 test (verify_growth_endgame: tie-break, THREAT, costo in Armate).",
	"v0.7.136 - ESPANSIONE Diplomacy & Dominance: prime 2 Carte CRESCITA aggiuntive. 'Cambio di Leadership' (Liv.2, 4 VP): una volta per round puoi scartare tutta la mano e ripescare altrettante carte (bottone 'Usa' nel pannello Abilita' continuative). 'Tenore di Vita Elevato' (Liv.3, 4 VP): ogni volta che aumenti la Prosperita' spendi 1 Beni di consumo in meno e ottieni 1 VP in piu'. Si comprano con l'azione 'Get a Growth' come le altre. (Le altre 8 Carte Crescita dell'espansione e gli altri moduli - Azioni, Orientamenti, Obiettivi - arrivano nei prossimi aggiornamenti.) +1 test (verify_growth_expansion).",
	"v0.7.135 - BOT piu' VISIBILI. Durante il turno di un Bot ora compare in alto un BANNER ben visibile, nel colore della potenza, che dice cosa sta facendo (es. 'BOT CINA — Engage in Europa') - non serve piu' guardare solo il LOG. Inoltre i Bot agiscono a un ritmo piu' calmo (~0.85s a mossa) cosi' si seguono i loro turni. NB: i Bot funzionano solo nelle partite LOCALI (Solo / completamento tavolo in hot-seat); nelle partite ONLINE non sono ancora disponibili (in arrivo). +check nei test.",
	"v0.7.134 - Choose Focus: ora SCEGLI TU quali NAZIONI riattivare. Quando hai PIU' Nazioni esaurite di quante il Focus ne puo' riattivare (es. Focus Nazionale = 1, ma hai 3 Nazioni esaurite), il gioco non le riattiva piu' a caso da solo: tocchi tu sulla plancia le Nazioni esaurite (grigie) da rimettere attive, fino al numero consentito, poi 'Continua'. Se invece le esaurite sono <= al numero del Focus, si riattivano tutte da sole (niente scelta inutile). Funziona anche in multiplayer (scelta sincronizzata). Insieme alla produzione interattiva (v0.7.133), ora TUTTO il Choose Focus e' guidato e scelto dal giocatore. +1 test (verify_focus_ready).",
	"v0.7.133 - PRODUZIONE del FOCUS ora la SCEGLI TU. In Preparazione, dopo aver scelto il Focus, la produzione non e' piu' automatica: si apre la STESSA schermata Produce delle carte (la track sulla plancia), limitata ai tipi del tuo Focus (Nazionale: Beni di consumo + Servizi · Diplomatico: Diplomazia · Militare: Armate). Imposti quanto produrre e premi Conferma, poi prosegue l'Aumento Produzione opzionale come prima. Cosi' la produzione e' COERENTE ovunque (Focus e carte usano la stessa interfaccia) e vedi quanto costa in primarie. Funziona anche in multiplayer (Produce del Focus sincronizzata). +1 test (verify_focus_produce). (Prossimo passo: scegliere anche QUALI Nazioni esaurite riattivare.)",
	"v0.7.132 - PRODUCE piu' CHIARO. Quando un'azione (es. una carta Crescita) ti fa Produrre, sulla track della plancia le caselle verdi mostrano '+N' = quante ne PRODUCI di quella risorsa, e per le risorse DERIVATE il '-N' = quanto COSTA in primarie, ora con l'iniziale della risorsa (es. '-2En -2RM' invece di '-2,-2'). In piu' la barra in alto ha una LEGENDA e un RIEPILOGO dal vivo: es. 'Stai producendo: Beni di consumo +3 (costa 3 Energia, 3 Materie Prime)'. Cosi' si capisce subito cosa significano i numeri. +1 test (verify_produce_ui).",
	"v0.7.131 - MENU rifatto: ora per OGNI superpotenza (USA, UE, Russia, Cina) scegli il ruolo — UMANO, BOT o NEUTRALE. Cosi' puoi giocare in solitaria (1 Umano + 3 Bot), completare un tavolo (2-3 Umani + Bot sui posti liberi) o lasciare le potenze libere come NEUTRALI (guidate dalle carte Auto-Influence, come nel gioco base a 2-3). Spariscono le vecchie modalita' 'Hot Seat'/'Solo': la modalita' LOCALE le ingloba (tutti Umani = hot seat; mix Umano/Bot = solitaria/completamento). Restano la difficolta' dei Bot (Normale/Difficile) e l'Online (LAN). CONFERMA REGOLE: una potenza e' O un Bot (gioca da solo) O Neutrale (Auto-Influence) — mai entrambi; i Bot NON ricevono l'influenza automatica delle Neutrali (la usano solo per decidere dove agire). +2 test (verify_solo_menu aggiornato, verify_bot_vs_neutral).",
	"v0.7.130 - BOT che GIOCANO DAVVERO (Solo mode, stadio 4b). Nella fase Azione i bot non si limitano piu' a un Trade: pescano il TIPO della loro prossima carta, consultano la propria Automa board e ESEGUONO l'azione vera sul tabellone condiviso — Improve Relations (alleano una Nazione), Engage e Invest e Build a Base (mettono Influenza/Armate nelle Regioni, +VP), Move (spostano Armate), Trade, oppure Domestic. Pagano in money (Armate gratuite, come da regolamento), con i fallback giusti (se non possono permettersi un'azione ripiegano su Trade/Improve). Le loro Influenze e Armate contano per maggioranze, THREAT e Scoring come quelle di un giocatore. La partita scorre da sola fino in fondo (Preparazione, Azione, Research, Aftermath, riepiloghi) anche con piu' bot. Semplificazioni note in questa build: la scelta della Regione per Move/Build preferisce la zona di interesse (non il calcolo THREAT completo del regolamento); Domestic da' +30 money (la presa di una Growth card con i suoi VP arrivera' con lo step Research dell'Automa). +1 test (verify_automa_actions) e partita completa all-bot fino al Round 6 nei test.",
	"v0.7.129 - NUOVO: modalita' SOLO (vs Bot). Nel menu, scegli 'Solo (Bot)': per ogni seggio decidi Umano o Bot (Automa) e imposti la difficolta' (Normale/Difficile). Avvii e i bot prendono i loro turni in automatico, senza bloccare la partita. I bot ora sono FEDELI alle carte ufficiali dell'espansione Diplomacy & Dominance: money iniziale, priorita' Mercato/cubetti azione e traccia Prosperita' propri per USA/UE/Russia/Cina (prima erano segnaposto copiati dagli USA). NB: in questa build le AZIONI dei bot sono ancora minimali (in Preparazione scelgono il Focus e incassano il money del Focus, in Azione fanno un Trade e passano) — la logica completa delle azioni (Improve/Engage/Invest/Build/Move via Automa board) arriva nel prossimo aggiornamento. Hot Seat e Online invariati (nessun bot).",
	"v0.7.128 - Choose Focus: la CINA in Focus DOMESTIC puo' ora aumentare DUE Produzioni (distinte) per 15 money, non solo una per 6 (come sulla sua player board). In pratica: aumenti la prima Produzione (6 money) e poi ti viene riofferto un secondo aumento (9 money, su un'altra Produzione) oppure 'Salta'; totale 15. Le altre potenze restano a un solo aumento. Funziona anche in multiplayer (stato sincronizzato). +1 test (verify_china_focus_increase).",
	"v0.7.127 - NUOVO: modulo EXECUTIVE ORDER. Una volta per partita, invece di giocare una carta, premi 'Usa Executive Order' (sotto la tua mano) e scegli UNA tra 8 azioni: Improve Relations, Engage, Trade, Invest, Guadagna 1 Armata + Muovi fino a 2, Build a Base, Get a Growth, Produci 3 tipi. Consuma la giocata del turno. Se NON la usi, a fine partita vale +3 VP (gia' nello scoring). Funziona anche in multiplayer (nuovo comando sincronizzato; la scelta passa per il popup gia' sincronizzato). +2 test (verify_executive_order, verify_net_executive_order).",
	"v0.7.126 - FIX regole (Produce) + chiarimento. L'azione Produce (es. la scelta 'Produci' della carta Growth Strategy, o R&D Champion / Optimization Program) ora rispetta il LIMITE DI TIPI scritto sulla carta: Growth Strategy = 3 tipi di risorsa, R&D Champion = 2, Optimization Program = 1. Prima l'interfaccia ignorava il limite e lasciava produrre TUTTI i tipi. Ora la barra mostra 'fino a N tipi (scelti M/N)' e oltre il limite il tipo in piu' viene rifiutato. Come funziona Produce: tocchi le caselle sulla resource track della tua plancia per produrre fino alla tua Produzione (le primarie danno la quantita' piena, le secondarie consumano i requisiti; le Armate vanno in riserva, -1 Materia ciascuna; l'eccesso oltre 10 diventa money tranne la Diplomazia che si perde). NB sul Commercio: si POSSONO vendere le Armate (carri) dalla riserva, 20 money ciascuna (mai dal tabellone), e la Diplomazia NON e' commerciabile - era gia' corretto (regolamento pag. 13). +1 test (verify_produce_count).",
	"v0.7.125 - FIX regole (Choose Focus): ogni superpotenza ha COSTI e READY PROPRI, come sulle player board. Prima erano fissi per tutti (preparare 1/4/2 carte Nazione e costo 8 per aumentare una Produzione). Ora: costo per aumentare una Produzione = USA 8, UE 7, Russia 6, Cina 6; carte Nazione preparate (ready) per Focus = UE 2/5/3 (Domestic/Diplomatic/Military), USA/Russia/Cina 1/4/2. La fase di Preparazione (dal Round 2; il Round 1 si salta da regolamento) continua a fare ready delle carte esaurite + Produzione del Focus + aumento Produzione opzionale, ora coi valori giusti per potenza. (Nota: l'opzione della Cina di aumentare 2 Produzioni per 15 nel Focus Domestic e' gia' nei dati, l'interfaccia la offrira' in un prossimo aggiornamento.) +1 test (verify_focus_costs).",
	"v0.7.124 - Due cose. 1) MOVE (regole): lo spostamento delle Armate e' consentito SOLO verso Regioni della tua sfera d'influenza (la bandiera della tua potenza nella zona di interesse) o dove hai una Base. Prima si poteva spostare ovunque. Sulla mappa vengono evidenziate solo le destinazioni valide; l'host rifiuta quelle non valide. Le mosse 'gratis' degli Strategic Asset non sono soggette al limite. +1 test (verify_move_zone). 2) UI: le 2 carte Auto-Influence (potenze neutrali) sono ora SOTTO i segnalini dell'ordine di turno, non piu' in alto sopra il titolo 'WORLD ORDER'.",
	"v0.7.123 - CORREZIONE: il Round 1 NON ha la fase di Preparazione - si parte subito con la fase Azione e tutti col Focus Domestic (da regolamento). La Preparazione (scelta del Focus + ready delle carte Nazione esaurite + Produzione del Focus + aumento Produzione opzionale) parte dal Round 2. Annulla v0.7.121, che per errore aggiungeva la Preparazione anche al Round 1.",
	"v0.7.122 - FIX regole (rivisto): tornano i CUBETTI NERI 'local' nelle caselle Influenza iniziali di Medio Oriente/Nord Africa e Asia del Sud. Occupano la casella e contano nelle maggioranze come forze locali (come da regolamento). Il problema dei PV di maggioranza 'attivi gia' al setup' e' risolto alla radice: in board.json gli slot permanenti di queste due Regioni ora contano ANCHE le caselle 'fill' (non solo quelle iniziali), quindi i cubetti iniziali NON completano da soli la riga e i PV scattano solo quando i giocatori riempiono davvero la riga permanente giocando. (Sostituisce l'approccio di v0.7.120, che spostava i 'local' in temporanea facendoli sparire dalle caselle iniziali.) verify_majority_setup aggiornato.",
	"v0.7.120 - FIX regole: i PV di MAGGIORANZA non si attivano piu' gia' al setup. I cubetti iniziali NEUTRALI 'local' venivano messi negli slot PERMANENTI: cosi' Medio Oriente/Nord Africa e Asia del Sud partivano con la riga permanente gia' completa e le maggioranze risultavano 'attive' subito, pur essendo solo cubetti iniziali e non vera influenza permanente di una potenza. Ora i 'local' vanno in TEMPORANEA: contano per l'influenza ma NON completano da soli la riga permanente. I PV di maggioranza si attivano solo quando i giocatori riempiono davvero la riga permanente giocando. (I cubetti iniziali delle potenze restano dove sono: gia' lasciavano slot liberi, quindi nessuna Regione partiva attiva per loro.) +1 test (verify_majority_setup).",
	"v0.7.119 - FIX multiplayer (Commercio tra giocatori). Il trasferimento di MONEY funzionava gia' (vive nello stato sincronizzato): comprando i prodotti di un giocatore, lui incassa e tu paghi, e tutti vedono i money aggiornati. Le CARTE PRODOTTO invece NON si giravano per gli altri: lo stato 'carta girata' viveva solo nella vista dell'host, quindi quando qualcuno comprava i prodotti di un giocatore la sua carta risultava girata SOLO sullo schermo dell'host - gli altri la vedevano ancora disponibile (e potevano ri-comprarla). Ora lo stato delle carte Commercio girate e' sincronizzato: tutti vedono la stessa cosa. +1 test (verify_net_trade_money).",
	"v0.7.118 - Due aggiunte richieste. 1) AVVISO: quando un'azione non e' eseguibile (e la carta ti torna in mano) compare un banner rosso ben visibile in alto, non solo la riga di stato. In rete l'avviso arriva a CHI ha tentato l'azione. 2) REGISTRO delle azioni: una colonna sul bordo DESTRO della mappa, collassabile in orizzontale (tasto ≡ per aprirla/chiuderla). Elenca le cose fatte - carte giocate, Engage/Improve/Invest/Base, Commercio, Produzione, Growth, Focus, cambi di turno, Aftermath e azioni non possibili. E' sincronizzato: tutti i giocatori vedono la stessa storia. +2 test (verify_net_log, verify_action_refund).",
	"v0.7.117 - FIX regole: niente piu' carte/turni SPRECATI su azioni che non puoi permetterti. Prima, se giocavi una carta e poi l'azione falliva per risorse insufficienti (Engage senza Diplomazia, Invest/Build a Base senza money, Improve Relations senza Diplomazia, Get a Growth senza i prodotti), la carta finiva comunque negli scarti e il turno era consumato a vuoto. Ora, se l'azione fallita e' la PRIMA cosa che la carta fa (quindi non e' ancora successo nulla), la carta TORNA in mano e il turno NON viene consumato: puoi rigiocarla o sceglierne un'altra. Per le carte multi-effetto, se un effetto precedente ha gia' avuto luogo si prosegue saltando solo l'azione non eseguibile (la carta resta giocata). +1 test (verify_action_refund).",
	"v0.7.116 - VERIFICA a 4 giocatori + irrobustimento. Domanda: le correzioni fatte a 2 valgono anche a 4? Si': si appoggiano tutte su 'chi agisce ora' (un valore unico, sincronizzato) e sullo stato redatto per ciascun giocatore, che valgono per qualsiasi numero di giocatori. L'unica cosa legata ai 2 era il buffer dei socket, gia' corretto nella v0.7.115. In piu' ho irrobustito l'ATTRIBUZIONE dei comandi: ora l'host ricava il seggio del mittente dalla CONNESSIONE (autenticato), non da quanto dichiara il messaggio - un client non puo' agire al posto di un altro (conta di piu' con piu' giocatori). +1 test a 4 giocatori (verify_net_4p_flow): rotazione dei turni su tutti e quattro i seggi, attribuzione autenticata, e Improve Relations di un seggio centrale (Russia) risolto e sincronizzato su tutte le finestre.",
	"v0.7.115 - FIX multiplayer a 3+ GIOCATORI: i client oltre il primo (es. Russia/Europa in 4 giocatori) non si aggiornavano - mappa, segnalini, ordine di turno, PV restavano sul setup locale. Causa: a ogni aggiornamento l'host invia uno snapshot a OGNI client nello stesso istante; a 4 giocatori pesa ~38 KB l'uno e il buffer dei socket WebSocket (default 65 KB) andava in overflow gia' dopo il primo, scartando in silenzio i pacchetti per gli altri (per questo il 1° client si sincronizzava e gli altri no). Ora i buffer di ingresso/uscita sono 4 MiB: ci stanno gli snapshot di tutti i giocatori. +1 test a 4 giocatori (verify_net_4players) e diagnostica delle dimensioni.",
	"v0.7.114 - AUDIT multiplayer: chiuse due ultime criticita' della stessa famiglia (azioni sulla finestra sbagliata). 1) AFTERMATH: scartare un Engage token (money/Difesa) toccandolo sulla mappa era possibile anche dall'host durante il turno dell'altro -> ora solo il giocatore di turno Aftermath. 2) COMMERCIO dalla carta Trade Deals: l'avvio era LOCALE, cosi' il client entrava in Commercio ma l'host no e il risultato veniva rifiutato -> ora l'avvio passa dall'host (entra in trade_mode e lo sincronizza) ed e' riservato a chi e' di turno. Verificato che le altre fasi/scelte (popup, Growth, riepilogo, Research, Produce, mappa) erano gia' a posto. +1 test (verify_net_audit2).",
	"v0.7.113 - FIX multiplayer: PREPARAZIONE (scelta del Focus + Aumento Produzione). La scelta dell'aumento appariva SEMPRE sullo schermo dell'host (USA) anche durante il turno dell'altro giocatore, e il Focus sembrava 'fuori sync': il client non apriva la propria plancia e non vedeva la barra dell'aumento. Causa: la barra dell'aumento la costruiva l'host e l'indice del giocatore in preparazione non era sincronizzato. Ora _prep_idx e l'attesa dell'aumento sono sincronizzati; la plancia del giocatore di turno si apre da sola e le barre (Focus e Aumento) si ricostruiscono per CHI agisce (in rete il client), non sull'host. +1 test (verify_net_prep).",
	"v0.7.112 - FIX multiplayer: azioni sulla MAPPA solo a CHI agisce. Le caselle Influenza (e la scelta di Regione / delle carte nazione sul tabellone) comparivano e si potevano cliccare anche sulla finestra dell'ALTRO giocatore: cosi' l'host poteva posare l'Influenza al posto del client (le 'azioni sulla finestra sbagliata'). Ora gli elementi cliccabili della mappa appaiono e funzionano solo per il giocatore di turno; un click del giocatore non di turno viene ignorato. Nota sul riquadro diagnostico: 'hand' ora si chiama 'myhand' (la TUA mano) - host e client mostrano giocatori diversi, quindi valori diversi NON sono un desync; gli altri campi invece coincidono se si e' in sync. +1 test (verify_net_acting_guard).",
	"v0.7.111 - FIX multiplayer: il RIEPILOGO di fine round (le 'conseguenze': THREAT, Scoring, Token Maggioranza, bonus) compariva SOLO sullo schermo dell'host -> il client non vedeva mai le conseguenze e il round non avanzava insieme ('tutte le conseguenze fuori sync'). Ora il riepilogo e' sincronizzato: lo vedono ENTRAMBI con le stesse righe, e il 'Continua' passa dall'host che avanza il round una volta sola (a fine partita ognuno torna al proprio menu). Aggiunti al riquadro diagnostico anche 'aft=' (giocatore Aftermath) e 'sum=' (riepilogo attivo). +1 test (verify_net_summary).",
	"v0.7.110 - FIX multiplayer: 'Get a Growth Card'. Il selettore delle Growth (la scelta a carte) compariva sullo schermo dell'HOST anche quando a giocarla era l'altro giocatore - per questo 'la Growth scelta dalla Cina appariva sulla finestra USA' e il turno si bloccava. Causa: quel selettore era l'ultimo a essere disegnato da chi ARBITRA invece che da CHI AGISCE. Ora e' sincronizzato come gli altri popup: appare a chi sta giocando la carta (in rete il client), l'host non lo mostra mentre fa da arbitro, e anche 'Salta' passa dall'host. +1 test (verify_net_growth).",
	"v0.7.109 - TROVATO E CORRETTO il blocco di Improve Relations. Il riquadro diagnostico l'ha rivelato: l'host RISOLVEVA (nazione alleata, mano scalata, turno pronto) ma il client restava fermo un passo indietro (in attesa della Country). Causa: ogni snapshot era inviato UNA volta sola, quindi se il client ne perdeva uno restava bloccato per sempre, senza modo di recuperare. Ora l'host RIBROADCASTA lo stato ogni secondo (heartbeat): un client rimasto indietro si riallinea entro ~1s e il turno si sblocca da solo. Per non avere sfarfallio, il client IGNORA gli snapshot identici a quello gia' mostrato (dedup per hash): ridisegna solo quando qualcosa cambia davvero. Vale anche per connessioni Internet/relay ballerine. +1 test che riproduce il blocco e ne verifica il recupero (verify_net_heartbeat).",
	"v0.7.108 - DIAGNOSTICA Improve Relations: il blocco che hai visto NON e' un problema di rete (verificato: lo snapshot di Improve Relations e' 32 KB, sta nel buffer WebSocket e si ricostruisce identico sia in LAN sia via relay). Il blocco e' uno stato della VISTA che i test headless non vedono. Per catturarlo ho aggiunto, SOLO in rete, un piccolo riquadro verde sul bordo sinistro con lo stato vivo (chi agisce, cosa si attende, carte/popup/sconto/move/commercio pendenti, Fine turno ON/OFF). Quando si blocca, mandami UNA foto di quell'angolo: dice subito quale stato e' appeso. Nessun cambiamento alle regole. +1 test diagnostico (verify_net_snapsize).",
	"v0.7.107 - FIX multiplayer (audit completo delle interazioni): instradate all'host le ultime due giocate che restavano LOCALI -> giocare una carta a faccia in giu' per +10 money e attivare una Carta Strategica (la carta selezionata e' il costo). Prima dal client cambiavano solo il suo stato. NOTA su Improve Relations: il blocco che hai visto ('la nazione si allea ma poi niente') era la barra dello SCONTO (esaurire alleati) che restava appesa: e' gia' corretto nella v0.7.106 (aggiorna a questa build). +3 test di rete (Improve completo con/senza sconto, money/strategic).",
	"v0.7.106 - FIX multiplayer: la barra di stato non resta piu' 'appesa'. Dopo una scelta a popup (es. 'quante Armate sposti?') sul client la barra restava visibile e il turno sembrava bloccato. Causa: sul client la barra delle scelte va guidata SOLO dallo stato e non veniva svuotata alla chiusura. Ora: quando nessuna scelta e' attiva la barra si svuota sul client; le barre interattive (popup/sconto/Commercio/Produce/Move/Aftermath) compaiono solo a CHI agisce (non sull'altra finestra); aggiunta anche la ricostruzione della barra del Move sul client. +1 controllo (verify_net_popup).",
	"v0.7.105 - FIX multiplayer: 1) IMPROVE RELATIONS (scelta della Country sul tabellone) si desincronizzava: il click sulla carta nazione veniva risolto in LOCALE, cosi' la carta spariva solo da te (status 'risolta') ma per l'host no -> tornava sulla mappa e il turno si bloccava. Ora il click, e anche la conferma/salta dello SCONTO (esaurire alleati), passano dall'host; lo stato dello sconto e' sincronizzato, cosi' il client vede e usa la barra. 2) La PLANCIA non viene piu' trascinata dalle scelte altrui: in rete la vista si sposta sul giocatore che agisce SOLO quando sei TU, altrimenti puoi guardare la board che vuoi (e di default vedi la tua). +2 test (verify_net_improve).",
	"v0.7.104 - FIX multiplayer: le carte con SCELTA a popup ora funzionano dal client. Le scelte tipo 'quante Armate', 'quanto money', 'scegli una carta da giocare subito' usano una callback non spedibile in rete: prima comparivano solo sullo schermo dell'host. Ora il client VEDE la scelta (prompt + opzioni, sincronizzati) e rimanda l'indice scelto col command bus (comando popup_choice); l'host esegue la callback corrispondente. Funziona anche per scelte concatenate (un popup che ne apre un altro) e l'annullo chiude la scelta su entrambi. In hot-seat invariato. +1 test (verify_net_popup).",
	"v0.7.103 - FIX multiplayer: stesso freeze dell'«Annulla» risolto anche per lo SPOSTAMENTO Armate (Move) e le scelte a popup. Anche li' «Annulla» chiamava una funzione locale: dal client usciva dalla giocata ma l'host restava in attesa -> blocco. Ora l'annullo della giocata passa dall'host (comando cancel_card): entrambe le finestre escono insieme. +1 test (verify_net_cancel). NOTA in lavorazione: le carte con SCELTA a popup (es. 'quante Armate', 'quanto money') sono ancora gestite lato host - per il client di quelle carte e' in arrivo l'instradamento al command bus.",
	"v0.7.102 - FIX: 1) BANDIERA identità ridimensionata (era enorme): ora e' alta quanto la riga di testo. 2) FREEZE dopo «Annulla» del Commercio/Produce in rete: l'annullo chiamava una funzione LOCALE, cosi' il client usciva dal Commercio ma l'host restava dentro e continuava a re-inviare lo stato 'in Commercio' -> tutto bloccato e non si andava avanti. Ora l'annullo passa dall'host (come la Conferma): entrambe le finestre escono insieme. +1 controllo nel test del Commercio.",
	"v0.7.101 - FIX multiplayer: COMMERCIO e PRODUCE si compongono sulla finestra GIUSTA. La resource track (dove sposti i prodotti) era interattiva su ENTRAMBE le finestre quando toccava al giocatore attivo: cosi' l'host poteva comporre/validare il Commercio del client ('lo validava solo l'altra finestra'). Ora la plancia e' interattiva SOLO per il giocatore locale nel proprio turno (in rete); l'altra finestra la vede in sola lettura. Inoltre il client, entrando in Commercio/Produce, inizializza la propria composizione (prima cliccare la track poteva dare errore). Stesso principio applicato alle colonne Focus. In hot-seat nulla cambia. +1 test (verify_net_trade).",
	"v0.7.100 - FIX multiplayer: niente piu' MANI scoperte + indicatore di IDENTITA'. 1) La mano veniva disegnata in base al giocatore DI TURNO: cosi' in rete l'host vedeva la mano del client quando toccava al client (leak di informazione). Ora ogni finestra mostra SOLO la mano del giocatore locale, e puoi vedere le tue carte anche mentre aspetti (interattive solo nel tuo turno). 2) Aggiunto in alto un distintivo «TU: <potenza>» con BANDIERA e colore della potenza, cosi' e' sempre chiaro come quale giocatore stai giocando (distinto da «> a chi tocca»). Il tasto «Fine turno» ora e' attivo solo nel tuo turno. +1 test (verify_net_hand). NOTA: alcune sotto-fasi interattive (es. la composizione del Commercio) sono in revisione per la rete.",
	"v0.7.99 - FIX multiplayer (tabellone host<->client): risolti tre problemi legati allo stesso difetto. 1) Le Country card scoperte per Regione e le carte Auto-Influence vivevano nella Vista (non in gs) ed erano MESCOLATE in modo indipendente in ogni istanza: host e client mostravano carte diverse, le carte nazione non cambiavano quando venivano prese, e le Auto-Influence comparivano in un'istanza e non nell'altra. Ora l'host e' autorita' e il client SPECCHIA queste carte dallo snapshot. 2) Il client, ricevendo uno snapshot, NON ridisegnava gli overlay della mappa (Armate, carte, influenza): per questo le azioni sembravano 'finalizzarsi solo sullo schermo dell'host'. Ora il client ridisegna sempre il tabellone. +1 test di regressione (verify_net_board_state).",
	"v0.7.98 - Relay online pre-configurato: il campo «URL relay» nella lobby e' gia' compilato con wss://world-order-relay.onrender.com, cosi' basta «Ospita (Internet)» / «Entra (Internet)» senza incollare nulla (puoi comunque cambiarlo; l'ultimo usato viene ricordato). NOTA: il relay free si 'addormenta' dopo un po' di inattivita' — la PRIMA connessione dopo una pausa puo' metterci ~30-60s (o fallire una volta): se dice 'Relay irraggiungibile', apri una volta https://world-order-relay.onrender.com nel browser per svegliarlo e riprova.",
	"v0.7.97 - FIX multiplayer (Research di fine round in rete): stesso schema dell'Aftermath. Prima i pulsanti del passo Research (Compra al Market, Cambia Market, esaurisci alleato, «Continua») chiamavano funzioni LOCALI: dal client avanzavano solo il suo stato (desync) o non comparivano affatto, e il Market mostrato era quello locale (diverso da quello dell'host). Ora: tutte le azioni Research passano dal command bus (nuovi comandi research_exhaust_ally/research_reshuffle/research_continue), il pannello Market e i punti Research sono sincronizzati e il client li RICOSTRUISCE dallo stato, e l'attribuzione e' corretta (agisce solo chi e' di turno). +1 test di regressione (verify_net_research).",
	"v0.7.96 - FIX multiplayer (Aftermath di fine round in rete): prima il client si bloccava perche' in Aftermath 'chi agisce' non e' il giocatore di turno ma il giocatore in scelta, e quel dato non arrivava al client (ne' la barra delle scelte veniva ricostruita da lui). Ora: il seggio Aftermath e' sincronizzato (attribuzione corretta: il client agisce solo sul PROPRIO Aftermath), e il client ricostruisce la barra delle scelte dallo stato (vede «Continua»/Prosperita' e i token Engage), cosi' puo' chiudere il proprio turno di Aftermath senza bloccare la partita. +1 test di regressione (verify_net_aftermath).",
	"v0.7.95 - FIX multiplayer: la sequenza dei turni non si rompe piu' ('un giocatore avanti, l'altro bloccato'). Causa: un input del CLIENT veniva etichettato col giocatore DI TURNO invece che col proprio seggio, cosi' un tocco della Cina mentre toccava agli USA chiudeva/agiva il turno degli USA (USA avanti, Cina bloccata). Ora: 1) il client puo' agire SOLO come se' stesso e fuori dal proprio turno l'input viene ignorato; 2) l'host forza il seggio del mittente (autenticato dal trasporto), scartando comandi spacciati per un altro giocatore; 3) l'host ribroadcasta lo stato dopo OGNI cambiamento, inclusi gli avanzamenti di fase/turno che non passano da un comando (prima il client poteva restare indietro). +1 test di regressione sui turni in rete (host<->client).",
	"v0.7.94 - ONLINE via Internet (relay): ora si gioca anche DA BROWSER/TELEFONO e FUORI dalla LAN, non solo tra app native sulla stessa rete. Come funziona: un piccolo server 'relay' (cartella relay/, da mettere online una volta - vedi relay/README.md) a cui host e client si collegano tutti in uscita via 'wss://'; ci si trova con un CODICE STANZA. Nella lobby: incolli l'URL del relay (viene ricordato), l'host preme «Ospita (Internet)» e ottiene un codice da condividere, gli altri «Entra (Internet)» con quel codice. Dal browser ora SI PUO' ospitare (il relay e' una connessione in uscita, non un server locale). La LAN diretta resta invariata. L'host resta l'arbitro; il relay inoltra i messaggi senza leggerli. +3 test del relay (protocollo stanze) e un test d'integrazione Godot<->relay end-to-end.",
	"v0.7.93 - Build per MAC (e ANDROID sbloccata). Aggiunto l'export macOS: artefatto 'world-order-macos' (un .zip con world-order.app), build UNIVERSALE per Mac Intel e Apple Silicon (M1/M2/M3); non e' firmata, quindi al primo avvio si sblocca una volta sola con 'xattr -dr com.apple.quarantine world-order.app' o click destro -> Apri. BONUS: il fix che serviva al Mac (abilitare le texture ETC2 ASTC, richieste dall'arm64) ha risolto anche il misterioso errore dell'APK Android, che ora si compila: era la stessa causa, ma Android la segnalava senza messaggio. Ora la pipeline produce TUTTE le app native: Linux, Windows, macOS e Android. Guida in docs/multiplayer-lan.md.",
	"v0.7.92 - APP NATIVE per la LAN: aggiunta la pipeline che genera le build native scaricabili da GitHub Actions. Servono perche' il multiplayer LAN funziona SOLO tra app native (dal browser non si puo' ospitare). DESKTOP (Linux + Windows): pronte e scaricabili. ANDROID (APK): ancora in lavorazione (l'export in CI da' un errore opaco di Godot, in indagine; non blocca le build desktop). Come si gioca: tutti sulla stessa rete, uno fa Ospita (LAN) e mostra il suo IP, gli altri si Uniscono con quell'IP, poi l'host preme Avvia. Guida in docs/multiplayer-lan.md.",
	"v0.7.91 - LOBBY: messaggi ONESTI sul Web. Da BROWSER non si puo' OSPITARE (una pagina web non puo' fare da server: prima dava un fuorviante 'porta occupata? Errore 1') e nemmeno unirsi a una LAN in 'ws://' (la pagina e' HTTPS e il browser blocca il contenuto misto). Quindi la LAN diretta funziona solo tra APP NATIVE (desktop/Android); per giocare da browser/telefono servira' un piccolo relay 'wss://' (versione online, prossimo passo). Aggiunta anche la chiusura immediata del socket quando si lascia la lobby (niente piu' 'porta occupata' ri-ospitando su nativo).",
	"v0.7.90 - MULTIPLAYER (turno completo in rete): le ultime azioni mancanti ora passano per il COMMAND BUS, quindi un client le puo' eseguire a distanza e l'host le arbitra: PRODUCE (la selezione di quanto produrre si compone in locale, poi si invia il risultato), COMMERCIO/TRADE (export/import per risorsa, venditore scelto, vendita Armate) e MOVE delle Armate (ogni spostamento sorgente->destinazione e il rientro in Riserva sono comandi singoli; l'host applica costo e limiti). Lo stato del Move viene sincronizzato negli snapshot cosi' il client sa quante Armate gli restano. In Hot Seat nulla cambia. +13 test (command bus + integrazione host/client via loopback con un Move end-to-end).",
	"v0.7.89 - LOBBY LAN (multiplayer giocabile in rete locale): nel menu, scegliendo «Online (LAN)» compare la lobby. Un giocatore fa «Ospita (LAN)» (mostra il proprio IP da condividere) e gli altri «Unisciti» inserendo quell'IP; quando tutti sono collegati l'host preme «Avvia partita» e tutti entrano nella stessa partita. L'host arbitra (possiede lo stato) e a ogni mossa invia a ciascun client il proprio stato REDATTO (ognuno vede solo la propria mano); i client inviano le mosse all'host. La modalità Hot Seat resta invariata. Prossimo passo: rifinire il turno interattivo lato client e poi la versione via Internet (relay).",
	"v0.7.88 - FIX IMPORTANTE sullo SCORING: per un bug (i numeri da JSON sono float e 'int in [float]' e' sempre falso in Godot) il controllo del round di punteggio era SEMPRE falso, quindi lo Scoring delle REGIONI non avveniva MAI, ne' al round 3 ne' al 6! Ora i round 3 e 6 segnano correttamente le maggioranze d'area delle Regioni. Inoltre, come da regolamento, ad OGNI round di punteggio (3 e 6) si segnano anche i 3 token Maggioranza (piu' money / armate sul board / Country alleate), prima conteggiati solo a fine partita.",
	"v0.7.87 - CARTE AUTO-INFLUENZA visibili: nelle partite a 2-3 giocatori le 2 carte Auto-Influence delle potenze NEUTRALI ora si vedono sulla mappa, in alto vicino al titolo, e restano visibili per tutto il round (vengono rivelate a inizio round; l'effetto si applica in Aftermath come prima).",
	"v0.7.86 - MULTIPLAYER: gli snapshot dell'host ora includono lo STATO DI INTERAZIONE (cosa attende il turno: scegli Regione, casella d'Influenza, ecc.), cosi' un client puo' essere pilotato dall'host e renderizzare gli highlight giusti durante il proprio turno. Base per il turno interattivo in rete. Ancora nulla di visibile in partita (manca la lobby).",
	"v0.7.85 - MULTIPLAYER (nucleo di rete): aggiunto il modulo NetSession host-authoritative con trasporto WebSocket (per la LAN ora, Internet poi con un relay) e un trasporto 'loopback' per i test. Il protocollo gestisce lobby, avvio e l'inoltro comando -> host -> snapshot REDATTO al client (ogni giocatore vede solo la propria mano). Nulla di visibile in partita ancora: manca la lobby nel menu e la sincronizzazione del turno interattivo (prossimi passi). +7 test di rete.",
	"v0.7.84 - Anteprima carte e regole del turno: la TRADUZIONE italiana ora appare SOVRAPPOSTA alla parte bassa della carta ingrandita (come a tradurre la carta stessa, copre l'inglese), dopo ~1 secondo che si sta fermi col mouse, con carattere piu' piccolo. Inoltre NON si puo' piu' premere 'Fine turno' senza aver prima giocato (o passato con la Moneta +10) una carta. Annullare un'azione NON brucia il turno: la carta resta in mano e puoi sceglierne un'altra (gia' corretto).",
	"v0.7.83 - AUDIT effetti carte: alcune carte multi-effetto risolvevano solo una parte. Corretti 4 effetti che erano no-op silenziosi: 'gain_money_per_fdi' (Return on Investment: +money per ogni FDI), 'repeat' (Private Military Corporations: ora ripete davvero il blocco con i suoi piazzamenti), 'spend_for_gain' (Main UN Funding Contributor: scegli quanto money spendere per il guadagno), 'research_free' (Minimize Bureaucracy: prendi gratis una carta Market e giocala subito). +3 test motore.",
	"v0.7.82 - AREE delle Regioni ricalibrate: i riquadri di evidenziazione e piazzamento (dove si droppano i Carri durante Move, si scelgono le Regioni per Engage, ecc.) erano enormi e si SOVRAPPONEVANO. Ora usano le 7 aree precise della guida posizioni: piu' piccole, una per Regione, senza piu' sovrapposizioni.",
	"v0.7.81 - TRADUZIONE ITALIANA dei testi delle carte: passando il mouse su una carta (mano, Market, Strategic Asset, Growth) ora a fianco dell'anteprima ingrandita compare la spiegazione dell'effetto tradotta in italiano, con carattere piu' piccolo. Tradotte 109 carte (abilita', Market, Strategic, Growth). L'inglese resta come riserva se manca la traduzione.",
	"v0.7.80 - Linee di EVIDENZIAZIONE piu' sottili: i bordi che evidenziano Regioni, celle d'Influenza, carte (selezione), zone Focus e le sorgenti di Move/Trade erano troppo spessi e ora sono assottigliati (restano comunque ben visibili).",
	"v0.7.79 - CHOOSE FOCUS completo: dopo aver scelto il Focus in Preparazione ora compare il passo opzionale AUMENTO PRODUZIONE (paga il costo per spostare un cubo Produzione di +1; se aumenti una PRIMARIA - Energia/Materie/Cibo - guadagni subito 1 di quella risorsa). Inoltre, quando produci un tipo elencato sulle tue carte Commercio, queste si rigirano a faccia in su (surplus per il Trade). Domestic permette di aumentare una primaria, Diplomatic la Diplomazia, Military le Armate.",
	"v0.7.78 - Multiplayer (passo 4): il COMMAND BUS copre ora anche 'Get a Growth Card', l'acquisto al Market (Research) e le scelte di Aftermath (scarta Engage per money/Difesa, aumenta Prosperita', Continua). Introdotto il gating per FASE: durante l'Aftermath il comando deve venire dal giocatore in scelta, non dal giocatore di turno. Sempre invisibile in partita.",
	"v0.7.77 - Multiplayer (passo 3): il COMMAND BUS ora copre anche le scelte sulla mappa e in plancia - clic su una Regione, clic su una cella d'Influenza, scelta di una nazione alleata (Invest/Build), attivazione abilita' continuative e sconto 'esaurisci alleato'. Tutto continua a funzionare come prima in partita; cambia solo che questi input passano per il punto unico (validati e pronti per la rete).",
	"v0.7.76 - Multiplayer (passo 2): introdotto il COMMAND BUS. Gli input di gioco 'scegli Focus', 'gioca carta' e 'fine turno' ora passano per un unico punto (apply_command) con validazione di forma e controllo del turno, invece di agire direttamente. E' invisibile in partita (stesso comportamento di prima), ma e' il meccanismo che permettera' di spedire le mosse via rete. Nuovo modulo GameCommands + test dedicato (verify_commands).",
	"v0.7.75 - Lavori preparatori per il GIOCO IN RETE (multiplayer): lo stato della partita ora si puo' SERIALIZZARE (snapshot completo: giocatori, regioni/influenza, market) e ricostruire identico, e c'e' la REDAZIONE per giocatore (ogni client vedra' la propria mano intera e quelle avversarie solo come numero). Nessun cambiamento visibile in partita: e' la base su cui costruiremo il multiplayer in LAN. +9 test motore (133 totali).",
	"v0.7.74 - Layout ancora piu' arioso: la MAPPA viene allineata a DESTRA e lo spazio 'grigio' che lasciava ai lati viene RECUPERATO per la colonna BOARD, ora un po' piu' larga (board, plancia e carte si adattano e crescono). Le carte ALLEATE sono un po' piu' piccole: ne entrano almeno 7 per riga. Le pile di carte uguali (xN) ora si sfalsano verso il BASSO, cosi' si vede la PRODUZIONE della carta sotto invece del solo bordo superiore.",
	"v0.7.73 - Barra in alto RICALIBRATA: l'HUD si compatta (niente piu' spazio vuoto ne' doppioni con la riga sotto) e la BARRA SCELTE ha altezza FISSA con testo piu' piccolo, cosi' non sconfina piu' sulla mappa/board. Il tasto 'Fine turno' non e' piu' nell'angolo in alto a destra (scomodo, a volte tagliato): ora e' un tasto fisso in BASSO a destra, accanto alle linguette. Corretto il testo del turno (non si sceglie il Focus durante l'azione). Cornice delle caselle Influenza piu' sottile.",
	"v0.7.72 - Pannello board riorganizzato: in alto la PLANCIA con la carta COMMERCIO a fianco (allineata in alto) e le carte PRODOTTO subito SOTTO la carta Commercio (piu' piccole, riga larga quanto la carta). Sotto, le carte nazione ALLEATE in una fila (almeno 6 per riga, le altre vanno a capo); piu' sotto ancora le carte CRESCITA quando acquistate.",
	"v0.7.71 - RESEARCH come BOARD MERCATO: niente piu' popup che copre tutto. Durante la Research, al posto della mappa (a destra) compare il MERCATO (carte Market + 'Cambia Market' + le tue Country alleate da esaurire per +Research), mentre la tua board resta visibile a sinistra. Inoltre nel pannello board le carte PRODOTTO ora stanno a DESTRA della carta Commercio sulla stessa riga (sopra le carte alleate).",
	"v0.7.70 - NUOVO LAYOUT piu' ergonomico: la BOARD del giocatore e' ora una finestra SEPARATA a SINISTRA, sempre visibile, e la MAPPA sta a DESTRA - zoomando la mappa la board non si ingrandisce e non serve piu' collassarla. Nel pannello board, in colonna: plancia, poi carta Commercio + carte prodotto, poi carte nazione alleate, poi carte crescita. La MANO resta a tutta larghezza in basso: aperta si sovrappone a mappa e board (non comprime le carte), collassata e' una barra sottile. Le linguette in basso scelgono quale board guardare (sempre visibile).",
	"v0.7.69 - Tante migliorie: (1) COMMERCIO: niente più cerchi blu - ogni prodotto e' la sua ICONA; toccala per selezionarla (si illumina e va in primo piano), ri-toccala per deselezionarla o (se due prodotti stanno sulla stessa casella) passare all'altro; poi la trascini o tocchi una casella per spostarla. (2) IMPORT: +1 Diplomazia solo comprando l'INTERA carta del venditore (es. tutti e 3 dalla Russia), come da regolamento. (3) PREPARAZIONE: il round 1 non si fa (tutti partono Domestic); dal round 2 il Focus si sceglie cliccando una COLONNA evidenziata sulla plancia (niente piu' bottoni). (4) Tolti i simboli non sempre visualizzabili dal font (frecce, ecc.), sostituiti con testo.",
	"v0.7.68 - IMPORT nel Commercio com'è giusto: la quantità che puoi importare di un prodotto è la SOMMA dei simboli Import delle tue Country alleate PIÙ quanto vende il GIOCATORE che scegli. Le bandiere dei venditori sono alternative TRA LORO (ne scegli una), ma quella scelta si AGGIUNGE alla base delle tue alleate (es. 'importabili 2 alleate + 1 da Europa = 3'). 'Solo alleate' = compri dalla Riserva senza Diplomazia; scegliendo una superpotenza le sue unità le paghi a lei e prendi +1 Diplomazia. La barra mostra il totale e la composizione.",

	"v0.7.67 - FIX ciclo prodotti nel Commercio: quando due prodotti stanno sulla stessa casella, toccando l'anello '' ora si CICLA davvero tra loro. Prima il trascinamento (che su touch parte anche da un tocco breve) 'rubava' il tocco e selezionava sempre il primo prodotto; ora su quelle caselle il tocco è dedicato al ciclo (il drag resta sulle caselle con un solo prodotto).",

	"v0.7.66 - COMMERCIO più chiaro: (1) la selezione del prodotto torna SULLA CASELLA della plancia (tocca o trascina il token, come prima) - tolti i bottoni-prodotto dalla barra che rovinavano il feeling del drag. Se due prodotti stanno sulla STESSA casella (es. Servizi e Cibo), l'anello mostra '': ri-toccando si CICLA tra loro. (2) Ora è CHIARO da quale giocatore compri: ogni sorgente mostra la BANDIERA + il NOME della superpotenza (es. 'Europa', 'Cina') e quella scelta è evidenziata in ORO - cliccarla 'sblocca' l'acquisto da quel giocatore. La sorgente 'Banca' resta indicata con i nomi delle TUE Country alleate.",

	"v0.7.65 - FIX di interazione sulla mappa: (1) le EVIDENZIAZIONI ora si vedono davvero - le Regioni da scegliere (Engage, Move...) hanno il bordo azzurro e le caselle Influenza valide sono grandi e colorate (verde = permanente, viola = temporanea). Prima un dettaglio dei bottoni 'flat' le rendeva invisibili (apparivano solo al passaggio del mouse). (2) DRAG&DROP Armate zona->zona: trascinare un carro non sposta più la mappa (il pan è sospeso durante un trascinamento). (3) AFTERMATH: la plancia del giocatore si CHIUDE, così la mappa è piena e puoi scartare gli Engage token toccandoli; 'Aumenta Prosperità' è un bottone chiaro nella barra. (4) BARRA in alto: niente più doppione - la riga di stato si nasconde quando è attiva la barra delle scelte. (5) COMMERCIO: scegli il prodotto con bottoni espliciti (En/RM/Food/CG/Serv con la quantità), niente più ambiguità quando due prodotti stanno sulla stessa casella; e la sorgente 'Banca' ora mostra le TUE Country alleate (i loro nomi), così capisci da chi importi.",

	"v0.7.64 - PREPARAZIONE non più automatica: a inizio di OGNI round ogni potenza SCEGLIE il Focus (Domestic / Diplomatic / Military) con bottoni chiari nella barra in alto - ognuno mostra cosa fa (quante Country prepara, cosa produce). Scelto il Focus, vengono applicate le azioni legate (ready delle Country card + Produzione del Focus) e si può OPZIONALMENTE aumentare una Produzione spendendo Energia; 'Continua' passa alla potenza successiva, poi inizia la fase Azione. CARTE STRATEGICHE: tolte dal doppione sulla board - ora stanno SOLO nella mano, più GRANDI (alte quanto le carte) e senza l'etichetta 'Strategica'.",

	"v0.7.63 - COMMERCIO tutto nella BARRA IN ALTO (non più ancorato alla plancia) e bandiere delle sorgenti 'compra da:' ALTE QUANTO IL TESTO (niente più icone giganti). I bottoni di OGNI scelta ora hanno una chiara FORMA da pulsante (sfondo, bordo, padding). Tolti i caratteri non riconosciuti (la 'Banca' e 'la Moneta +10' al posto delle emoji). Selezionando una carta della mano ora si VEDE bene: bordo verde sulla scelta e le altre carte si oscurano. AFTERMATH tutto sulla mappa/plancia: gli Engage token si scartano TOCCANDOLI sulla mappa (-> money o Difesa) e la Prosperità si aumenta toccando la prossima corona sulla plancia; intestazione e 'Continua' nella barra in alto. Anche il PRODUCE ora ha i controlli nella barra in alto.",

	"v0.7.61 - La barra del MOVE non galleggia più sulla mappa: i controlli (vassoio Riserva da cui trascinare i carri, 'Fine spostamento' e 'Annulla' se non hai ancora mosso) sono ora nella barra in alto, che spinge giù la mappa senza coprirla. 'Annulla' (prima di muovere) ridà la carta senza consumare la giocata.",

	"v0.7.60 - PRODUCE sulla PLANCIA (niente popup): come il Commercio, ora imposti quanto produrre toccando le caselle sulla resource track (entro la tua Produzione). Le caselle mostrano il guadagno e, per le secondarie, il costo in primarie (es. '+2 -2,-2'); le Armate si producono con +/- nella barra in cima (-1 Materia cad.). Conferma/Annulla in cima al cassetto.",

	"v0.7.59 - FIX: annullare il COMMERCIO non consuma più la giocata del turno né scarta la carta. Prima 'Annulla' nel Commercio chiudeva la carta (come se l'avessi giocata): ora la carta resta in mano e puoi giocarne un'altra.",

	"v0.7.58 - SCONTO esaurendo alleati: ora si fa CLICCANDO le carte delle tue nazioni alleate della Regione direttamente sulla plancia (un click la attiva per lo sconto, un altro la annulla); la barra in alto mostra lo sconto in tempo reale (-N Dip) con 'Conferma sconto' / 'Salta'. Niente più popup.",

	"v0.7.57 - SCELTE nella BARRA in alto (niente più popup sopra la board): le scelte a opzioni (es. quante Armate spostare, scegli una risorsa/bersaglio) ora compaiono come BOTTONI chiari in una barra subito sotto l'HUD, che spinge giù la mappa senza coprirla. UI pulita.",

	"v0.7.56 - INFLUENZA sempre SULLA MAPPA: anche la scelta dello slot per Engage, Invest e Build a Base ora si fa toccando una casella evidenziata sul tabellone (verde = permanente, viola = temporanea), come per add_influence. Eliminato il popup 'Influenza: quale slot?' - meno testo sopra la board.",

	"v0.7.55 - MANO ridisegnata, niente più popup 'Come giochi?': nella mano, dopo le 6 carte, ci sono il gettone Moneta +10 e le tue carte STRATEGICHE. Tocchi una carta per SELEZIONARLA (si evidenzia), la ri-tocchi per GIOCARLA; oppure, con la carta selezionata, tocchi Moneta +10 per scartarla e prendere +10 money, o una carta Strategica per attivarla (la carta è il costo). Niente più scritte in sovraimpressione.",

	"v0.7.54 - FIX Commercio: comprando da una potenza ora si gira UNA SOLA carta prodotto per trade (non si sommano più tutte le carte scoperte). Quindi dalla Russia compri al massimo 3 Energia O 3 Materie Prime per trade (prima il bug permetteva fino a 9 perché contava tutte e 3 le carte). Le altre carte restano per altri trade/giocatori dello stesso round.",

	"v0.7.53 - FLUSSO TURNO più chiaro (indicatori): in alto ora vedi 'Round X/6 - Azione Y/4' con la FASE corrente (Azione / Research / Aftermath) e un grande '> POTENZA' nel colore di chi tocca; la sua linguetta-bandiera in basso ha un >. A ogni inizio turno una riga ti dice cosa puoi fare (gioca una carta, oppure scegli un Focus, poi 'Fine turno'). Niente schermate che interrompono.",

	"v0.7.52 - CALIBRAZIONE precisa (dalla tua guida): le carte nazione ora si posano ESATTAMENTE nei 2 slot stampati di ogni Regione (2 per zona), e il token ENGAGE va sul simbolo handshake stampato. Gli Engage successivi nella stessa Regione si impilano di lato, o SOTTO per Americhe/Europa/Asia Centrale. Coordinate rilevate al pixel dai pallini di 'Guida posizioni 3.png'.",

	"v0.7.51 - INFLUENZA scelta SULLA MAPPA: giocando una carta che dà Influenza, il cassetto si chiude e si evidenziano le CASELLE valide direttamente sul tabellone (VERDE = permanente, VIOLA = temporanea) in tutte le Regioni; un solo click posa l'Influenza (scegli Regione e tipo di slot insieme). Niente più finestra di scelta. (L'Influenza dell'Engage resta col suo popup rapido, perché la Regione è già scelta col costo.)",

	"v0.7.50 - ARMATE con DRAG&DROP: durante un Move ora TRASCINI i carri (immagini, non numeri). Niente più scelta della sorgente: trascini un carro dalla RISERVA su una Regione per schierarlo, da una Regione all'altra per spostarlo, o lo riporti sul vassoio RISERVA per farlo rientrare (gratis, annulla lo spostamento). Le Regioni sorgente (tue Armate) e destinazione valide sono evidenziate; valgono i costi e il limite del Move (5 money/carro). Il tap sorgente->destinazione tra Regioni resta come alternativa.",

	"v0.7.49 - UI scelte più pulita: quando devi fare una SCELTA dopo aver giocato una carta (es. scegliere una nazione alleata sulla plancia) o durante il Commercio, la MANO si collassa da sola così non copre la plancia e le scelte. Per le scelte sulla MAPPA (Move, zona per l'Engage, ecc.) è già tutta la plancia a chiudersi. Finita la scelta, la mano riappare.",

	"v0.7.48 - COMMERCIO con DRAG&DROP: ora puoi TRASCINARE il token di un prodotto lungo la sua resource track e RILASCIARLO su una casella valida (verso 0 vendi, verso 10 compri), invece di toccare. Compaiono le caselle valide come bersagli col denaro su ognuna. Il TAP resta come alternativa. (La sensazione del trascinamento è da confermare sul tuo dispositivo.)",

	"v0.7.47 - Verificati i dati del TABELLONE (board.json) di tutte e 7 le Regioni confrontandoli con l'immagine del tabellone stampato: slot Influenza permanenti/temporanei, bonus Maggioranza, costo Engage, bandiere (zone d'interesse) e cubi iniziali corrispondono tutti. La MENA (segnalata errata in passato) risulta ora corretta. Nessun valore da correggere.",

	"v0.7.46 - CARTE PRODOTTO (Commerce) con quantità per carta: ogni carta vende UNA risorsa fino al suo tetto. USA 1 Servizi/carta (x2), Cina 1 Beni/carta (x2), EU 1 Servizi O 1 Beni/carta (x2), Russia fino a 3 Energia O 3 Materie Prime/carta (x3). Comprando da una potenza si girano le sue carte fino a coprire la quantità richiesta, e ogni carta girata è consumata per intero (anche l'altra risorsa): es. compri 2 Energia dalla Russia -> giri 1 sola carta (restano 6 tra Energia/Materie sulle altre due).",

	"v0.7.45 - COMMERCIO: ora puoi VENDERE le ARMATE dalla riserva (20 money cad.). Nel banner Commercio compare la riga 'Vendi Armate (riserva N)' con - / + per scegliere quante venderne; il saldo money si aggiorna e la vendita occupa uno slot Export (come una risorsa). Le Armate NON sono importabili (puoi solo venderle). Completa la regola del Trade (il bene da 20 sono le Armate, non la Diplomazia).",

	"v0.7.44 - Schermata RESEARCH ripulita: il Market è ora una SOLA fila di carte alla giusta dimensione (niente più carte enormi che sforavano). Tolte le carte GROWTH da qui: non si comprano nella Research ma con l'azione 'Get a Growth Card' nella fase di Azione. Le Country alleate esauribili (+Research = loro valore) sono ora mostrate come CARTE reali, con '+N R' sotto, nello stesso stile del Market.",

	"v0.7.43 - Commercio (2-3 giocatori): ora puoi comprare anche dalle POTENZE NEUTRALI (es. la Cina compra Energia dalla Russia): compaiono le loro bandierine tra le sorgenti e si gira la loro Commerce card come al solito, pagando la banca - ma NON guadagni la +1 Diplomazia (solo comprando da un vero giocatore). Confermato che non puoi comprare e vendere la stessa risorsa nello stesso Commercio.",

	"v0.7.42 - Plancia del giocatore più ALTA (usa lo spazio verticale del cassetto: si legge meglio). Le carte prodotto (Commerce) ora stanno tutte in una riga larga esattamente quanto la carta Trade Deals sopra: con più carte (Russia 3) diventano più piccole, restando allineate.",

	"v0.7.41 - Fix Influenza permanente: i cubi AGGIUNTI in gioco ora vanno sulle vere caselle permanenti (la riga '1 1 1 1' sotto), non più ammucchiati sulle caselle colorate del setup. Le Influenze INIZIALI restano correttamente sulle caselle colorate in alto. Coordinate prese dalla guida (box celesti) per tutte e 7 le Regioni.",

	"v0.7.40 - COMMERCIO ORA SULLA TUA PLANCIA (niente più finestra separata): si lavora direttamente sulla resource track della plancia. Tocchi un prodotto (anello evidenziato sul token) e compaiono le caselle valide 0-10: verso 0 VENDI, verso 10 COMPRI, col denaro su ogni casella; il token si sposta dove tocchi. In cima al cassetto una barra mostra il saldo money, le bandierine per scegliere da quale potenza comprare, e Conferma/Annulla.",

	"v0.7.39 - CARTE PRODOTTO MULTIPLE: ogni potenza ha 2 carte prodotto (Commerce), 3 per la Russia, ora mostrate tutte nel cassetto; quelle usate nel round appaiono girate/grigie. Comprando un prodotto da una potenza si gira la CARTA SPECIFICA che lo mostra, quindi può venderlo una volta per ogni carta scoperta (prima si poteva comprare quel prodotto da lei una sola volta a round). Il limite d'acquisto da una potenza dipende dalle sue carte ancora scoperte.",

	"v0.7.38 - COMMERCIO rifatto: niente più tabella di testo. Ogni risorsa ha la sua traccia 0-10; tocchi una casella per spostare la risorsa - verso 0 VENDI, verso 10 COMPRI - con il denaro guadagnato/speso scritto su ogni casella. Per comprare da un altro giocatore scegli la sua BANDIERINA tra le sorgenti a fianco (Banca banca o le potenze che vendono quella risorsa), e il limite si adatta a quanto offre. (Il trascinamento drag&drop arriverà come passo successivo.)",

	"v0.7.37 - AUTO-INFLUENCE completo (partite a 2-3 giocatori): ora le potenze neutrali applicano DUE carte Auto-Influence per round (prima una sola), elencate nel riepilogo di fine round con dove piazzano Influenza/Armate. Il money del commercio (10) ora è CONDIZIONATO: una potenza neutrale lo dà a un giocatore solo se quel giocatore ha una Commerce card a faccia in su (che viene girata); se le ha già girate tutte, niente money.",

	"v0.7.36 - AFTERMATH ora INTERATTIVO: invece di applicare tutto in automatico, ogni giocatore ha un popup di scelte. L'INCREASE PROSPERITY è opzionale (decidi tu se spendere i Consumer Goods per avanzare). Puoi SCARTARE i tuoi Engage token per ottenere +5 money per Country alleata della Regione (Return on Investments) OPPURE +2 Difesa per Country alleata, applicata al THREAT di quella Regione. La quota FDI del Return on Investments resta automatica.",

	"v0.7.35 - L'anteprima ingrandita (flyover) delle carte al passaggio del mouse è ora ANCORATA A DESTRA e più contenuta: prima compariva grande al centro e copriva la board e i testi delle scelte nei popup.",

	"v0.7.34 - Research: ora puoi ESAURIRE le Country alleate (ancora ready) per aggiungere il loro valore ai punti Research, da spendere nel Market (come da regolamento: es. Singapore +2, Tajikistan +1). I pulsanti compaiono nella schermata Research.",

	"v0.7.33 - Schermata RESEARCH/MARKET rifatta e LEGGIBILE: le carte Market e Growth sono ora dimensionate per stare in una riga senza accavallarsi (le Growth mostrate in orizzontale), con il pannello scrollabile e adattato allo schermo. Aggiunte le regole del Market: comprando una carta ne compare una nuova a sinistra; puoi spendere 2 Research per scartare le 3 carte più a destra; a fine Research si scartano le carte più a destra (2 in 2 giocatori, 1 in 3, nessuna in 4).",

	"v0.7.32 - Regole allineate al regolamento (audit). Le ABILITÀ SPECIALI delle potenze ora contano davvero nello scoring: USA penalità se ha la maggioranza di Influenza in meno di 4 Regioni, Russia +VP per ogni Regione di zona con più Armate, Cina VP per le Regioni con FDI. A fine partita: +2 VP per ogni Strategic Asset non usato e +3 per l'Executive Order non usata. Spareggio del vincitore corretto (1° bonus Maggioranza -> più cubi Influenza -> vittoria condivisa). Azioni corrette: nel Trade il bene da 20 sono le Armate (la Diplomazia non si commercia) e la +1 Diplomazia si ha solo comprando da un altro giocatore; Engage richiede una Country alleata nella Regione; Invest/Build a Base una sola volta per Paese; Move solo in zona d'interesse o dove hai una Base; Build a Base muove fino al valore del Paese (non più 1 fisso); la Diplomazia in eccesso (>10) va persa. NATO USA/EU validata sulle potenze in gioco.",

	"v0.7.31 - Plance ricalibrate dai template utente: i segnalini di Produzione, Prodotti, Prosperità e Focus sono ora centrati sulle caselle stampate di tutte e 4 le potenze (USA, EU, Russia, Cina), con la posizione del tracciato Materie Prime specifica per potenza.",

	"v0.7.30 - Tolto il flyover (anteprima ingrandita) sulle carte nazione sul tabellone: si leggono zoomando la mappa. Corretto lo sfarfallio quando si trascina la mappa ingrandita: su un asse dove la mappa è più piccola della viewport ora viene centrata stabilmente invece di rimbalzare.",

	"v0.7.29 - Bugfix: dopo aver spostato i carri, 'Fine spostamento' (e quindi 'Fine turno') non bloccano più la partita. Le barre di spostamento non si accumulano più nascoste sul tabellone.",

	"v0.7.28 - Classifica maggioranza rifinita: bandiere più piccole, distanziate e posate sulla riga dei numeri (non coprono più i box temporanei); i PV accanto a ogni bandiera. Le Regioni che non segnano ancora (permanenti non tutti pieni) mostrano la classifica provvisoria in trasparenza.",

	"v0.7.27 - Cubi Influenza iniziali ora sulle CASELLE COLORATE in alto (non più sulle caselle valore \u201c1\u201d). Nuovo: CLASSIFICA MAGGIORANZA in tempo reale - su ogni numero della traccia maggioranza compare la bandiera della potenza in quella posizione + i PV (regole del regolamento: Influenza, pareggi rotti dalle Armate, i local contano ma non segnano, conteggia solo a permanenti pieni). Segnalino ROUND ora sulla casella giusta della traccia round. Tutto calibrato a pixel dal template.",

	"v0.7.26 - Segnalini di gioco ora visibili: Engage token (stretta di mano della potenza, max 3) sulle Regioni dove fai Engage; token FDI (Invest) e Base militare (Build a Base) sulle carte delle nazioni alleate. Prima non erano implementati.",

	"v0.7.25 - Quando bisogna toccare la mappa (spostare Armate, piazzare/convertire Influenza, ecc.) il cassetto plancia ora si CHIUDE da solo così la mappa è cliccabile (prima restava aperto e la bloccava). MENA allineato al tabellone reale (3 permanenti / 5 temporanee) con i cubi iniziali eu+usa+local.",

	"v0.7.24 - Posizioni RICALIBRATE A PIXEL dal template: segnalini Ordine di Turno ora esattamente nelle caselle 1°-4°; cubi Influenza sulle caselle reali di ogni Regione (incluse le tracce più lunghe di MENA); ogni superpotenza ha la sua casella per i carri armati (4 per Regione, 2x2: EU alto-sx, Russia alto-dx, USA basso-sx, Cina basso-dx).",

	"v0.7.23 - Le carte 'prodotto' delle superpotenze nel Commercio ora usano l'arte ufficiale (es. Russia: barile/energia + roccia/materie prime) invece delle icone generiche. I carri armati (Armate) nelle Regioni sono ora centrati sull'area armate calibrata di ogni Regione (sopra le sagome stampate), non più nel centro generico del riquadro.",

	"v0.7.22 - Segnalini Ordine di Turno ricalibrati nelle caselle 1°-4° (erano spostati nella mappa). Cubi Influenza un po' più grandi. Le Growth card acquisite ora compaiono come carte vicino alla plancia (colonna accanto agli Strategic Asset), non più solo come testo.",

	"v0.7.21 - Cubi Influenza ora posati sulle CASELLE stampate di ogni Regione (slot permanenti sopra la linea, temporanei sotto) invece che ammucchiati nell'angolo: coordinate calibrate per tutte e 7 le Regioni. La mappa inoltre si ri-centra/adatta sempre alla viewport finché non la sposti a mano.",

	"v0.7.20 - UI tabellone e plancia: la plancia NON si deforma più (rapporto bloccato); la barra in alto è ora FUORI dalla mappa (mappa incastonata tra barra e linguette) e la mappa si trascina di nuovo col mouse. Ricalibrate le carte Country sulle Regioni, i cubi di Produzione e i token Risorse sulla plancia, e i segnalini Ordine di Turno (più grandi e centrati). Il cassetto è ora a colonne (plancia - nazioni amiche - Commercio con carte prodotto - Strategic Asset in verticale a destra), senza etichette e senza icone illeggibili.",

	"v0.7.19 - Fasi del round più fedeli: AFTERMATH ora include Return on Investments (incassi 2 money x valore Paese per ogni FDI da Invest). PREPARATION (dal 2° round) ora rivela/ruota le carte Country delle Regioni. Il FOCUS è tornato un passo di Preparation: si sceglie GRATIS una volta per round (non costa più un'azione), con ready/produce associati.",

	"v0.7.18 - Segnalini sul tabellone: PUNTI VITTORIA (bandiere sulla traccia perimetrale 0-99), ORDINE DI TURNO (bandiere nelle 4 caselle 1°-4° sotto il titolo) e segnalino ROUND. Tolta la riga in alto con VP/Prosperità che copriva la mappa (la barra ora mostra solo round/turno + denaro + Fine turno; la Prosperità è sulla plancia).",

	"v0.7.17 - Influenza: ora SCEGLI tu se mettere il cubetto in slot PERMANENTE (sopra, resta a fine partita) o TEMPORANEO (sotto, più VP ma spingibile), come da regolamento. Vale per Engage, Invest, Build a Base e gli effetti carta (quando un permanente è libero).",

	"v0.7.16 - Mappa: ora puoi TRASCINARLA col mouse anche da zoomata (le Regioni catturano il click solo quando devi sceglierne una). Influenza iniziale resa come CUBETTI colorati (con conteggio) invece di pallini.",

	"v0.7.15 - Chiusi 6 effetti carta che prima non facevano nulla: reset_influence (proteggi Influenza temporanea), increase_production (+N a una traccia), ready_country (prepara N nazioni), trash/discard (elimina/scarta carte), increase_prosperity. Ora 106/109 carte hanno tutti gli effetti eseguiti.",

	"v0.7.14 - Gioco a FACCIA IN GIÙ: toccando una carta scegli se giocarla per la sua azione, oppure a faccia in giù per +10 money o per attivare uno dei tuoi 2 STRATEGIC ASSET (le carte speciali del setup, usabili una volta). I Strategic Asset sono mostrati nel cassetto (grigi se usati).",

	"v0.7.13 - Setup: Armate iniziali = Produzione di Armate (in riserva). Modificatori di carta condizionali sul Trade: 'conta Energia x2' (e Energia/Materie Prime, es. Energy Titan) raddoppiano i simboli Export; bonus Influenza concesso solo se hai esportato Beni/Servizi (o 4 Energia).",

	"v0.7.12 - Focus completo: la Focus action ora PRODUCE il tipo del Focus (Domestic->Beni/Servizi, Diplomatic->Diplomazia, Military->Armate in riserva) e prepara il giusto numero di Country card (Domestic 1, Diplomatic 4, Military 2). AUTO-INFLUENCE: con meno di 4 giocatori, ogni fine round le potenze neutrali piazzano Influenza/Armate da una carta Auto-Influence (mostrata nel riepilogo), così contano per scoring e maggioranze.",

	"v0.7.11 - Azioni domestiche. PRODUCE rifatto: scegli quante risorse generare da PIÙ tracce nella stessa azione (primarie gratis, secondarie consumano le primarie; le Armate vanno nella riserva). GET A GROWTH CARD: le carte Sviluppo si scelgono come immagini (con flyover), non più da lista testuale; le non acquistabili sono in grigio.",

	"v0.7.10 - Azioni economiche (Invest): le nazioni amiche ESAURITE ora si vedono (grigie e ruotate, come una carta tapped), così distingui a colpo d'occhio quali puoi ancora usare per Invest/Build a Base.",

	"v0.7.9 - Azioni militari. Pedine ARMATA (tank colorati) disegnate sulla mappa, impilate al centro della Regione; riserva del giocatore in alto sulla plancia. MOVE rifatto: scegli SORGENTE (Riserva o una Regione con tue Armate) e DESTINAZIONE, spostamento libero su qualsiasi Regione (5 money/Armata). Tolto anche qui il tap-diretto: Invest/Build a Base richiedono di giocare la carta.",

	"v0.7.8 - Azioni diplomatiche: ora SERVE giocare la carta (tolto l'Engage/Improve rapido toccando mappa/nazione). Nuovo popup per esaurire le nazioni amiche della Regione e scontare il costo in Diplomazia (Engage e Improve Relations).",

	"v0.7.7 - Carta Commercio (Trade Deals) mostrata accanto alle nazioni amiche (clic = apre il Trade). Le carte della stessa nazione ora si IMPILANO (badge xN): più carte = più simboli Export/Import, quindi più capacità di commercio con quella nazione.",

	"v0.7.6 - Denaro iniziale corretto per potenza: USA 30, UE 25, Cina 20, Russia 15 (nel setup).",

	"v0.7.5 - Denaro con le MONETE vere del gioco (asset TTS): la cifra è resa come pila di monete nei tagli 20/10/5/1 (scomposizione automatica), con il totale a fianco.",

	"v0.7.4 - Commercio tra giocatori: importando da un altro giocatore lui incassa il money e +1 Servizio, e la sua Commerce card si gira (1x/round). Abilità continuative completate: Focus action prepara le Country card (2 + bonus), e 'extra_play_first_turn' dà +1 carta al primo turno. Ora il turno = 1 azione (giochi 1 carta o fai Focus).",

	"v0.7.3 - Azione TRADE interattiva: scegli Export/Import per risorsa con i cap dalle nazioni amiche (simboli Export/Import) e dalla carta Trade Deals (limite 2/3 transazioni, una risorsa per transazione). Export incassa money, Import lo spende; +1 Diplomazia comprando dagli altri. saldo money in tempo reale.",

	"v0.7.2 - Audit costi: ogni azione paga il suo costo; rifiutata con messaggio se non puoi. La produzione secondaria consuma le primarie. Trade muove davvero le risorse.",

	"v0.7.0 - Move multi-regione e abilità continuative (ongoing): pesca extra a inizio round, pannello once-per-round.",

	"v0.6.7 - Regole: ordine di turno corretto (più VP gioca per primo). Strategic Asset nel setup (pesca 3, tiene 2 -> VP iniziali). Vedi TODO.md per lo stato regole/meccanica.",

	"v0.6.6 - Cubi produzione ricalibrati (3 colonne: erano sbagliati materie prime/grano/diplomazia). Linguette potenze con BANDIERE su barra dedicata in basso (non coprono la mappa). Mano collassabile (toggle) così non copre mai la plancia.",

	"v0.6.5 - Setup iniziale esatto: produzioni di partenza corrette per ogni potenza, risorse iniziali = produzione, nazioni amiche iniziali complete (4-5 per potenza). Nazioni amiche a destra della plancia (griglia). Prosperità e risorse ricalibrate.",

	"v0.6.4 - Cassetto: plancia a sinistra, nazioni amiche, mano in basso. Segnalini ancorati alla plancia.",

	"v0.6.3 - FIX plancia gigante: all'immagine mancava expand_mode=IGNORE_SIZE, non scendeva sotto la dimensione nativa (1400px).",

	"v0.6.2 - Tentativo tetto massimo plancia (non bastava da solo).",

	"v0.6.1 - Tolte le scritte ridondanti nel cassetto (intestazione potenza, 'La tua mano'). Flyover anche su mano e nazioni amiche. (Se non vedi questa versione nello splash, svuota la cache.)",

	"v0.6.0 - Flyover: passa sopra una carta per ingrandirla. Plancia adattiva (niente più gigante su desktop). Mano del giocatore sempre visibile in basso; carte più grandi.",

	"v0.5.0 - Mazzi potenza completi (12 carte, doppioni inclusi). Nazioni amiche iniziali (dal salvataggio TTS). Plancia con cubi/token reali e Focus cliccabile direttamente sull'immagine.",

	"v0.4.0 - Carte nazione originali posate negli slot designati del tabellone (coordinate dal TTS). Market/Growth illustrate.",

	"v0.3.0 - Mappa con zoom e trascinamento. Plance reali con i segnalini.",

	"v0.2.0 - UI responsive, cassetti per potenza.",

]

const POWERS := ["usa", "eu", "russia", "china"]
const POWER_NAME := {"usa": "USA", "eu": "UE", "russia": "Russia", "china": "Cina"}
const POWER_COLOR := {
	"usa": Color(0.45, 0.62, 0.9), "eu": Color(0.95, 0.82, 0.2),
	"russia": Color(0.9, 0.9, 0.9), "china": Color(0.9, 0.3, 0.3),
}

var _player_count := 2
var _count_buttons: Array[Button] = []
var _mode := "local"                  # "local" (griglia superpotenze) | "online" (lobby LAN)
var _mode_buttons: Array[Button] = []
var _seat_powers: Array = []          # potenza scelta per seggio (solo flusso Online)
var _seats_box: VBoxContainer
var _online_setup_box: VBoxContainer  # numero giocatori + potenze (visibile solo Online)
var _warn: Label

# --- Locale: ruolo per ognuna delle 4 superpotenze ---
# "human" = giocatore umano · "bot" = Automa · "neutral" = potenza neutrale (carte Auto-Influence)
var _role := {"usa": "human", "eu": "neutral", "russia": "neutral", "china": "human"}
var _role_box: VBoxContainer
var _local_setup_box: VBoxContainer   # label "Superpotenze" + griglia ruoli (visibile solo Locale)

# --- Difficolta' dei Bot ---
var _difficulty := "normal"           # "normal" | "hard"
var _diff_box: HBoxContainer
var _diff_buttons: Array[Button] = []

# --- Bot in Online: riempi i seggi non occupati da umani con i Bot (li guida l'host) ---
var _online_fill_bots := false
var _online_bots_check: CheckBox

# --- Lobby LAN (modalità Online) ---
var _net: NetSession = null
var _lobby_box: VBoxContainer
var _lobby_status: Label
var _players_list: VBoxContainer
var _ip_edit: LineEdit
var _host_btn: Button
var _join_btn: Button

# --- Online via Internet (relay wss://) ---
## URL di default del relay: pre-compilato nel campo della lobby (l'utente può comunque
## sovrascriverlo; l'ultimo usato viene ricordato). Deploy: vedi relay/README.md.
const RELAY_URL_DEFAULT := "wss://world-order-relay.onrender.com"
const RELAY_URL_SAVE := "user://relay_url.txt"
var _relay_url_edit: LineEdit
var _relay_room_edit: LineEdit
var _relay_host_btn: Button
var _relay_join_btn: Button
var _is_relay := false        # true se la sessione corrente passa dal relay
var _relay_room := ""         # codice stanza (host: assegnato dal relay; client: digitato)


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

	# --- LOCALE: per ognuna delle 4 superpotenze scegli Umano / Bot / Neutrale ---
	_local_setup_box = VBoxContainer.new()
	_local_setup_box.add_theme_constant_override("separation", 6)
	box.add_child(_local_setup_box)
	_local_setup_box.add_child(_section_label("Superpotenze (Umano / Bot / Neutrale)"))
	_role_box = VBoxContainer.new()
	_role_box.add_theme_constant_override("separation", 6)
	_local_setup_box.add_child(_role_box)
	_rebuild_roles()

	# --- ONLINE: numero giocatori + potenze per seggio (visibile solo in Online) ---
	_online_setup_box = VBoxContainer.new()
	_online_setup_box.add_theme_constant_override("separation", 6)
	_online_setup_box.visible = false
	box.add_child(_online_setup_box)
	_online_setup_box.add_child(_section_label("Numero di giocatori"))
	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 10)
	_online_setup_box.add_child(counts)
	for n in [2, 3, 4]:
		var b := Button.new()
		b.text = str(n)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(56, 40)
		b.pressed.connect(_on_count.bind(n))
		counts.add_child(b)
		_count_buttons.append(b)
	_online_setup_box.add_child(_section_label("Potenze"))
	_seats_box = VBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 6)
	_online_setup_box.add_child(_seats_box)
	# Bot online: i seggi non occupati da umani vengono guidati dai Bot (logica sull'host).
	_online_bots_check = CheckBox.new()
	_online_bots_check.text = "Riempi i posti liberi con i Bot"
	_online_bots_check.toggled.connect(_on_online_bots_toggled)
	_online_setup_box.add_child(_online_bots_check)

	box.add_child(_section_label("Modalità"))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10)
	box.add_child(modes)
	var loc := Button.new()
	loc.text = "Locale"
	loc.toggle_mode = true
	loc.custom_minimum_size = Vector2(140, 40)
	loc.pressed.connect(_on_mode.bind("local"))
	modes.add_child(loc)
	_mode_buttons.append(loc)
	var online := Button.new()
	online.text = "Online (LAN)"
	online.toggle_mode = true
	online.custom_minimum_size = Vector2(140, 40)
	online.pressed.connect(_on_mode.bind("online"))
	modes.add_child(online)
	_mode_buttons.append(online)

	# Selettore difficolta' dei Bot (visibile in Locale quando c'e' almeno un Bot).
	_diff_box = HBoxContainer.new()
	_diff_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_diff_box.add_theme_constant_override("separation", 10)
	_diff_box.visible = false
	box.add_child(_diff_box)
	var diff_lbl := Label.new()
	diff_lbl.text = "Bot:"
	_diff_box.add_child(diff_lbl)
	for d in [["normal", "Normale"], ["hard", "Difficile"]]:
		var b := Button.new()
		b.text = d[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 36)
		b.pressed.connect(_on_difficulty.bind(d[0]))
		_diff_box.add_child(b)
		_diff_buttons.append(b)

	_build_lobby(box)

	var opts := Button.new()
	opts.text = "Opzioni (prossimamente)"
	opts.disabled = true
	box.add_child(opts)

	_warn = Label.new()
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	box.add_child(_warn)

	var play := Button.new()
	play.text = ">  Avvia partita"
	play.custom_minimum_size = Vector2(0, 50)
	play.add_theme_font_size_override("font_size", 22)
	play.pressed.connect(_on_play)
	box.add_child(play)

	_update_selection(_count_buttons, 0)
	_update_selection(_mode_buttons, 0)   # Locale
	_update_selection(_diff_buttons, 0)   # Normale
	_set_count(2)
	_on_mode("local")


# --- LOCALE: ruolo per superpotenza (Umano / Bot / Neutrale) ---

const ROLE_LABELS := [["human", "Umano"], ["bot", "Bot"], ["neutral", "Neutrale"]]
const ROLE_COLORS := {
	"human": Color(0.6, 1.0, 0.6), "bot": Color(0.7, 0.85, 1.0), "neutral": Color(0.7, 0.7, 0.7),
}

func _rebuild_roles() -> void:
	for c in _role_box.get_children():
		c.queue_free()
	for power in POWERS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		var lbl := Label.new()
		lbl.text = POWER_NAME[power]
		lbl.custom_minimum_size = Vector2(72, 0)
		lbl.add_theme_color_override("font_color", POWER_COLOR[power])
		row.add_child(lbl)
		for rl in ROLE_LABELS:
			var b := Button.new()
			b.text = rl[1]
			b.toggle_mode = true
			b.button_pressed = (_role[power] == rl[0])
			b.custom_minimum_size = Vector2(80, 36)
			if _role[power] == rl[0]:
				b.add_theme_color_override("font_color", ROLE_COLORS[rl[0]])
			b.pressed.connect(_on_role.bind(power, rl[0]))
			row.add_child(b)
		_role_box.add_child(row)
	# _diff_box / _warn possono non esistere ancora alla prima costruzione (ordine in _ready).
	if _diff_box != null:
		_diff_box.visible = (_mode == "local") and _has_bot()
	if _warn != null:
		_validate()


func _on_role(power: String, role: String) -> void:
	_role[power] = role
	_rebuild_roles()


## Potenze attive (umane o bot) in modalita' Locale, in ordine fisso USA/EU/Russia/Cina.
func _active_powers() -> Array:
	var out := []
	for power in POWERS:
		if _role[power] == "human" or _role[power] == "bot":
			out.append(power)
	return out


func _bot_powers() -> Array:
	var out := []
	for power in POWERS:
		if _role[power] == "bot":
			out.append(power)
	return out


func _has_bot() -> bool:
	return not _bot_powers().is_empty()


# --- ONLINE: numero giocatori / potenze ---

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


func _on_difficulty(d: String) -> void:
	_difficulty = d
	_update_selection(_diff_buttons, ["normal", "hard"].find(d))


## Online: attiva/disattiva il riempimento dei posti liberi con i Bot (mostra la difficolta').
func _on_online_bots_toggled(on: bool) -> void:
	_online_fill_bots = on
	_diff_box.visible = (_mode == "online" and on) or (_mode == "local" and _has_bot())
	if _diff_buttons.size() == 2:
		_update_selection(_diff_buttons, 0 if _difficulty == "normal" else 1)
	_validate()


## Validazione: in Locale servono almeno 2 superpotenze attive (umane o bot); in Online ogni
## seggio deve avere una potenza distinta. Ritorna true se la configurazione e' avviabile.
func _validate() -> bool:
	if _mode == "local":
		var active: Array = _active_powers()
		if active.size() < 2:
			_warn.text = "Servono almeno 2 superpotenze Umane o Bot (le altre = Neutrali)."
			return false
		_warn.text = "" if _has_human() else "Nessun Umano: guarderai i Bot giocare."
		return true
	var chosen := {}
	for p in _seat_powers:
		if p == "" or chosen.has(p):
			_warn.text = "Assegna una potenza diversa a ogni giocatore."
			return false
		chosen[p] = true
	_warn.text = ""
	return true


func _has_human() -> bool:
	for power in POWERS:
		if _role[power] == "human":
			return true
	return false


# --- Modalita' / avvio ---

func _on_mode(m: String) -> void:
	_mode = m
	_update_selection(_mode_buttons, ["local", "online"].find(m))
	var online := (m == "online")
	_local_setup_box.visible = not online
	_online_setup_box.visible = online
	_lobby_box.visible = online
	_diff_box.visible = (_has_bot() if not online else _online_fill_bots)
	if not online:
		# Tornando in Locale si chiude la sessione di rete eventualmente aperta.
		_free_net()
		_reset_lobby_controls()
	if _diff_buttons.size() == 2:
		_update_selection(_diff_buttons, 0 if _difficulty == "normal" else 1)
	_validate()


func _on_play() -> void:
	if not _validate():
		return
	GameConfig.mode = _mode
	# --- LOCALE: le superpotenze attive sono i seggi; le Neutrali -> Auto-Influence. ---
	if _mode == "local":
		var active: Array = _active_powers()
		GameConfig.player_count = active.size()
		GameConfig.powers = active
		GameConfig.automa_powers = _bot_powers()
		GameConfig.automa_difficulty = _difficulty
		GameConfig.net = null
		get_tree().change_scene_to_file("res://scenes/board.tscn")
		return
	# --- ONLINE ---
	GameConfig.player_count = _player_count
	GameConfig.powers = _seat_powers.duplicate()
	GameConfig.automa_powers = []
	if _mode == "online":
		# In rete avvia SOLO l'host; i client entrano al segnale `started`.
		if _net == null or not _net.is_host():
			_warn.text = "Ospita una partita (i client partono quando avvii)."
			return
		# Seggi occupati da umani (< player_count); i restanti sono Bot se richiesto.
		var occupied := {}
		for pl in _net.lobby_players():
			var s := int((pl as Dictionary).get("seat", -1))
			if s >= 0 and s < _player_count:
				occupied[s] = true
		var bot_powers: Array = []
		for seat in range(_player_count):
			if not occupied.has(seat):
				bot_powers.append(_seat_powers[seat])
		if _online_fill_bots:
			if occupied.size() < 1:
				_warn.text = "Serve almeno 1 umano (l'host); i posti liberi diventano Bot."
				return
		elif not bot_powers.is_empty():
			_warn.text = "Aspetta che si colleghino %d giocatori (ora %d) — oppure spunta 'Riempi i posti liberi con i Bot'." % [_player_count, occupied.size()]
			return
		GameConfig.automa_powers = bot_powers if _online_fill_bots else []
		GameConfig.automa_difficulty = _difficulty
		GameConfig.net = _net
		_net.start_game(_seat_powers.duplicate(), GameConfig.automa_powers)
		get_tree().change_scene_to_file("res://scenes/board.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/board.tscn")


# --- Lobby LAN ---

## Costruisce il pannello lobby (nascosto finché non si sceglie la modalità Online):
## Ospita (LAN) / Unisciti con IP, stato della connessione e lista dei giocatori.
func _build_lobby(box: VBoxContainer) -> void:
	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 6)
	_lobby_box.visible = false
	box.add_child(_lobby_box)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_lobby_box.add_child(row)

	_host_btn = Button.new()
	_host_btn.text = "Ospita (LAN)"
	_host_btn.custom_minimum_size = Vector2(130, 36)
	_host_btn.pressed.connect(_on_host)
	row.add_child(_host_btn)

	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP host (es. 192.168.1.10)"
	_ip_edit.custom_minimum_size = Vector2(200, 36)
	row.add_child(_ip_edit)

	_join_btn = Button.new()
	_join_btn.text = "Unisciti"
	_join_btn.custom_minimum_size = Vector2(110, 36)
	_join_btn.pressed.connect(_on_join)
	row.add_child(_join_btn)

	# --- Online via Internet (relay wss://): funziona anche da browser e fuori dalla LAN ---
	var sep := Label.new()
	sep.text = "— oppure via Internet (relay) —"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	_lobby_box.add_child(sep)

	_relay_url_edit = LineEdit.new()
	_relay_url_edit.placeholder_text = "URL relay (es. wss://tuo-relay.onrender.com)"
	_relay_url_edit.custom_minimum_size = Vector2(440, 36)
	_relay_url_edit.text = _load_relay_url()
	_lobby_box.add_child(_relay_url_edit)

	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rrow.add_theme_constant_override("separation", 8)
	_lobby_box.add_child(rrow)

	_relay_host_btn = Button.new()
	_relay_host_btn.text = "Ospita (Internet)"
	_relay_host_btn.custom_minimum_size = Vector2(150, 36)
	_relay_host_btn.pressed.connect(_on_relay_host)
	rrow.add_child(_relay_host_btn)

	_relay_room_edit = LineEdit.new()
	_relay_room_edit.placeholder_text = "Codice stanza"
	_relay_room_edit.custom_minimum_size = Vector2(140, 36)
	rrow.add_child(_relay_room_edit)

	_relay_join_btn = Button.new()
	_relay_join_btn.text = "Entra (Internet)"
	_relay_join_btn.custom_minimum_size = Vector2(150, 36)
	_relay_join_btn.pressed.connect(_on_relay_join)
	rrow.add_child(_relay_join_btn)

	_lobby_status = Label.new()
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_status.custom_minimum_size = Vector2(440, 0)
	_lobby_status.add_theme_color_override("font_color", Color(0.8, 0.92, 0.8))
	_lobby_box.add_child(_lobby_status)

	_players_list = VBoxContainer.new()
	_players_list.add_theme_constant_override("separation", 2)
	_lobby_box.add_child(_players_list)


func _on_host() -> void:
	# Da BROWSER non si puo' ospitare: una pagina web non puo' aprire una porta in
	# ascolto (server). L'hosting LAN funziona solo dalle build NATIVE (desktop/Android).
	if OS.has_feature("web"):
		_lobby_status.text = "Dal browser non si puo' OSPITARE (un sito web non puo' fare da server). " \
			+ "Ospita dall'app desktop/Android e qui usa «Unisciti», oppure attendi la versione online con relay."
		return
	_free_net()
	_net = NetSession.new()
	_net.name = "NetSession"
	get_tree().root.add_child(_net)
	var err := _net.host_lan()
	if err != OK:
		_lobby_status.text = "Impossibile ospitare (porta occupata?). Errore %d" % err
		_free_net()
		return
	GameConfig.net = _net
	_net.lobby_changed.connect(_on_lobby_changed)
	_set_lobby_busy(true)
	_on_lobby_changed(_net.lobby_players())


func _on_join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		_lobby_status.text = "Inserisci l'IP dell'host."
		return
	# Dal browser (pagina HTTPS) un collegamento LAN in 'ws://' viene bloccato dal browser
	# (mixed content): serve un relay sicuro 'wss://'. La LAN diretta funziona tra app native.
	if OS.has_feature("web") and not (ip.begins_with("wss://")):
		_lobby_status.text = "Dal browser la LAN non e' raggiungibile (HTTPS blocca 'ws://'). " \
			+ "Servira' un relay 'wss://' (versione online). Per la LAN usa l'app nativa."
		return
	_free_net()
	_net = NetSession.new()
	_net.name = "NetSession"
	get_tree().root.add_child(_net)
	var err := _net.join_lan(ip)
	if err != OK:
		_lobby_status.text = "Connessione fallita. Errore %d" % err
		_free_net()
		return
	GameConfig.net = _net
	_net.lobby_changed.connect(_on_lobby_changed)
	_net.started.connect(_on_started)
	_net.connection_failed.connect(func(): _lobby_status.text = "Connessione fallita.")
	_set_lobby_busy(true)
	_lobby_status.text = "Connessione a %s… attendi che l'host avvii la partita." % ip


## HOST via relay: si collega al relay e ottiene un codice stanza da condividere.
## A differenza della LAN, dal browser SI PUO' ospitare (il relay e' una connessione in
## uscita, non un server locale).
func _on_relay_host() -> void:
	var url := _relay_url_edit.text.strip_edges()
	if url == "":
		_lobby_status.text = "Inserisci l'URL del relay (es. wss://tuo-relay.onrender.com)."
		return
	_free_net()
	_is_relay = true
	_net = NetSession.new()
	_net.name = "NetSession"
	get_tree().root.add_child(_net)
	var err := _net.host_relay(url)
	if err != OK:
		_lobby_status.text = "URL relay non valido. Errore %d" % err
		_free_net()
		return
	_save_relay_url(url)
	GameConfig.net = _net
	_net.lobby_changed.connect(_on_lobby_changed)
	_net.relay_ready.connect(_on_relay_ready)
	_net.relay_error.connect(_on_relay_err)
	_net.connection_failed.connect(func(): _lobby_status.text = "Relay irraggiungibile: controlla l'URL.")
	_set_lobby_busy(true)
	_lobby_status.text = "Connessione al relay…"


## CLIENT via relay: entra nella stanza `codice` passando dal relay.
func _on_relay_join() -> void:
	var url := _relay_url_edit.text.strip_edges()
	var room := _relay_room_edit.text.strip_edges().to_upper()
	if url == "":
		_lobby_status.text = "Inserisci l'URL del relay."
		return
	if room == "":
		_lobby_status.text = "Inserisci il codice stanza dato dall'host."
		return
	_free_net()
	_is_relay = true
	_net = NetSession.new()
	_net.name = "NetSession"
	get_tree().root.add_child(_net)
	var err := _net.join_relay(url, room)
	if err != OK:
		_lobby_status.text = "URL relay non valido. Errore %d" % err
		_free_net()
		return
	_save_relay_url(url)
	GameConfig.net = _net
	_net.lobby_changed.connect(_on_lobby_changed)
	_net.started.connect(_on_started)
	_net.relay_ready.connect(_on_relay_ready)
	_net.relay_error.connect(_on_relay_err)
	_net.connection_failed.connect(func(): _lobby_status.text = "Relay irraggiungibile: controlla l'URL.")
	_set_lobby_busy(true)
	_lobby_status.text = "Connessione alla stanza %s…" % room


## Relay: stanza pronta. Host -> mostra il codice da condividere; client -> attende l'host.
func _on_relay_ready(room: String) -> void:
	_relay_room = room
	if _net != null and _net.is_host():
		_on_lobby_changed(_net.lobby_players())
	else:
		_lobby_status.text = "Connesso alla stanza %s — attendi che l'host avvii la partita." % room


## Relay: la stanza ha rifiutato (codice errato, piena, host uscito…).
func _on_relay_err(code: String, msg: String) -> void:
	var human := msg
	if human == "":
		human = "Errore relay: %s" % code
	_lobby_status.text = human
	_set_lobby_busy(false)
	_is_relay = false


## HOST e CLIENT: aggiorna la lista dei giocatori in lobby.
func _on_lobby_changed(players: Array) -> void:
	for c in _players_list.get_children():
		c.queue_free()
	for pl in players:
		var l := Label.new()
		l.text = "Seggio %d — %s" % [int((pl as Dictionary).get("seat", 0)), String((pl as Dictionary).get("name", ""))]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_players_list.add_child(l)
	if _net != null and _net.is_host():
		if _is_relay:
			_lobby_status.text = "Stanza ONLINE «%s» — condividi il codice. Giocatori: %d (servono %d). Poi premi «Avvia partita»." % [
				_relay_room, players.size(), _player_count]
		else:
			_lobby_status.text = "In ascolto su %s:%d — condividi questo IP. Giocatori: %d (servono %d). Poi premi «Avvia partita»." % [
				_local_ip(), NetSession.PORT_DEFAULT, players.size(), _player_count]


## CLIENT: l'host ha avviato la partita -> entra nella scena di gioco.
func _on_started(_seat: int, _powers: Array) -> void:
	GameConfig.net = _net
	GameConfig.mode = "online"
	get_tree().change_scene_to_file("res://scenes/board.tscn")


## Chiude e rimuove la sessione di rete corrente (se presente).
func _free_net() -> void:
	if _net != null:
		_net.close()   # libera SUBITO il socket/porta (queue_free e' differito)
		_net.queue_free()
		_net = null
	GameConfig.net = null
	_is_relay = false
	_relay_room = ""


## Abilita/disabilita tutti i controlli della lobby (LAN + relay) mentre si e' connessi.
func _set_lobby_busy(busy: bool) -> void:
	if _host_btn != null: _host_btn.disabled = busy
	if _join_btn != null: _join_btn.disabled = busy
	if _ip_edit != null: _ip_edit.editable = not busy
	if _relay_host_btn != null: _relay_host_btn.disabled = busy
	if _relay_join_btn != null: _relay_join_btn.disabled = busy
	if _relay_url_edit != null: _relay_url_edit.editable = not busy
	if _relay_room_edit != null: _relay_room_edit.editable = not busy


## Ricorda l'ultimo URL di relay usato (così non va reincollato ogni volta).
func _load_relay_url() -> String:
	if FileAccess.file_exists(RELAY_URL_SAVE):
		var f := FileAccess.open(RELAY_URL_SAVE, FileAccess.READ)
		if f != null:
			return f.get_as_text().strip_edges()
	return RELAY_URL_DEFAULT


func _save_relay_url(url: String) -> void:
	var f := FileAccess.open(RELAY_URL_SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(url)


func _reset_lobby_controls() -> void:
	_set_lobby_busy(false)
	_is_relay = false
	_relay_room = ""
	if _players_list != null:
		for c in _players_list.get_children():
			c.queue_free()
	if _lobby_status != null:
		_lobby_status.text = ""


## Primo indirizzo IPv4 di LAN (non loopback / link-local): da mostrare ai client.
func _local_ip() -> String:
	for a in IP.get_local_addresses():
		var s := String(a)
		if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("169.254."):
			return s
	return "127.0.0.1"


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
	head.text = "Novità - %s" % VERSION
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
		e.text = "- " + String(entry)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(310, 0)
		e.add_theme_font_size_override("font_size", 12)
		e.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
		list.add_child(e)


func _update_selection(buttons: Array, idx: int) -> void:
	for i in buttons.size():
		buttons[i].button_pressed = (i == idx)
