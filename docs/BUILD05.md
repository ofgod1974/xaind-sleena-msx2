# Build 05 — audio arcade e doppio salto

Obiettivo confermato: conversione fedele all'arcade. Questa build e ancora una sezione tecnica giocabile, non il gioco completo.

## Avvio

Aprire `index.html`. Scegliere PSG, SCC, MSX-MUSIC/FM-PAC oppure OPL4 e premere **Avvia configurazione**. Il selettore dei brani espone i 29 comandi musicali originali, ancora senza attribuzione completa ai livelli.

La ROM e una cartuccia **ASCII16 da 1 MiB** per MSX2 con 128 KiB di VRAM. Richiede Z80 standard e V9938; non richiede MSX2+.

Comandi: frecce per muoversi, Su per saltare, Spazio per sparare. Rilasciare e premere nuovamente Su per il secondo salto. Un terzo impulso in aria viene ignorato. Joystick: pulsante 1 sparo, pulsante 2 salto. Dopo GAME OVER o SECTOR CLEAR, rilasciare e premere Spazio per ricominciare.

Nella ROM: F1 PSG, F2 SCC, F3 YM2413, F4 Y8950/MSX-AUDIO, F5 OPL4. Premere per circa un decimo di secondo. La scheda deve essere presente; in sua assenza viene usato il PSG. FM-PAC e MSX-MUSIC condividono il backend YM2413; l'abilitazione specifica della FM-PAC non e stata ancora verificata su cartuccia reale.

## Musiche

La libreria contiene acquisizioni di circa 62,6 secondi per ognuno dei 29 comandi musicali del driver YM2203 originale. Sono conservate note, volumi e riattacchi delle sei voci FM. La temporizzazione arcade viene adattata agli interrupt MSX PAL/NTSC, indipendentemente dal numero di aggiornamenti grafici.

- PSG: riduzione a tre voci; gli effetti condividono temporaneamente un canale.
- SCC: riduzione a cinque voci con forme d'onda dedicate; effetti sul PSG.
- MSX-MUSIC/FM-PAC: sei voci YM2413 con strumenti adattati; effetti sul PSG.
- MSX-AUDIO: driver Y8950 presente, uscita sonora ancora da verificare con un emulatore compatibile o hardware.
- OPL4: sei voci PCM con strumenti della ROM YRW801, come nella MoonSound standard; effetti sul PSG.

Non e una riproduzione bit per bit: mancano le parti SSG/rumore dell'arcade e i timbri originali a quattro operatori. I punti di loop originali non sono ancora stati identificati: al termine viene ripetuto il blocco acquisito. I quattro WAV `audio-*.wav` sono brevi registrazioni dell'uscita effettiva dei driver emulati, non sintesi esterne alla ROM.

## Verifiche

Compilazione SjASMPlus: zero errori e zero avvisi. Uscita audio non nulla registrata per PSG, SCC, MSX-MUSIC e OPL4. Clock verificato: 241 interrupt in circa quattro secondi NTSC e 150 in tre secondi PAL. Provato il brano 03, che attraversa piu banchi ROM, oltre la durata di una singola acquisizione.

Durante il test finale con movimento e sparo: 128 scritture R#18, tutte le 16 fasi, nessuna con il VDP occupato e nessuna nel periodo video attivo. Doppio salto, rifiuto del terzo impulso e azzeramento all'atterraggio verificati. I dettagli sono in `test-results-build05.json`. Hardware reale non ancora provato.

## Lavoro ancora necessario

Il fondale rimane ciclico e il nemico dimostrativo conserva il comportamento semplificato. Mancano percorso e collisioni dei livelli originali, boss, sezioni spaziali, tutte le armi e relativo comportamento, animazioni complete e fedelta degli effetti sonori. Sono stati acquisiti separatamente i cinque stati d'arma originali per studiarne grafica e traiettorie: Normal, Grenades, Double Shot, Heavy Shot, Triple Shot. Non vengono presentati come gia implementati.

## Compilazione e crediti

Eseguire `build.ps1 -Assembler C:\percorso\sjasmplus.exe`. Il codice audio e in `src/audio/player.asm`; le tabelle e i dati inclusi sono distribuiti insieme ai sorgenti. Il file `src/audio/manifest.json` descrive le acquisizioni.

Gioco, grafica e composizioni originali: Technos Japan. WebMSX: Paulo Augusto Peccin. Dati degli strumenti YRW801 derivati dal driver Linux OPL4: avviso completo in `src/audio/THIRD_PARTY-YRW801.txt`. Documentazione tecnica: https://map.grauw.nl/resources/msx_io_ports.php e https://github.com/torvalds/linux/tree/master/sound/drivers/opl4 .
