# Xain’d Sleena MSX2 — Fusion-C, 0.8.2-dev

**Primo pianeta con mappa e collisioni; conversione completa ancora in lavorazione.**

2026 - progetto di conversione di Lorenzo Moretti e Andrea D Dio (Associazione MSX Italia)

Questa ROM contiene codice C compilato per Z80 con SDCC e le routine di input di Fusion-C 1.2, compilate dai sorgenti originali. Il motore V9938, il caricamento delle risorse, la presentazione e il driver musicale restano in assembly. Non è un gioco JavaScript: `index.html` carica il file ROM separato e WebMSX lo esegue.

## Codice da leggere

| File | Responsabilità |
| --- | --- |
| `src/c/game.c` | Input Fusion-C, movimento, salto, collisioni; incontri dimostrativi esplicitamente marcati |
| `src/c/weapons.c` | Cinque armi, proiettili, granate, bonus P, posture, punteggio, vite |
| `src/c/game.h` | Interfaccia e mappa RAM condivisa fra C e Z80 |
| `src/c/entry.s` | Due ingressi C stabili nel banco 3 |
| `src/game.asm` | Avvio cartuccia, VDP, scrolling e rendering |
| `src/weapons.asm` | Inizializzazione RAM e rendering di armi/HUD; vecchia logica rimossa |
| `src/audio/player.asm` | Driver musicale e interrupt |
| `third_party/fusion-c/` | Input e header upstream, con licenza e attribuzione |

## Compilare

Servono Node.js, SDCC con `sdasz80`/`sdldz80` e sjasmplus. Nessun HTML è necessario per compilare la ROM.

```powershell
node build.cjs C:/strumenti/sdcc/bin/sdcc.exe C:/strumenti/sjasmplus.exe
```

In alternativa impostare `SDCC` e `SJASMPLUS`. Il codice C viene collegato a `$8000`, inserito nel banco ASCII16 numero 3 e richiamato dal banco fisso; il precedente banco delle risorse viene ripristinato al ritorno. Il driver musicale salva e ripristina il banco anche durante gli interrupt. RAM C riservata da `$C920`, stack della cartuccia invariato.

La compilazione usa ABI SDCC `--sdcccall 0`, coerente con i sorgenti Fusion-C 1.2. La distribuzione SDCC 4.6.0 #16555 provata richiede `--no-peep`: con le ottimizzazioni peephole abilitate generava un'istruzione Z80 illegale (`ld hl,a`). Non viene corretta a mano l'uscita del compilatore.

`build/report.json` registra compilatore e dimensioni; `build/core.map` mostra le funzioni C effettivamente collegate. Sono vietate sezioni RAM C che richiedono un'inizializzazione di runtime assente dalla cartuccia.

Per rigenerare la grafica, installare `sharp` e lanciare i generatori in `src/`. La rigenerazione non è necessaria per compilare i sorgenti C: i dati grafici sono inclusi.

## Provare

Servire questa cartella con un server HTTP locale e aprire `index.html`. Il browser deve poter caricare `xain-msx2.rom` e `wmsx.js`. In emulatore MSX2 esterno: cartuccia ASCII16, almeno 128 KiB VRAM, Z80 standard.

Frecce: movimento e salto. Giù, rilasciare e ripremere: inginocchiato e prono. Spazio: un tiro per pressione. Il primo pianeta usa ora il fondale acquisito fino alla base (2.768 pixel), con streaming delle colonne e collisioni originali adattate alla risoluzione MSX. Nemici e boss restano incompleti.

## Verifica eseguita

Compilazione assembly senza errori o warning; collegamento C riuscito. Avvio reale della ROM in WebMSX, titoli, intro, ingresso in partita, movimento e salto. **28 controlli eseguiti sul codice C compilato nella CPU emulata**, comprendenti cinque salve, assenza di autofire, bonus P, danni senza perdita dell'arma, morte, game over, posture e doppio salto. Risultati in `qa-mechanics.json`; fotografia della partita in `fusion-c-webmsx.png`.

