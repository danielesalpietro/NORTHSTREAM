# Sintesi delle fasi chiuse — NORTHSTREAM

Memoria distillata delle fasi già concluse, secondo `CLAUDE.md` §8: una pagina per
fase, mai di più. **Si legge in onboarding al posto dei logbook integrali**, che
restano in `docs/logbook/archive/` e si aprono solo per ricostruire un dettaglio
che questa sintesi non copre.

Regola di compressione: decisioni col loro perché e le alternative scartate, numeri
misurati, item aperti e lezioni che hanno generato una regola **non si comprimono
mai**. Tutto il resto sì.

---

## ESITO FASE 0 — chiusa il 2026-08-26 con il tag `v0.0.1` → `d3053be`

**Esito**: fase chiusa. Tag `v0.0.0-baseline` → `5eb456a` e tag `v0.0.1` → `d3053be`
pubblicati; `develop` allineato col merge `60269f7`. Tutte e sette le sub-issue
(#9–#15) chiuse. Consegnato: harness `bench/t0/` (12 test), tre workflow CI con
`ci-static` e `ci-smoke` verdi, runner self-hosted `z8-env-w` registrato e attivo,
README allineato al sistema reale (T0.12 flippato), e il **run T0 di riferimento**
contro il tag baseline con modelli reali — il metro di ogni release successiva.

**Che cosa rilascia v0.0.1**: la capacità di *misurare* il progetto e la verità
documentale. Il runtime di stack e agent è identico alla baseline: v0.0.1 non
ripara il sistema, lo rende osservabile e smette di raccontarlo male.

**Decisioni prese, con il perché**
- **Storyline README accorciata, non costruita**: i layer non collegati (Flink,
  Apicurio, MinIO, Trino, OpenMetadata) sono dichiarati tali invece di
  implementarli. Costruirli erano settimane per una pipeline vista tre minuti in
  demo; un diagramma con frecce inventate è un rischio reputazionale.
- **Niente PR flow, CI con smoke test al suo posto**: a bus factor 1 la review di
  sé stessi è cerimonia; i difetti reali (P-1, P-2) non si vedono in un diff, si
  vedono eseguendo. PR flow al secondo contributor.
- **Boost keyword su `KNOWN_SITES` resta fino a v0.0.4**, solo dichiarato nel
  demo-script: rimuoverlo prima romperebbe la demo senza il sostituto pronto.
- **Scenografia congelata** fino a dopo v0.1.0-beta1.
- **Issue #1 (Norimberga/MoE)**: decisione rimandata ai numeri della matrice EVAL
  (Fase 5) — la premessa dell'issue era imprecisa, il tier Optimal è già MoE.
- **I tag di release sono un'azione locale**: le sessioni cloud hanno il push dei
  tag rifiutato dal proxy git (HTTP 403, verificato).
- **Le sessioni bridge (CLI locale) si raggiungono solo** via `create_trigger`
  con `persistent_session_id` + `fire_trigger`; non espongono `usage`.
- **P-5 (tier RAM) non è verificabile su ENV-W**: con 256 GB fisici le JVM
  auto-dimensionano l'heap e i pesi dei modelli stanno in VRAM. Serve ENV-L o
  `mem_limit` espliciti (v0.0.3, T-PROF).
- **Le attese di `expected/baseline.json` non si piegano ai risultati**: l'XPASS
  di T0.10 non è stato promosso a PASS, perché avrebbe cristallizzato nel metro
  di riferimento una proprietà che il run non dimostra.
- **`NS_RECENCY_SECONDS` = 300 di default** e tetto per-test derivato dai
  parametri del test: un test che coi soli default non può finire è un test che
  non flipperà mai da solo.
- **`RUN_NIGHTLY` si imposta separatamente dalla registrazione del runner, e di
  proposito** (9ª entry): la variabile *è* l'interruttore della nightly, non un
  dettaglio di configurazione. `ci-nightly` ha `schedule: cron "30 2 * * *"` e il
  gate `if: vars.RUN_NIGHTLY == 'true'`, quindi impostarla accende la nightly
  della notte stessa; e il suo ultimo step è `docker compose ... down -v`, che
  **cancella `ollama_data`**. Registrare il runner e accendere la nightly sono
  due decisioni distinte e vanno prese distintamente.

**Numeri misurati**
- **Run di riferimento** `20260826-2053-envw-5eb456a` (ENV-W, modelli reali,
  suite `full` contro il tag): **5 PASS + 6 XFAIL + 1 XPASS**, `RESULT: OK`. È il
  metro di ogni release successiva.
- **P-1, P-2, A-2, A-3, A-5 confermati per misura**; **D-1/D-2/P-1 doc** chiusi da
  T0.12 (XFAIL → PASS, il progression test dichiarato per v0.0.1).
- **A-8 scoperto per misura**: agent cieco ai topic CDC per **4 min 46 s**
  seguendo l'ordine documentato. Non era nella review. Issue #39, fix in v0.0.4.
- **XPASS di T0.10 spiegato**: con 61 punti in collection e `top_k=5` il match
  letterale entra comunque; il test dipende dalla dimensione del corpus → issue
  #40, da rafforzare prima che il suo esito significhi qualcosa.
- **P-9 confermato su clone pulito** (9ª entry): i tre script del Quick Start sono
  `100644` in git e `./start-addon.sh --help` termina con **exit 126**,
  `Permission denied`. Non è un file mancante (sarebbe 127): manca il bit di
  esecuzione. È il primo comando del Quick Start.
- RSS totale dello stack full su ENV-W: **9,52 GiB** (non è una verifica di P-5).
- Costo del processo: ~81,6 M token letti da cache contro ~310 mila generati
  (263:1). Il costo è rilettura, non generazione.

**Aperto**
**Consegnato alla Fase 1 (v0.0.2)**
- **#41 — P-9**: script del Quick Start non eseguibili su clone pulito (exit 126).
- **#42 — P-10**: teardown di `ci-nightly` con `down -v` che cancella `ollama_data`.
  **Da chiudere prima di impostare `RUN_NIGHTLY`**: finché la variabile è spenta il
  gate tiene il workflow dormiente e il runner registrato è innocuo.
- Progression test dichiarato di v0.0.2: **T0.6** (doppio listener Kafka).

**Ancora aperto oltre la Fase 1**
- **#40** — T0.10 non è un test robusto di ciò che dichiara di misurare (Fase 3).
- **P-5** verificabile solo su ENV-L o con `mem_limit` (Fase 2, T-PROF).
- **RP-0** (probe DinD su RunPod) non eseguito — e reso **opzionale**: tutta la
  matrice EVAL entra nei 24 GB della 3090, quindi gira su ENV-W via `ci-nightly`.

**Risolto rispetto alla testa precedente**
- **ENV-W può di nuovo pubblicare su GitHub**: `gh auth status` → autenticato come
  `danielesalpietro` (scope `repo`), `ssh -T git@github.com` → autenticazione OK,
  `git push --dry-run` → exit 0. Il blocco che rendeva ENV-W «un ambiente che
  misura ma non pubblica» non c'è più.

**Correzioni alla review prodotte dalla misura** — la fase ha smentito o
ridimensionato quattro affermazioni del documento che l'ha aperta: **A-8** non è
costante (~5 min) ma uniforme in [0, 5 min]; **P-6** non è riproducibile su host
preconfigurato; **A-1** resta vero nel meccanismo ma la sua premessa sul ranking
non regge su corpus piccolo — e la collection era piccola *a causa di A-3*, un
difetto che ne mascherava un altro; **P-5** stimava 20-24 GB contro 9,52 GiB
misurati. È il funzionamento previsto del metodo: il report comanda sul documento.

---

## ESITO FASE 1 — chiusa il 2026-08-27 con il tag `v0.0.2` → `966422d`

**Esito**: fase chiusa. Tag annotato `v0.0.2` → `966422d`, `develop` allineato col
merge `cfc98f3`. Nove sub-issue chiuse (#16, #17, #18, #19, #20, #41, #42, #45, #46,
#48). **È la prima release che cambia il comportamento del sistema**: v0.0.1 aveva
aggiunto misura e verità documentale senza toccare lo stack.

**Che cosa rilascia v0.0.2**: lo stack è raggiungibile dall'host come documentato e
riproducibile nel tempo. **P-1, l'unico BLOCKER comportamentale della review, è chiuso
nel comportamento** — non solo nel codice.

**Numeri misurati** (tutti su ENV-W, in finestra di manutenzione dichiarata)
- **T0.6 XFAIL → PASS con modelli veri**, in **due** nightly consecutive contro
  `6b377a3` (run 33068899387 e 33069809809): probe `kcat` host-network che ottiene
  `broker 1 at localhost:29092 (controller)`. T0.2 e T0.3 PASS in entrambe: il cambio
  d'immagine Kafka non ha introdotto regressioni.
- **`granite4:32b-a9b-h` entra nella 3090**: picco **19 788 MiB su 24 576**, 100% GPU,
  margine 4,7 GiB, contesto 32k preallocato, 101 s a freddo e 1-3 s a caldo.
  L'assunzione su cui poggia la matrice EVAL di beta1 non è più un'assunzione.
- **P-11 quantificato**: con volume `kafka_data` della vecchia immagine, **46 restart**
  in crash-loop; con volume fresco, **healthy in 23 s**. `bitnamilegacy/kafka:3.7.1`
  gira `uid=1001 gid=0(root)`, `apache/kafka:4.3.1` gira `uid=1000 gid=1000`.
- **Soak parziale** `20260827-1406-envw-c6b56d3` (~7 h, non T-SOAK-24h): campionatore
  validato con 5 sonde contro `psql`, sempre concordi, forzando anche lo stato
  inattivo. Divario DB/Qdrant alla partenza: 95.

**Decisioni prese, con il perché e le alternative scartate**
- **#17 prima di #16**: l'immagine definitiva prima dei listener, così la
  configurazione è scritta una volta sola e T0.6 flippa sull'immagine finale.
  *Scartata*: listener sull'immagine Bitnami e migrazione dopo — avrebbe significato
  riscrivere la stessa configurazione due volte (i prefissi `KAFKA_CFG_*` e `KAFKA_*`
  non sono intercambiabili) e far flippare il progression test su un'immagine
  destinata a cambiare.
- **Teardown `ci-nightly`: rimozione esplicita dei soli tre volumi di stato** che la
  suite T0 esercita, al posto di `down -v`. *Scartata*: "tutti tranne `ollama_data`" —
  i volumi di MinIO/OpenMetadata appartengono a servizi congelati e ripulirli non
  aggiunge garanzie di test. *Scartata*: `ollama_data` come volume esterno, più robusto
  ma con una procedura di primo avvio diversa; rimandata a issue separata.
- **P-11 chiuso nel preflight, non solo con una nota di migrazione.** Motivo, di chi ha
  eseguito la misura: *la nota la legge chi sospetta già un problema di aggiornamento;
  chi non lo sospetta vede solo un broker che non parte.* La nota resta come
  complemento, non come sostituto.
- **Una nota di migrazione unica per P-11 e P-13**, con l'ordine esplicito (rimuovere
  **prima** del `git pull`), invece di due note separate: sono lo stesso difetto.
- **T0.4/T0.5 al gate come verdi con qualificazione dichiarata**, non verdi e basta.
  *"Non è una regressione"* e *"la nightly è affidabile"* sono affermazioni diverse e
  solo la prima è dimostrata. Senza la qualificazione, fra un mese avremmo una suite
  i cui rossi nessuno guarda più.
- **Finestra GPU non estesa per il soak da 24 h**: l'harness aveva un difetto e una
  finestra si spende misurando, non debuggando (§2.1). Il T-SOAK-24h si prenota a
  parte, con harness ormai provato.

**Lezioni che hanno generato una regola**
- **Le finestre GPU su ENV-W si prenotano, non si occupano** (piano §2.1): la Z8 è
  noleggiata su vast.ai fuori dalle finestre, ha due stati, e una finestra prenotata
  va spesa misurando — quindi prova a secco prima, e richiesta all'apertura della fase.
- **Una misura che conferma l'ipotesi attesa va controllata due volte** (`CLAUDE.md`
  §5): due casi lo stesso giorno — il 32b letto a `100% CPU` e lo slot di replica letto
  `false` — entrambi falsi, entrambi in accordo con ciò che ci aspettavamo. Corollario:
  **un campo derivato deve distinguere "falso" da "non l'ho potuto sapere"**; una
  costante travestita da misura è peggio di un campo assente.
