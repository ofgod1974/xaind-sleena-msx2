# Build 06 — armi, bonus e meccaniche del personaggio

La ROM MSX2 include ora le cinque modalita d'arma, raccolta dei pacchi P, due posture abbassate, energia, vite e punteggio. Il percorso rimane il settore tecnico ciclico: questa build non completa ancora il port dell'arcade.

## Provala

Aprire `index.html` oppure la pagina del server locale. Il menu **Arma iniziale (banco prova)** permette di provare subito ogni arma. Il valore 0 avvia con il laser normale, come nell'arcade; le altre scelte sono una funzione di prova, non un bonus automatico della partita originale.

- Sinistra/destra: movimento e direzione di tiro.
- Su: salto; rilasciare e premere nuovamente per il doppio salto.
- Giu: inginocchiarsi. Rilasciare e premere nuovamente per sdraiarsi. Le direzioni laterali rialzano il personaggio; le diagonali verso il basso cambiano la direzione del tiro restando abbassati.
- Spazio: sparo, una pressione per ciascuna salva. Tenere premuto non produce piu il fuoco automatico della demo precedente.
- Joystick: pulsante 1 sparo, pulsante 2 salto.
- Dopo GAME OVER o SECTOR CLEAR: rilasciare e premere Spazio per ricominciare.

L'HUD mostra **X** seguito dalle vite, **P** seguito dal numero dell'arma, la barra energia e il punteggio a sei cifre.

## Armi

| ID | Arma | Comportamento implementato |
|---|---|---|
| 0 | Laser normale | Proiettile sottile, fino a tre presenti; si consuma colpendo un nemico. |
| 1 | Laser e granate | Laser normale accompagnato da una granata, fino a due granate presenti; traiettoria parabolica ed esplosione a terra o all'impatto. |
| 2 | Photon a due vie | Una sfera orizzontale e una diretta verso l'alto; fino a tre coppie presenti. |
| 3 | Laser pesante | Proiettile piu lento, una presenza alla volta, che continua oltre il nemico colpito. |
| 4 | Laser largo | Tre proiettili su quote diverse, con grafica distinta per il centrale e i laterali; fino a nove proiettili presenti. |

La grafica proviene dagli indici dei veri sprite arcade: laser 774, granata 1044, Photon 1775, pesante 776 e tiro largo 776/778. Le palette sono state acquisite durante l'esecuzione delle rispettive armi; le immagini sono ritagliate ai pixel effettivamente usati. Per questo il laser normale e ora alto un solo pixel e i colpi potenziati hanno forme e colori differenti. L'icona P deriva dal tile 766. Esplosioni e posture usano anch'esse tile originali.

Sono implementazioni MSX delle famiglie d'arma originali: velocita, cadenze, gravita, collisioni e numero massimo dei proiettili non costituiscono ancora una verifica ciclo per ciclo del programma arcade. Le animazioni dei proiettili usano per ora fotogrammi selezionati, non l'intera sequenza originale.

## Bonus, energia e vite

Nel settore di prova alcuni soldati portano un simbolo P. I portatori non sparano e fuggono quando Xain si avvicina. Abbattendoli il pacco cade; occorre raggiungerlo per ottenere uno dei quattro potenziamenti. Il tipo viene scelto alla raccolta. La grafica completa del portatore originale non e ancora ricostruita: il soldato marcato P e un adattamento provvisorio.

La partita parte con tre vite e 16 unita di energia. Il proiettile del soldato dimostrativo toglie un'unita; il contatto col corpo ne toglie otto. Da prono si possono evitare i suoi colpi orizzontali. Dopo un danno e attiva una breve invulnerabilita. Il potenziamento resta dopo un danno; alla morte si perde una vita e si torna al laser normale con energia ripristinata. A zero vite appare GAME OVER.

Ogni soldato abbattuto vale 100 punti nel settore di prova. Sono attive le vite extra a 20.000 e 70.000 punti, poi ogni 70.000, secondo l'impostazione DIP predefinita documentata dal driver MAME. Il sistema usa un punteggio BCD a sei cifre. I valori degli altri nemici e dei bonus di fine livello richiedono l'integrazione dei contenuti corrispondenti.

## Verifiche

Compilazione SjASMPlus: zero errori e avvisi, ROM ASCII16 da 1 MiB. Tredici verifiche delle condizioni di gioco hanno dato esito positivo: rilascio e raccolta P, danni, perdita dell'arma, vite, riporto del punteggio, vita extra, penetrazione, esplosioni, schivata e mira abbassata. Le condizioni limite sono state predisposte tramite fixture RAM; non sono presentate come una partita naturale completa.

Stress test con nove proiettili e scrolling per quattro secondi: tutte le 16 fasi R#18, 48 scritture, nessuna con CE attivo o fuori VBlank. Confrontati 35.758 pixel del fondale fuori dalle aree degli attori: zero differenze. Clock audio: 241 interrupt in circa quattro secondi NTSC; PAL con OPL4: 151 in circa tre secondi.

Il renderer ripristina ora anche i nove rettangoli dei proiettili e quello del bonus. Le strisce del fondale sono copiate prima del disegno degli attori, per impedire che i nuovi oggetti finiscano nella pagina del fondale. La frequenza grafica dipende dal carico: nello stress artificiale con nove grandi colpi centrali e stata circa 12 aggiornamenti/s. Non e raggiunto il target di gioco a 50/60 aggiornamenti/s. Il clock della musica resta indipendente. Hardware reale non ancora verificato.

Dettagli in `test-results-build06.json`. Per i driver audio e i loro limiti, vedere `BUILD05.md`.

## Particolarita ancora da integrare

Non sono ancora implementati i percorsi originali dei cinque pianeti e della fortezza, le collisioni del terreno e le loro insidie, le specifiche famiglie di nemici e veicoli, mini-boss e boss, scelta e progressione dei pianeti, conto alla rovescia della bomba e fuga sulla Sleena, sezioni di volo, asteroidi e nave madre. Sono inoltre incompleti timer e checkpoint originali, punteggi specifici, animazioni e fedelta sonora. Questi elementi richiedono mappe e comportamenti dell'arcade, non la sostituzione con contenuti inventati.

## Sorgenti

`src/weapons.asm` contiene proiettili, bonus, posture e gestione di vite/punteggio. `src/game.asm` integra aggiornamento e renderer. `src/generate-assets.cjs` rigenera grafica e tabelle usando gli indici e le palette inclusi in `src/reference/`. Compilare con `build.ps1 -Assembler C:\percorso\sjasmplus.exe`.

Riferimenti: esecuzione dell'arcade in MAME e acquisizione degli sprite; [driver MAME Xain](https://github.com/mamedev/mame/blob/master/src/mame/technos/xain.cpp), [renderer MAME](https://github.com/mamedev/mame/blob/master/src/mame/technos/xain_v.cpp). La guida di [Lord Willow](https://gamefaqs.gamespot.com/arcade/584136-solar-warrior/faqs/19159) e stata usata per confrontare famiglie d'arma, posture e contenuti ancora mancanti. Gioco, grafica e composizioni originali: Technos Japan. Crediti WebMSX e YRW801 nei documenti della build 05.