Non sono prove su MSX2 fisico, né una convalida della fedeltà dei boss o dei livelli. PSG/SCC/MSX-MUSIC/OPL4 ereditano il driver precedente; Y8950 resta da verificare con hardware o emulatore compatibile.

## Livelli e boss: stato reale

`research/maps/` conserva tile e attributi osservati in cinque acquisizioni dell'arcade. Le immagini sono ricostruzioni di ricerca, **non livelli già integrati nella ROM**. Le celle non osservate sono segnalate da `known.bin` e, nelle anteprime, da una scacchiera. Le dimensioni sono quelle dell'area osservata, non una certificazione dell'estensione completa del pianeta. Anche copertura 100% significa solo copertura del rettangolo acquisito.

Le acquisizioni forzano posizione ed energia del giocatore per leggere i fondali: non possono validare tempi, collisioni o intelligenza dei nemici. Per questo non vengono usate come prova della fedeltà dei comportamenti. I buffer video reali vengono letti a `$2800` e `$3000`, secondo il driver MAME; le aree RAM `$0800`/`$1000` non vengono trattate come tilemap video.

Restano da completare: percorsi e collisioni originali, dislivelli e pericoli, checkpoint/timer, tutti i nemici e i loro punti di comparsa, boss e miniboss con animazioni e comportamenti verificati, selezione/progressione dei pianeti, bombe e fughe, combattimenti spaziali, asteroidi/mothership e fortezza finale. Il fondale del primo pianeta non è più ciclico. Le tabelle di collisione e il piano di appoggio provengono dalle ROM arcade; la risoluzione verticale e il comportamento sulle pendenze sono ancora adattamenti. Non viene dichiarata una conversione completa.

## Riferimenti e diritti

Fusion-C 1.2: Eric Boez ed équipe, https://github.com/ericb59/Fusion-C-v1.2 — CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/ . I due file di input e l'header in `third_party/fusion-c/` sono conservati senza modifiche. Codice C del progetto: CC BY-SA 4.0, con i crediti del progetto sopra indicati. Questa indicazione non concede diritti sulle risorse del gioco originale.

Driver hardware di riferimento: https://github.com/mamedev/mame/blob/master/src/mame/technos/xain.cpp e `xain_v.cpp`, BSD-3-Clause. Acquisizioni MAME 0.289 dal set `xsleenaba`: la variante usata per ricerca va confrontata con la versione World per verificare le eventuali differenze prima di dichiarare fedeltà completa.

Grafica e musica di Xain’d Sleena restano dei rispettivi titolari. WebMSX: Paulo Augusto Peccin, https://github.com/ppeccin/WebMSX . Strumenti di compilazione non inclusi.

## Correzione dello scrolling 0.8.2-dev

Ripristinato il passo di un pixel e una sola copia di striscia per aggiornamento. La nuova colonna viene caricata nella pagina nascosta in 16 gruppi da 10 righe, evitando il trasferimento di 160 righe in un solo frame. Benchmark NTSC di otto secondi, con il solo giocatore e collisioni disattivate in entrambe le ROM: intervallo mediano 50,01 → 34,49 ms; tutte le 16 fasi usate; zero scritture di R#18 durante display attivo o VDP occupato; zero differenze su 26.880 pixel del fondale attivo. Sono misure di quella scena, non una promessa di 50/60 fps nel gioco completo. Risultati in qa-scrolling.json.

## 0.8.3-dev - prova montagna (15 novembre 2026)

Salita dei gradini originali, collisioni e salti sopra il limite precedente, appoggio sulle rocce tondeggianti, tempi verticali adattati allo scorrimento di un pixel. Comparsa e movimento del nemico richiedono un appoggio libero; i punti di comparsa non sono ancora le tabelle dell’arcade. Nube MSX a tre fotogrammi e suono di distruzione distinto. Conservata la correzione del bit VR di R#8 verificata dall’utente su NMS8245 con Pico+.

