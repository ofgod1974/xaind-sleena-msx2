# Versione 0.7.0 — titoli e intro

Il front-end e eseguito dalla ROM Z80 sul V9938, non e una schermata HTML sopra l'emulatore.

All'avvio appaiono il logo originale dell'arcade, un invito lampeggiante a premere Spazio o Fire, la versione **0.7.0** e i crediti:

**2026 - progetto di conversione di Lorenzo Moretti e Andrea D Dio (Associazione MSX Italia)**

Il credito e presente anche nella pagina WebMSX e nei metadati della ROM. Il gioco originale resta attribuito separatamente a Technos Japan, 1986.

Premendo Spazio o Fire inizia una breve introduzione italiana in tre schermate, con Xain, il pianeta e testo progressivo. Ogni nuova pressione avanza alla schermata successiva, anche durante la comparsa del testo. Durante il breve caricamento tra due schermate, attendere che la nuova schermata inizi a comparire prima di premere nuovamente. Dopo l'intro inizia la partita, con l'arma e la scheda audio scelte nella pagina.

Lasciando il titolo inattivo per circa dieci secondi parte automaticamente l'intro. Senza input, al termine si torna al titolo: la partita non inizia da sola. Una pressione durante questa sequenza sceglie invece di proseguire verso la partita. Tenere premuto non salta automaticamente tutte le schermate.

Il titolo usa il brano originale 01; l'intro usa il comando musicale 0F. All'avvio della partita viene ripristinato il brano scelto nella pagina. Il logo proviene da una cattura dell'arcade; composizione, testo italiano e transizioni dell'intro sono un adattamento per questo progetto, non una ricostruzione identica della sequenza originale.

Le quattro immagini SCREEN 8 sono compresse nei banchi ROM 56–63, precedentemente occupati da riempimento della libreria musicale. La ROM resta ASCII16 da 1 MiB. Le immagini vengono caricate nella pagina nascosta e rivelate tramite comandi VDP; l'atlante degli sprite e l'HUD del gioco vengono preservati. Prima della partita si ripristinano fondale, sprite e regolazione orizzontale. La musica continua sugli interrupt durante i caricamenti.

Verificati in WebMSX: titoli, ciclo automatico intro/titolo, avanzamento manuale, pressione mantenuta e ritorno al gioco con OPL4, brano 06, tre vite e 16 unita di energia. Il confronto della schermata dei titoli su 47.712 pixel, esclusa la zona lampeggiante, non ha trovato differenze rispetto all'immagine generata. Compilazione senza errori e avvisi. Dettagli in `test-results-build07.json`.

Sorgenti: `src/frontend.asm`, `src/generate-frontend.cjs` e `src/frontend/`. Per rigenerare le immagini serve Node con `sharp`; i binari gia generati sono inclusi e non richiedono questa dipendenza per compilare la ROM. La compilazione normale resta `build.ps1 -Assembler C:\percorso\sjasmplus.exe`.

Il contenuto giocabile e quello della build 06. Per armi e limiti attuali del port vedere `BUILD06.md`; per la trascrizione musicale e le schede audio vedere `BUILD05.md`.
