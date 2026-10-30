# Acquisizioni dei livelli, non livelli convertiti

I cinque ID osservati sono `0,1,2,4,5`. I file `maps/planet-N.json` indicano il rettangolo osservato e le celle valide; `complete` rimane `false`. Non sono ancora ricostruiti il percorso completo di ogni livello, collisioni, nemici e boss.

Il renderer di ricerca decodifica buffer video a `$2800` (foreground) e `$3000` (background) con il mapper di tile MAME. Non usa i buffer RAM intermedi come tilemap video. Le anteprime ripetono il primo panorama di sfondo da 256 pixel e non riproducono il parallasse originale.

`scripts/capture-map.lua` gira con MAME 0.289 e set `xsleenaba`. Creare prima la directory `planet-N` e impostare `XAIN_PLANET` e `XAIN_CAPTURE_ROOT` (percorso con barra finale). Il programma forza posizione e salute: i frame così acquisiti sono adatti alla ricerca grafica, non al confronto dei comportamenti.

Per ricostruire i risultati dai dump e dagli indici grafici decodificati:

```text
node research/scripts/extract-world-maps.cjs CARTELLA_DUMP CARTELLA_GRAFICA CARTELLA_RISULTATI
```

La cartella grafica deve contenere `fondale-a.indices.bin` e `fondale-b.indices.bin`, decodificati dalle proprie ROM con il layout documentato dal driver MAME. È richiesto `sharp`. I dump di RAM, le ROM arcade e il compilatore non sono inclusi.

Le celle mancanti e quelle che cambiano fra più campioni richiedono ulteriori acquisizioni. Un rettangolo coperto al 100% non prova che la mappa del pianeta sia stata acquisita interamente.
