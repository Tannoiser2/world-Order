#!/usr/bin/env python3
"""Codifica il testo-effetto di ogni carta in 'effect_ops' (lista di operazioni
eseguibili dal motore) + 'effect_modifiers' (sfumature condizionali/ongoing).
Tabella esplicita per accuratezza. Le scelte (Paese/Regione/quantita') restano
da risolvere a runtime (UI/bot)."""
import json, glob, os

# Costruttori compatti di op.
def op(name, **kw): return dict(op=name, **kw)
def improve(): return op("improve_relations")
def engage(): return op("engage")
def trade(): return op("trade")
def invest(): return op("invest")
def build_base(): return op("build_base")
def move(maxn=None): return op("move", **({"max": maxn} if maxn else {}))
def get_growth(): return op("get_growth")
def produce(n=None, types=None): return op("produce", **({"count": n} if n else {}), **({"types": types} if types else {}))
def gain_money(a): return op("gain_money", amount=a)
def gain_res(t, a): return op("gain_resource", type=t, amount=a)
def gain_armies(a): return op("gain_armies", amount=a)
def gain_vp(a): return op("gain_vp", amount=a)
def draw(n): return op("draw", n=n)
def play_another(): return op("play_another")
def trash(loc="hand"): return op("trash", source=loc)
def ready_country(n=1): return op("ready_country", n=n)
def reset_influence(): return op("reset_influence")
def convert_influence(): return op("convert_influence")
def increase_prod(n): return op("increase_production", count=n)
def add_influence(perm=False): return op("add_influence", permanent=perm)
def sell_armies(n, money): return op("sell_armies", n=n, money=money)
def place_armies(n, regions=None): return op("place_armies", n=n, **({"regions": regions} if regions else {}))
def choice(*opts): return op("choice", options=list(opts))
def ongoing(tag): return op("ongoing", tag=tag)

T = {}  # effect_text -> {"ops":[...], "modifiers":[...]}
def reg(text, ops, mods=None): T[text] = {"ops": ops, "modifiers": mods or []}

# --- Azioni singole / dirette ---
reg("Trade.", [trade()])
reg("Invest in an allied Country.", [invest()])
reg("Improve Relations with a Country on the board.", [improve()])
reg("Engage in a Region.", [engage()])
reg("Build a Base in an allied Country.", [build_base()])
reg("Improve Relations with 2 Countries on the board.", [improve(), improve()])
reg("Increase 2 of your Productions by 1.", [increase_prod(2)])
reg("Gain 1 Army. You can then Move up to 2 Armies.", [gain_armies(1), move(2)])
reg("Produce 1 Army. Then, Move up to 3 Armies.", [produce(types=["armies"]), move(3)])
reg("Produce 1 Army. Then, Build a Base in an allied Country.", [produce(types=["armies"]), build_base()])
reg("Produce 1 resource type. Then, Get a Growth Card.", [produce(1), get_growth()])
reg("Produce 2 resource types. Then, Get a Growth Card.", [produce(2), get_growth()])
reg("Get a Growth Card or Produce 3 resource types.", [choice([get_growth()], [produce(3)])])
reg("Trade. Then, Invest in an allied Country.", [trade(), invest()])
reg("Gain 10 money. Then, Invest in an allied Country.", [gain_money(10), invest()])
reg("Draw 2 cards. Then, Play another card.", [draw(2), play_another()])
reg("Draw a card. Then, Build a Base in an allied Country.", [draw(1), build_base()])
reg("Ready up to 2 allied Country cards. Then, Engage in a Region.", [ready_country(2), engage()])

