# Legenda dei simboli risorsa

Identificata dalle plance di produzione (`Images/Player Production/`) e validata
contro gli esempi del regolamento. Usata per trascrivere export/import delle Country card.

## I 7 tipi di risorsa

| Risorsa | Categoria | Icona | Colore |
|---------|-----------|-------|--------|
| **Energy** (Energia) | primaria | barile di petrolio | grigio/nero |
| **Raw Materials** (Materie Prime) | primaria | blocco di minerale/roccia | grigio |
| **Food** (Cibo) | primaria | spiga di grano | oro/giallo |
| **Consumer Goods** (Beni di Consumo) | secondaria | smartphone/dispositivo | blu |
| **Services** (Servizi) | secondaria | valigetta | magenta/viola |
| **Diplomacy** (Diplomazia) | secondaria | bilancia | — |
| **Armies** (Armate) | secondaria | carro armato | — |

## Layout delle Country card

- **In alto a sinistra**: esagono con il **Valore** del Paese.
- **Sotto il valore**: numero + moneta = **costo di Invest**.
- **In alto a destra**: bandiere **barrate** = potenze che **NON** possono migliorare le relazioni
  (`no_relations_powers`). Es. Iran/Syria → USA barrata (coerente col regolamento).
- **Metà destra**: simbolo **Base** (fortino con stella) + bandiere sotto = potenze che possono
  **costruire una Base** qui (`base_allowed_powers`).
- **Striscia in basso**: sezione **grande a sinistra** = risorse che puoi **Esportare** (vendere);
  sezione **a destra con freccia ↓** = risorse che puoi **Importare** (comprare).
  Il numero di copie di un simbolo = quante unità di quella risorsa.

## Esempi verificati (Middle East – North Africa)

- **Turkey**: valore 3, Invest 20, Base→USA, export = Materie Prime + 2 Beni di Consumo, import = 2 Servizi.
- **Iran**: valore 3, Invest 20, USA non può migliorare relazioni, export = Materie Prime + Cibo + Beni di Consumo, import = 2 Energia.
- **Jordan**: valore 1, Invest 10, Base→USA+UE, export = Cibo, import = nessuno.
