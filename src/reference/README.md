# Riferimenti grafici della demo 03

`arcade-scene.rgb`: panorama RGB 512×240, tre byte per pixel, composto dai due livelli grafici della RAM di Xain’d Sleena (set World `xsleena`) e dalle rispettive palette catturate in MAME 0.289. La demo 04 usa la sezione iniziale da 240×192 pixel, adattandola verticalmente nei 160 pixel del campo di gioco e aggiungendo otto pixel neri per lato. Il buffer completo è 256×192; le maschere sprite delimitano una finestra visibile stabile di 224×160.

`arcade-palette.bin`: 512 colori RGB dell’arcade, tre byte per colore. La palette sprite comincia all’indice 128. Il generatore usa il banco 0 per Xain e il banco 1 per i nemici.

`sprites.indices.bin`: sprite arcade decodificati, 2.048 tile 16×16, un byte per pixel (indice 0–15). Le coppie di tile sono composte in personaggi 16×32.

La conversione finale è SCREEN 8 GGG RRR BB, senza una palette adattata condivisa da fondale e personaggi. I dati non costituiscono una licenza d’uso della grafica originale, i cui diritti restano ai rispettivi titolari.

Layout e composizione: https://github.com/mamedev/mame/blob/master/src/mame/technos/xain.cpp e xain_v.cpp.