35 verifiche sul codice compilato in WebMSX: comprende salita, atterraggio sulla roccia x1320 e attraversamento del primo vuoto fino a x1906 senza perdere vite, oltre alle armi, morte nel vuoto, stato della nube e trasferimenti VRAM. La nuova build richiede ancora verifica fisica. Inquadratura verticale fissa: il personaggio puo uscire dalla vista durante salti alti. Boss e incontri completi originali restano da implementare.

## 0.8.4-dev - telecamera verticale e velocita

Xain MSX2 0.8.4-dev - 16 novembre 2026
ROM ASCII16 da 2 MiB. MSX2 con 128 KiB VRAM.
Telecamera verticale: segue il giocatore nella fascia 72..112, con spostamento massimo 88 righe; R#23 per le 8 fasi fini e HMMM sulle due pagine per la parte grossolana. Le nuove righe vengono ricostruite dalla mappa.
Velocita: due aggiornamenti logici per presentazione, con preparazione di tutte le fasi orizzontali intermedie. Nella scena isolata comune (senza nemici/collisioni) il benchmark di 8 secondi passa da 207 spostamenti da 1 pixel a 147 da 2 pixel: circa +42%. La cadenza video misurata passa da circa 34 a 50 ms di mediana; non e un motore a 50/60 fps.
QA: 39 controlli su codice compilato, incluse 153600 verifiche di pixel per salita/discesa delle due pagine, preservazione di atlas e HUD, percorso della montagna e armi. Verifica visiva del personaggio sulle rocce nella nuova inquadratura.
La correzione R#8 del precedente test NMS8245 + Pico+ e mantenuta. Questa nuova build non e ancora stata provata su hardware reale.
Limiti: la ricostruzione verticale a blocchi puo causare rallentamenti; la mappa e ancora quella parziale acquisita, lo spazio sopra il bordo acquisito e nero. Nemici adattati, boss e conversione completa da completare.
2026 - progetto di conversione di Lorenzo Moretti e Andrea D Dio (Associazione MSX Italia)
SHA256 e2528f172ece6ab501e7b7968592ddd8caf800ffe918947382bbecb32d460ba0

## 0.8.5-dev - composizione su pagina nascosta

Xain MSX2 0.8.5-dev - scrolling verticale a bipixel
ROM ASCII16, 2 MiB. MSX2, 128 KiB VRAM.
Il ciclo normale non usa piu vertical_update: prepara la pagina nascosta in quattro lavori limitati e presenta lo spostamento fine R#23 durante VBlank. Lo spostamento verticale applicato e limitato a due pixel per presentazione, con controllo dei cambi di direzione e della discesa.
La composizione ripara sulla pagina nascosta le porzioni copiate degli attori, conservando gli attori sullo schermo. La grafica e le tabelle HUD hanno fasce di guardia per gli spostamenti fini positivi e negativi.
QA: 54 controlli su codice compilato, inclusi movimento bipixel, inversione, diagonale, corrispondenza pixel della mappa, assenza di fantasmi, conservazione atlas/HUD e presenza dell'attore durante la preparazione.
Benchmark isolato in WebMSX: picco della copia HMMM ridotto da 36480 a 9728 pixel; pause peggiori circa 400 -> 85 ms, senza scritture R#23 fuori VBlank nel controllo finale. Questi dati non equivalgono a 50/60 fps e non sono una misura su hardware reale.
Conservata la configurazione R#8 gia confermata su NMS8245 e Pico+. Questa nuova build necessita di prova fisica. Nemici e boss completi, mappe e altre parti della conversione restano in sviluppo.
2026 - progetto di conversione di Lorenzo Moretti e Andrea D Dio (Associazione MSX Italia)
SHA256 34abd1825e60ed5403d9e7301f06b0b9ffc43cb6a1081224827be8a6a741f3ba


## 0.8.6-dev

Aggiunti trainer T/SELECT (TR nell’HUD), energia e vite protette con ritorno all’ultimo terreno sicuro, collisioni Z80 ottimizzate e cache per pavimento nemici/punteggio. Questa variante conserva SCREEN 8 a 256 colori e il compositore precedente. La variante SCREEN 5 rapida è nella cartella sorella xain-msx2-fast. 58 controlli di regressione passati in WebMSX.
