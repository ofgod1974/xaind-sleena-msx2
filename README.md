# Xain’d Sleena MSX2 — Fusion-C, 0.8.0-dev

**Migrazione C giocabile, conversione arcade completa ancora in lavorazione.**

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

Frecce: movimento e salto. Giù, rilasciare e ripremere: inginocchiato e prono. Spazio: un tiro per pressione. Il settore è ancora quello di prova della 0.7; non rappresenta un livello arcade completo.

## Verifica eseguita

Compilazione assembly senza errori o warning; collegamento C riuscito. Avvio reale della ROM in WebMSX, titoli, intro, ingresso in partita, movimento e salto. **19 controlli eseguiti sul codice C compilato nella CPU emulata**, comprendenti cinque salve, assenza di autofire, bonus P, danni senza perdita dell'arma, morte, game over, posture e doppio salto. Risultati in `qa-mechanics.json`; fotografia della partita in `fusion-c-webmsx.png`.

Non sono prove su MSX2 fisico, né una convalida della fedeltà dei boss o dei livelli. PSG/SCC/MSX-MUSIC/OPL4 ereditano il driver precedente; Y8950 resta da verificare con hardware o emulatore compatibile.

## Livelli e boss: stato reale

`research/maps/` conserva tile e attributi osservati in cinque acquisizioni dell'arcade. Le immagini sono ricostruzioni di ricerca, **non livelli già integrati nella ROM**. Le celle non osservate sono segnalate da `known.bin` e, nelle anteprime, da una scacchiera. Le dimensioni sono quelle dell'area osservata, non una certificazione dell'estensione completa del pianeta. Anche copertura 100% significa solo copertura del rettangolo acquisito.

Le acquisizioni forzano posizione ed energia del giocatore per leggere i fondali: non possono validare tempi, collisioni o intelligenza dei nemici. Per questo non vengono usate come prova della fedeltà dei comportamenti. I buffer video reali vengono letti a `$2800` e `$3000`, secondo il driver MAME; le aree RAM `$0800`/`$1000` non vengono trattate come tilemap video.

Restano da completare: percorsi e collisioni originali, dislivelli e pericoli, checkpoint/timer, tutti i nemici e i loro punti di comparsa, boss e miniboss con animazioni e comportamenti verificati, selezione/progressione dei pianeti, bombe e fughe, combattimenti spaziali, asteroidi/mothership e fortezza finale. Il fondale del settore giocabile rimane ciclico. Non viene dichiarata una conversione completa.

## Riferimenti e diritti

Fusion-C 1.2: Eric Boez ed équipe, https://github.com/ericb59/Fusion-C-v1.2 — CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/ . I due file di input e l'header in `third_party/fusion-c/` sono conservati senza modifiche. Codice C del progetto: CC BY-SA 4.0, con i crediti del progetto sopra indicati. Questa indicazione non concede diritti sulle risorse del gioco originale.

Driver hardware di riferimento: https://github.com/mamedev/mame/blob/master/src/mame/technos/xain.cpp e `xain_v.cpp`, BSD-3-Clause. Acquisizioni MAME 0.289 dal set `xsleenaba`: la variante usata per ricerca va confrontata con la versione World per verificare le eventuali differenze prima di dichiarare fedeltà completa.

Grafica e musica di Xain’d Sleena restano dei rispettivi titolari. WebMSX: Paulo Augusto Peccin, https://github.com/ppeccin/WebMSX . Strumenti di compilazione non inclusi.
