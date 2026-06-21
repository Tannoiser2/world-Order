# Calibrazione plance (4 potenze) — template utente 2026-06-21

`template_0..3.png` (1655×1182, stesso rapporto h/w 0.714 delle plance reali):
pallini BLU al centro delle caselle di **Produzione**, dei **Prodotti**, della
**Prosperità** e del **Focus**. La posizione dei **carri/Armate va bene** (non toccarla).

`detected_dots.json`: pallini già rilevati e normalizzati (per immagine).
Conteggi: img0=54, img1=49, img2=52, img3=50 (i conteggi diversi → le track di
produzione hanno lunghezze diverse per potenza).

## Da fare (prossima sessione)
1. Identificare quale template = quale potenza: sovrapporre i pallini di ogni
   immagine su `game/assets/player_boards/{usa,eu,china,russia}.jpg` e vedere su
   quale i pallini cadono sulle caselle stampate.
2. Mappare ogni pallino all'elemento (track di Produzione per risorsa, Prodotti,
   Prosperità, Focus) leggendo le etichette della plancia sotto i pallini.
3. Decidere: griglia CONDIVISA (refine delle costanti in `board_view.gd`
   `PROD_TRACKS`/`PROD_PITCH`/`RES_TRACK_X`/`PROSPERITY_POS`/`FOCUS_POS`) oppure
   layout PER POTENZA (rifattorizzare `_build_plancia_view` a leggere coordinate
   per potenza da un JSON). NB: i carri (`PROD_TRACKS["armies"]`) restano invariati.
4. Verificare a video ciascuna delle 4 plance, poi commit.