# --- Con modificatori (azione core + nota) ---
reg("Build a Base in an allied Country. Then, gain 1 Army.", [build_base(), gain_armies(1)])
reg("Build a Base in an allied Country. Then, gain 1 Diplomacy.", [build_base(), gain_res("diplomacy", 1)])
reg("Invest in an allied Country. Then, gain 1 Diplomacy.", [invest(), gain_res("diplomacy", 1)])
reg("Trade. Then, Produce up to 2 Consumer Goods.", [trade(), produce(types=["consumer_goods"])], ["produce_max:2"])
reg("Trade. Then, gain 5 money for each resource type you Imported.", [trade()], ["gain_5_money_per_import"])
reg("Trade. You can count either Energy or Raw Materials symbols in your allied Countries twice.", [trade()], ["count_energy_or_raw_twice"])
reg("Engage in a Region, spending 1 Diplomacy less for each Army you have in that Region.", [engage()], ["engage_discount_per_army"])
reg("Engage in a Region, spending 1 Diplomacy less for each allied Country you have from the same Region.", [engage()], ["engage_discount_per_allied"])
reg("Engage in a Region. If you Engage in Europe, Middle East-North Africa, or Central Asia, spend 1 Diplomacy less.", [engage()], ["engage_discount_1_in:europe,middle_east_north_africa,central_asia"])
reg("Improve Relations with a Country on the board. For every Diplomacy required, you can spend 3 money instead.", [improve()], ["pay_money_for_diplomacy:3"])
reg("Improve Relations with a Country on the board, spending 1 Diplomacy less. You can then Reset 1 of your temporary Influence in that Country's Region.", [improve(), reset_influence()], ["improve_discount:1"])
reg("Improve Relations with a Country on the board. Then, Invest in that Country or Trade.", [improve(), choice([invest()], [trade()])])
reg("Improve Relations with a Country on the board. You can then Engage in that Country's Region.", [improve(), engage()])
reg("Improve Relations with a Country on the board. Then, if able, Build a Base in that Country, or Move up to 2 Armies to that Country's Region, even if you don't have a Base there.", [improve(), choice([build_base()], [move(2)])])
reg("Gain 2 Diplomacy. Then, Improve Relations with a Country on the board or Engage in a Region.", [gain_res("diplomacy", 2), choice([improve()], [engage()])])
reg("Gain 4 money for each FDI token on your allied Countries. Then, Invest in an allied Country.", [op("gain_money_per_fdi", amount=4), invest()])
reg("Gain 20 money. Then, Get a Growth Card. For every Services required, you can spend 10 money instead.", [gain_money(20), get_growth()], ["pay_money_for_services:10"])
reg("Ready an allied Country. Then, Invest in that Country without exhausting it.", [ready_country(1), invest()], ["invest_no_exhaust"])
reg("Ready an allied Country. You can then search the Country cards on the board of any 1 Region, choose 1 of those Countries, and Improve Relations with it. Shuffle the rest of the cards afterward and reveal the first 2 on the board.", [ready_country(1), improve()], ["search_region_before_improve"])
reg("Choose a resource type. Increase its Production by 1 (if able) and Produce it. Then, Play another card.", [increase_prod(1), produce(1), play_another()])
reg("Produce 1 Consumer Goods. Then, you can either increase your Prosperity, spending 2 Consumer Goods less, or Play another card.", [produce(types=["consumer_goods"]), choice([op("increase_prosperity", discount=2)], [play_another()])])
reg("Draw 3 cards. You can then discard 2 cards to Play another card.", [draw(3), choice([op("discard", n=2, then=[play_another()])], [op("noop")])])
reg("Draw a card. You can then Trash a card from your hand or your discard pile to Play another card.", [draw(1), choice([trash("hand"), play_another()], [trash("discard"), play_another()], [op("noop")])])
reg("Choose a Region and Reset 1 of your temporary Influence there. Then, Draw a card and Play another card.", [reset_influence(), draw(1), play_another()])
reg("Move up to 3 Armies. You can then Reset 1 of your temporary Influence in 1 of the Regions you moved your Armies to.", [move(3), reset_influence()])
reg("Choose a Region. Trade, considering that Region's available Countries on the board as allied Countries. Then, Reset 1 of your temporary Influence in that Region.", [trade(), reset_influence()], ["trade_region_available_countries"])
reg("Build a Base in an allied Country. When adding Influence to its Region as part of the action, you can place it as permanent Influence even if there is no available slot.", [build_base()], ["base_influence_permanent_force"])
reg("Build a Base in an allied Country. You can choose a Country even if you have already built a Base in it once before (but only once).", [build_base()], ["base_repeat_once"])
reg("Build a Base in an allied Country. You can move up to 3 Armies to its Region, regardless of the Country's value and without paying their move cost.", [build_base()], ["base_move_3_free"])
reg("Invest in an allied Country. You can choose a Country even if you have already invested in it once before (but only once).", [invest()], ["invest_repeat_once"])
reg("Invest in an allied Country. You can also Invest in an additional allied Country from another Region, spending 10 money more.", [invest(), choice([op("spend_then", money=10, then=[invest()])], [op("noop")])])
reg("Choose any 2, in any order: Improve Relations with a Country on the board; Trade; Move up to 2 Armies.", [op("choose_n", n=2, options=[improve(), trade(), move(2)])])
reg("Trade a resource type. (You can either Export or Import it.) Then, Play another card.", [trade(), play_another()], ["trade_single_type"])
reg("Trash this card when you play it. Research a card costing up to 6 Research for free and immediately Play it.", [trash("self"), op("research_free", max=6), play_another()])

