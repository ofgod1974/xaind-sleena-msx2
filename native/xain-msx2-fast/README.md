# Xain’d Sleena MSX2 — 0.8.6-dev, profilo rapido

2026 - progetto di conversione di Lorenzo Moretti e Andrea D Dio (Associazione MSX Italia)

Build nativa Z80: logica C compilata con SDCC, input Fusion-C 1.2 e video/audio in assembly. La conversione completa dei livelli e dei boss resta in lavorazione.

## Prova su hardware

Usare XAIN086.ROM, cartuccia ASCII16 da 2 MiB, MSX2 con 128 KiB VRAM. Sul Pico+ selezionare esplicitamente ASCII16. Il trainer si attiva/disattiva con T oppure SELECT: compare TR nell’HUD. Mantiene energia, vite e arma; una caduta riporta all’ultimo terreno sicuro. Per riprovare le condizioni normali disattivarlo.

## Scrolling

Questa variante usa SCREEN 5 a 16 colori, con palette indicizzata: è un compromesso grafico per ridurre il lavoro del VDP. SCREEN 8 a 256 colori rimane disponibile nella cartella sorella e in XAIN086C.ROM, con trainer ma senza questo nuovo motore video.

Lo scrolling verticale usa R#23 su tutta l’escursione della telecamera, a passi massimi di due pixel, senza ricopiare il fondale. L’orizzontale combina R#18, doppia pagina e otto lavori di composizione distribuiti. Il protagonista usa sprite hardware con quattro piani di colore combinati; HUD e campo di gioco sono separati da interrupt di linea. Il VBlank passa al BIOS per conservare audio e tastiera. La logica recupera fino a due tick per rendering usando il contatore degli interrupt video.

VRAM: pagine 0/1 fondali; pagina 2 atlante; pagina 3 tabelle sprite e sfondo nero HUD. La modalità conserva il bit VR di R#8, necessario sull’hardware reale. Nessun registro di scrolling MSX2+ richiesto.

## Verifica e limiti

50 controlli passati in WebMSX PAL: collisioni confrontate con 600 campioni di riferimento, armi, bonus, trainer, ricostruzione checkpoint, composizione del fondale, wrap VRAM e 14 pose hardware. T/SELECT e interrupt raster verificati anche con emulazione in esecuzione.

Nella scena isolata del benchmark PAL: circa 40 ms per aggiornamento orizzontale e diagonale, circa 20 ms verticale. Il vecchio 0.8.5 misura circa 58 ms orizzontale e 80 ms verticale/diagonale nella stessa prova. I valori non garantiscono le prestazioni di ogni scena con nemici. L’orizzontale resta circa 25 aggiornamenti/s in questa prova. Questa nuova variante non è ancora stata verificata fisicamente su NMS8245/Pico+.

## Sorgenti e compilazione

- src/c/game.c, weapons.c, level.c: gioco, armi e collisioni.
- src/game.asm, pipeline.asm: avvio e composizione video.
- src/hardware-player.asm: protagonista hardware e interrupt IM2/raster.
- src/trainer.asm: tastiera trainer e ricostruzione checkpoint.
- src/audio/player.asm: driver audio.

Compilare con Node.js, SDCC e sjasmplus:

    node build.cjs C:/strumenti/sdcc/bin/sdcc.exe C:/strumenti/sjasmplus.exe

La compilazione usa ABI SDCC 0 e --no-peep. Per rigenerare le risorse SCREEN 5 eseguire convert-assets.cjs, che legge gli asset SCREEN 8 dalla cartella sorella. Non lanciare direttamente qui i vecchi generatori SCREEN 8: sovrascriverebbero i dati packed.

I rapporti qa-mechanics.json e qa-performance-pal-final.json documentano questa build. I test richiedono Playwright e Chromium; impostare i percorsi locali nel runner se necessario.
