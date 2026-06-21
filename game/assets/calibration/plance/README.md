# Calibrazione plance (4 potenze) — template utente 2026-06-21

`template_0..3.png` (1655×1182, stesso rapporto h/w 0.714 delle plance reali):
pallini BLU al centro delle caselle di **Produzione**, dei **Prodotti**, della
**Prosperità** e del **Focus**. La posizione dei **carri/Armate va bene** (non toccarla).

`detected_dots.json`: pallini già rilevati e normalizzati (per immagine).
Conteggi: img0=54, img1=49, img2=52, img3=50 (i conteggi diversi → le track di
produzione hanno lunghezze diverse per potenza).

## ✅ Fatto (2026-06-21)
1. **Template→potenza** (dalle lunghezze dei tracciati): `0=USA, 1=China,
   2=Russia, 3=EU`. Verificato sovrapponendo i pallini alle `player_boards/*.jpg`:
   cadono al centro delle caselle stampate.
2. **Mappatura pallini**: riga alta = Produzione energy/raw_materials/food; riga
   media = consumer_goods (sx) · diplomacy (centro) · **produzione armate** (dx);
   riga bassa-sx = services; cerchi = Focus (3); corone = Prosperità (cerchio
   iniziale + 5); banda bassa = Prodotti/Risorse (0, poi 1-5 e 6-10).
3. **Scelta: griglia CONDIVISA** — i dati confermano stesse coordinate d'inizio per
   tutte le potenze (cambia solo la lunghezza dei tracciati). Aggiornate le costanti
   in `board_view.gd` (`PROD_PITCH`, `PROD_TRACKS`, `FOCUS_POS`, `PROSPERITY_POS`,
   `RES_TRACK_X`, `_resource_slot`). **Unica eccezione**: `raw_materials` parte da x
   diversa per potenza → nuova costante `RAW_MATERIALS_X`. La riserva carri/Armate in
   alto (`RESERVE_ARMY_POS`) NON è marcata nei template e resta invariata; il
   tracciato di **produzione** armate invece è stato calibrato (riga della Diplomazia).
4. **Verificato a video**: overlay dei pallini + simulazione dello stato di setup
   (produzione iniziale + Focus + Prosperità + token risorse) su tutte e 4 le plance,
   errore di fit ≤ ~1px sulla larghezza tipica della plancia.