# --- Ongoing / passive (Growth + alcune carte) ---
reg("Draw an additional card each round (including the round you get this card).", [ongoing("extra_draw_per_round")])
reg("During your first turn each round, you can Play an additional card.", [ongoing("extra_play_first_turn")])
reg("Whenever you choose your Focus, Ready an additional Country card.", [ongoing("ready_extra_on_focus")])
reg("Once per round, before or after adding Influence to a Region, you can convert 1 of your temporary Influence in that Region to a permanent one, even if there is no available slot.", [ongoing("once_per_round:convert_influence")])
reg("Once per round, when you Improve Relations, you can Improve Relations again with another Country, spending 1 Diplomacy more.", [ongoing("once_per_round:improve_again_plus1")])
reg("Once per round, you can Draw a card. Then, Trash a card from your hand.", [ongoing("once_per_round:draw_then_trash")])
reg("Once per round, you can Draw cards up to the highest value among your ready allied Countries. Then, discard that many cards.", [ongoing("once_per_round:draw_highest_value_then_discard")])

# --- Strategic Assets (uso singolo, spesso con place_armies/sell) ---
reg("Sell 2 Armies for 20 money in total to add 1 Influence to a Region of your choice.", [sell_armies(2, 20), add_influence()])
reg("Choose up to 2 Regions other than Central Asia. Move 2 Armies to each of them, spending 5 money more per Army moved. Then, add 1 Influence to each of those Regions.", [op("move_to_regions", per_region=2, count=2, exclude=["central_asia"]), add_influence(), add_influence()])
reg("Spend 1 Diplomacy to Move up to 2 Armies to Central Asia for free and add 1 permanent Influence to that Region, even if there is no available slot.", [op("spend", diplomacy=1), op("move_free", max=2, region="central_asia"), add_influence(True)])
reg("Spend 2 Diplomacy and 10 money to place 2 Armies from the supply on either Europe, Middle East-North Africa, or Central Asia (even if you don't have a Base there), and add 1 permanent Influence to that Region, even if there is no available slot.", [op("spend", diplomacy=2, money=10), place_armies(2, ["europe","middle_east_north_africa","central_asia"]), add_influence(True)])
reg("Spend 20 money to place 1 Army from the supply on Europe, Middle East-North Africa, Africa (even if you don't have a Base there), or Central Asia, and add 1 Influence to that Region. You can repeat this process once more, choosing a different Region.", [op("repeat", times=2, body=[op("spend", money=20), place_armies(1, ["europe","middle_east_north_africa","africa","central_asia"]), add_influence()])])
reg("Spend 30 money to add 1 Influence to 2 of the following Regions: Americas, Africa, and South Asia. Russia can then spend 20 money (or as much as it has if it has less) to add 1 Influence to the third Region.", [op("spend", money=30), add_influence(), add_influence()], ["brics_russia_third_region"])
reg("Spend up to 20 money. For every 10 money spent, gain 3 Diplomacy. Then, Engage in a Region, even if you don't have any allied Countries from that Region.", [op("spend_for_gain", spend_max=20, per=10, gain=gain_res("diplomacy",3)), engage()], ["engage_without_allied"])
reg("Move 2 Armies to either Europe, Middle East-North Africa, or Central Asia (even if you don't have a Base there) to add 1 permanent Influence to that Region, even if there is no available slot. Then, gain 2 Diplomacy.", [op("move_free", max=2, regions=["europe","middle_east_north_africa","central_asia"]), add_influence(True), gain_res("diplomacy",2)])
reg("Move 1 to 3 Armies to East Asia-Pacific to add 1 permanent Influence to the Region, even if there is no available slot.", [op("move_free", min=1, max=3, region="east_asia_pacific"), add_influence(True)])
reg("Spend 10 money / 20 money to increase 2 / 3 of your Productions by 1, and gain 3 VP. Then, Play another card.", [choice([op("spend", money=10), increase_prod(2), gain_vp(3)], [op("spend", money=20), increase_prod(3), gain_vp(3)]), play_another()])
reg("Improve Relations with a Country in Europe. You can spend 2 Diplomacy more to add 1 permanent Influence to Europe, even if there is no available slot.", [improve()], ["region:europe", "optional_spend_2dip_perm_influence"])
reg("Engage in Europe, Middle East-North Africa, or Central Asia (even if you don't have any allied Countries from that Region). You can then spend 10 money and Engage in 1 of the other 2 Regions as well.", [engage(), choice([op("spend", money=10), engage()], [op("noop")])], ["engage_without_allied"])
reg("Spend 1 Services to Reset 1 of your temporary Influence in that Region, and then add 1 Influence there.", [op("spend", services=1), reset_influence(), add_influence()])
reg("Choose a Region. Spend 1 Services to Reset 1 of your temporary Influence in that Region, and then add 1 Influence there.", [op("spend", services=1), reset_influence(), add_influence()])
reg("Choose a Region other than Europe. Trade, considering that Region's available Countries on the board as allied Countries. If you Exported at least 1 Consumer Goods and 1 Services to that Region's Countries, add 1 Influence there.", [trade(), choice([add_influence()],[op("noop")])], ["trade_region_available_countries","cond_influence_export_cg_services"])
reg("Choose any 2 Regions. Trade using only those Regions' allied Countries and available Countries on the board, counting each Energy symbol twice. In each Region to which you Exported at least 4 Energy, add 1 Influence.", [trade()], ["count_energy_twice","cond_influence_export_4_energy"])
reg("Produce 2 resource types. Then, Get a Growth Card.", [produce(2), get_growth()])
reg("Improve Relations with a Country in Middle East-North Africa, Central Asia, South Asia, or East Asia-Pacific. You can then either Invest in that Country, Build a Base in that Country (if able), or Engage in its Region.", [improve(), choice([invest()],[build_base()],[engage()])])

def encode(text):
    if not text:
        return None
    return T.get(text.strip())

root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
files=glob.glob(os.path.join(root,"data","abilities","*_starting.json"))+[
    os.path.join(root,"data",f) for f in ["market_cards.json","growth_cards.json","strategic_assets.json"]]
total=0; encoded=0; missing=set()
for path in files:
    doc=json.load(open(path)); changed=False
    for c in doc["cards"]:
        total+=1
        text=(c.get("effect_text") or c.get("ability_text") or "").strip()
        e=encode(text)
        if e:
            c["effect_ops"]=e["ops"]
            if e["modifiers"]: c["effect_modifiers"]=e["modifiers"]
            encoded+=1; changed=True
        elif text:
            missing.add(text)
    if changed:
        json.dump(doc, open(path,"w"), indent=1, ensure_ascii=False)
# executive order: lista azioni gia' strutturata
print(f"Carte: {total}, con effect_ops: {encoded}")
if missing:
    print("NON codificati:", len(missing))
    for m in sorted(missing): print("  -", m)
