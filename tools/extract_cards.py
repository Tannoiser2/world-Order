#!/usr/bin/env python3
"""
World Order - Card extraction pipeline.

Estrae le singole carte dagli sprite-sheet del prototipo Tabletop Simulator
(Tabelle_Materiali/World Order/) e produce immagini singole + un manifest.

Il salvataggio TTS e' una partita a meta', quindi le carte sono sparse tra
mazzi e tavolo: le deduplichiamo per identita' (sheet + cella della griglia)
e le classifichiamo per forma, che mappa in modo affidabile il tipo di carta.

Uso:
    python tools/extract_cards.py --source "/path/Tabelle_Materiali/World Order" \
                                  --out assets/cards --manifest data/cards_manifest.json
"""
import argparse, json, glob, os, re
from PIL import Image

# bucket per rapporto larghezza/altezza
def shape_bucket(w, h):
    r = w / h
    if 0.70 < r < 0.74:   return "country"            # 745x1040
    if 0.62 < r <= 0.70:  return "ability"            # 485x745 (ability/growth/auto-influence)
    if 1.35 < r < 1.45:   return "strategic_asset"    # 1000x716
    if r >= 1.45:         return "wide_aux"           # 745x485 trade deals / plance
    return "other"

def face_hash(url):
    return url.rstrip("/").split("/")[-1]

def index_local(source):
    local = {}
    for f in glob.glob(os.path.join(source, "Images", "**", "*"), recursive=True):
        if f.lower().endswith((".png", ".jpg")):
            m = re.search(r"([0-9A-F]{40})\.(png|jpg)$", os.path.basename(f))
            if m:
                local[m.group(1)] = f
    return local

def iter_cards(objs, local):
    """Genera ogni istanza di carta con sheet locale + posizione nella griglia."""
    def emit(o):
        cd = o.get("CustomDeck") or {}
        cid = o.get("CardID")
        if cid is None:
            return
        ck = str(cid // 100)
        v = cd.get(ck, {})
        W, H = v.get("NumWidth", 1), v.get("NumHeight", 1)
        idx = cid % 100
        row, col = divmod(idx, W)
        sheet = local.get(face_hash(v.get("FaceURL", "")))
        yield {"cardId": cid, "deckKey": ck, "grid": [W, H], "cell": [row, col],
               "sheet": sheet, "guid": o.get("GUID")}
    def walk(o):
        if o.get("Name") in ("Card", "CardCustom"):
            yield from emit(o)
        for c in o.get("ContainedObjects", []) or []:
            yield from walk(c)
    for o in objs:
        yield from walk(o)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, help="cartella 'World Order' con il .json e Images/")
    ap.add_argument("--out", required=True, help="cartella output immagini")
    ap.add_argument("--manifest", required=True, help="file manifest JSON")
    ap.add_argument("--format", default="jpg", choices=["jpg", "png"])
    ap.add_argument("--quality", type=int, default=88)
    args = ap.parse_args()

    save = glob.glob(os.path.join(args.source, "*.json"))[0]
    data = json.load(open(save))
    objs = data.get("ObjectStates", [])
    local = index_local(args.source)

    cache = {}
    def sheet_img(p):
        if p not in cache:
            cache[p] = Image.open(p).convert("RGBA")
        return cache[p]

    seen, records = set(), []
    counters = {}
    for c in iter_cards(objs, local):
        if not c["sheet"]:
            continue
        key = (c["sheet"], c["cardId"] % 100)
        if key in seen:
            continue
        seen.add(key)
        im = sheet_img(c["sheet"])
        W, H = c["grid"]
        cw, ch = im.width // W, im.height // H
        row, col = c["cell"]
        crop = im.crop((col*cw, row*ch, (col+1)*cw, (row+1)*ch))
        bucket = shape_bucket(cw, ch)
        n = counters.get(bucket, 0); counters[bucket] = n + 1
        name = f"{bucket}_{n:03d}.{args.format}"
        folder = os.path.join(args.out, bucket); os.makedirs(folder, exist_ok=True)
        out_im = crop.convert("RGB") if args.format == "jpg" else crop
        out_im.save(os.path.join(folder, name), quality=args.quality)
        records.append({"id": f"{bucket}_{n:03d}", "type": bucket,
                        "file": f"{bucket}/{name}", "size": [cw, ch],
                        "sourceSheet": os.path.basename(c["sheet"]),
                        "cell": c["cell"], "grid": c["grid"], "cardId": c["cardId"]})

    os.makedirs(os.path.dirname(args.manifest), exist_ok=True)
    json.dump({"count": len(records), "cards": records},
              open(args.manifest, "w"), indent=1, ensure_ascii=False)
    by = {}
    for r in records:
        by[r["type"]] = by.get(r["type"], 0) + 1
    print(f"Estratte {len(records)} carte uniche -> {args.out}")
    for k, v in sorted(by.items()):
        print(f"  {k}: {v}")

if __name__ == "__main__":
    main()