- **Le anomalie si scrivono quando si incontrano, non alla chiusura** (`CLAUDE.md` §5):
  P-11 e P-12 sono arrivati alla supervisione solo perché la sessione bridge si è
  bloccata e ha dovuto chiedere.
- **Agganciare sempre `source_url` e `source_revision` alla creazione di una sessione**
  (`CLAUDE.md` §7.5): due sessioni partite in un container senza repository, ~0,49 $
  ciascuna e zero lavoro.
- **Su branch condiviso l'SHA si annota dopo il push**: due entry hanno citato SHA
  pre-rebase inesistenti.

**Il ritrovamento che vale oltre questa fase**
**P-11, P-12 e P-13 sono un difetto solo visto da tre lati** — Docker gira come root e
lascia stato che l'utente non può toccare: un volume, una directory, la stessa
directory dentro un clone. E nessuno dei tre è stato intercettato dalla CI per **una
sola** ragione: ogni run parte da zero, quindi la catena di verifica esercita
sistematicamente l'unico caso che funziona. Non è una lacuna di copertura risolvibile
con più test: è una **classe di stato che la CI non visita mai**, e che solo una
macchina con una storia può esercitare. È l'argomento più forte, e su base empirica,
a favore delle finestre di verifica su hardware reale.

**Aperto a fine fase**
- **`RUN_NIGHTLY` resta spenta.** Il blocco tecnico (#42) è caduto, ma restano due
  argomenti: manca il *warm-up gate* (#47) e alle 02:30 nessuno sa se ENV-W è in
  manutenzione o a noleggio (#44). Decisione dell'owner.
- **#47** warm-up gate (Fase 3) · **#44** esclusività dell'host (Fase 2, con il flag
  `--exclusivity` e le condizioni iniziali già scritti su `feature/soak-harness`) ·
  **#40** T0.10 non robusto (Fase 3) · **P-5** e T-PROF (Fase 2).
- **T-SOAK-24h non eseguito**: solo un parziale da ~7 h. L'harness è su
  `feature/soak-harness` e verrà consumato in Fase 4 (v0.0.4).
- **`preflight.ps1` mai collaudato su Windows/ENV-L.**

**Costo della fase**: sessione A ~6,42 $, sessione B ~11,54 $ (`claude-sonnet-5`
entrambe), supervisione `claude-opus-5` ~150 $ nozionali; ENV-W non misurabile
(sessione bridge). Abbonamento MAX: nessun addebito reale.

---

## ESITO FASE 2 — chiusa il 2026-08-30 con il tag `v0.0.3` → `442bac1`

**Esito**: fase chiusa. Tag annotato `v0.0.3` → `442bac1`, `develop` allineato col
merge `f585e38`. Chiuse #21, #22, #24 e #44 (quest'ultima da riverificare, v. sotto);
**#23 resta aperta** e richiede ENV-L. Obiettivo O4: smettere di mentire sulle risorse.

**Che cosa rilascia v0.0.3**: lo stack dichiara quanto consuma e lo rispetta. Trino
interroga davvero il Postgres operativo, i profili separano ciò che serve da ciò che
è scenografia, e ogni servizio ha un tetto di memoria — **misurato, non stimato**,
dopo che due dei tetti si sono rivelati sotto il footprint reale.

### Numeri misurati

- **T0.7 XFAIL → PASS su hardware vero.** Suite 9 PASS / 3 XFAIL / 1 XPASS, nessuna
  regressione. Trino conta 15 477 righe su `postgresql.public.orders`, coincidente
  con `psql` cifra per cifra.
- **T-PROF**: profilo `core` a **3,0 GiB** contro il criterio di 14 GB — **oltre 4×**
  di margine. Contro il criterio più stretto (somma dei tetti dichiarati, 5 952 MiB)
  sta comunque dentro.
- **P-5 chiuso nel comportamento.** Soak #1 "prima" (427 campioni, 7,39 h) contro
  soak #2 "dopo" (420 campioni, 26 569 s, finestra comune ≈ entrambi i run interi):
  RSS totale mediano **15 170 → 7 986 MiB, −47%**.
- **La risposta di Trino è la pendenza, non il livello.** La crescita relativa è +73%
  prima e +60% dopo, che da sola non direbbe nulla. Per quarti:
  **+694/+630/+183/+130 MiB/h senza tetti** — ancora in salita dopo 7,4 ore — contro
  **+169/+165/+0,5/+0,3** con i tetti. Pendenza sulla seconda metà: **+150,0 → +0,5**.
- **Gate dei due tetti corretti, verde** (`20260829-1936-envw-d2bd3aa-gate`, 46
  campioni): `RestartCount` **0→0 su tutti e 19**, `elasticsearch` all'**82,6%** di
  2048m, `open-webui` piatto a **654,8 MiB ±0,02**, 63,9% di 1024m, `healthy`.
  Totale sotto tetto 7 202 MiB su 16 704 (43%), `ollama` esente a 604,5 MiB.
- **I due tetti sbagliati, quantificati**: `open-webui` 512m → **1024m** (footprint
  reale 679,7 e 687 MiB; **3 474 riavvii** in 7,4 h, 6 151 al teardown);
  `elasticsearch` 1536m → **2048m** (1 529 MiB = **99,5%** del tetto, `memory.peak`
  esattamente 1 536,0, **23 riavvii**, 40 al teardown).
- **VRAM sui 427 campioni del soak #1**: min 362, mediana 362, max 2 671 MiB, media
  380,7, **5 campioni sopra 1 GiB (1,17%)**, copertura 427/427. **Sei valori distinti
  in tutta la serie**: la VRAM non è occupata con continuità, il fabbisogno viene
  dalle generazioni di `/compare`, a raffiche.
- **#44 rotto dalla seconda GPU**: con un tenant su 22 GiB della 3090, la somma dei
  device dichiara **18 260 MiB liberi** mentre la scheda singola più libera ne ha
  **16 184**.

### Decisioni prese, con il perché e le alternative scartate

- **Catalogo `postgresql.properties`, non `postgres.properties`**: il nome del file
  fissa il nome del catalogo, e T0.7 (scritto prima) punta su
  `postgresql.public.orders`. La review lo chiama diversamente di sfuggita, ma il
  contratto vincolante è il test. *Scartato*: rinominare, che avrebbe fatto fallire
  T0.7 in silenzio.
- **Heap Trino fisso (`-Xms1G -Xmx2G`)** invece del default `MaxRAMPercentage=80`,
  che senza `mem_limit` dimensiona l'heap sull'80% della RAM **dell'host** — cioè
  esattamente il comportamento che P-5 denuncia.
- **`elasticsearch` a 2048m tenendo `-Xmx1g`.** *Scartato*: abbassare `-Xmx` o
  `MaxDirectMemorySize`, che avrebbe fatto stare i numeri dentro un tetto scelto male
  invece di correggere il tetto — e `-Xmx1g` è l'unico valore del compose ancorato a
  un'impostazione esplicita.
- **Soak #2 con tutti i profili attivi.** Dopo O4.1 un `compose up` nudo avvia solo
  `core`: un "dopo" lanciato così avrebbe confrontato 12 container con 19, e la
  differenza sarebbe stata dominata dai sette mancanti invece che dai tetti. Regola
  scritta in `piano_ricovero.md` §4.3.2: **un confronto prima/dopo varia una cosa sola**.
- **T-SOAK-24h aspetta la chiusura di A-3.** Oggi (a) e (c) falliscono per la
  sovrascrittura del corpus. *Scartato*: farlo subito "per avere il numero", che
  avrebbe speso 24 ore per rimisurare un guasto noto.
- **Tabella tier non riscritta nel README.** T-PROF ha misurato `core` a 3,0 GiB e
  quello è scritto, ma le righe RAM/VRAM per tier sono di #23, che ha bisogno di
  ENV-L per la domanda sui 16 GB. *Scartato*: riscriverle ora — sarebbe stato tirare
  a indovinare travestito da release note.
- **A-3 riclassificata**: non è crescita illimitata, è **distruzione silenziosa di
  dati**. Prova: il punto `id=3` porta un evento delle 13:41:55Z mentre `id=27413`
  ne porta ancora uno delle 12:31Z — il contatore è ripartito da zero e risale sopra
  il corpus esistente.

### Regole che questa fase ha generato

1. **Un test nuovo va falsificato prima di essere creduto** (`CLAUDE.md` §5, terzo
   caso). T0.7 era stato dichiarato PASS da un'asserzione che **non poteva fallire**:
   univa stderr a stdout e ricavava il conteggio da `head -1 | tr -dc '0-9'`, cioè
   dal timestamp di un WARNING. Una query a zero righe veniva valutata OK.
2. **Un tetto troppo stretto si legge come poco consumo, non come troppo.** Il
   processo muore prima di crescere: `open-webui` mostrava 138 MiB di mediana, il
   numero più basso della sua fascia, mentre era il servizio più rotto dei diciannove.
   Si cerca con `RestartCount`, mai con l'RSS. Terza condizione di §4.3.1(d).
3. **`OOMKilled` non è attendibile**: `false` per tutto il soak mentre ES restartava
   23 volte per memoria, perché esce da sé sotto `ExitOnOutOfMemoryError`.
4. **Un test è verificato contro una configurazione, non per sempre.** #44 è stato
   scritto, falsificato su tre stati e approvato il 28/08 su una macchina a una GPU;
   il 29 è arrivata la seconda scheda e il controllo era sbagliato lo stesso giorno.
5. **Un run lungo deve archiviarsi da solo** — checksum e copia come ultimo passo
   dello script, non primo passo della sessione successiva.

### Che cosa resta aperto

- **#23** (tier misurati, righe VRAM 16 GB, collaudo `preflight.ps1` su Windows):
  richiede **ENV-L**, unica cosa che tiene la Fase 2 formalmente incompleta.
- **#44 da riverificare su due device** dopo la correzione per-device.
- **`RUN_NIGHTLY` spenta**; #47 (warm-up gate) aperto; #40 (T0.10 non robusto,
  colto in flagrante: XPASS alle 12:40Z e XFAIL alle 12:47Z sullo stesso stack).
- **T-SOAK-24h** mai eseguito, in attesa di A-3.
- `verdict_caps.py`: la lista delle esenzioni dichiarate può divergere dal compose —
  rischio noto e reso visibile (un servizio senza tetto e non in lista resta UNKNOWN).
- RP-0 opzionale ma non archiviabile.

### Lezione di processo

La sessione bridge su ENV-W **si è archiviata quattro volte in tre giorni**, una
volta nove minuti dopo aver ricevuto un compito. Il campionatore distaccato ha
salvato la misura **tre volte su tre**, ma l'analisi è arrivata con ore o un giorno
di ritardo, e il passo di archiviazione è stato saltato ogni volta. Da qui il runner
che si distacca e chiude l'archivio da sé (`bench/gate/`). `tmux`, raccomandato tre
volte, non è mai stato applicato.

E il ritrovamento più prezioso della fase non viene da una misura: **tre soglie
scritte a tavolino sono state corrette in due giorni**, tutte perché la sessione che
le applicava le ha eseguite **alla lettera invece di aggirarle**. Una soglia scritta
a tavolino non è un fatto, è un'ipotesi, e va falsificata sulla prima misura vera
esattamente come un test.
