# LOGBOOK — Fase 3: Agent robusto (v0.0.4)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata il 2026-08-31, dopo la chiusura di A-3

**Dove siamo**: Fase 2 chiusa col tag `v0.0.3` → `442bac1`, `develop` allineato
col merge `f585e38`. **A-3 è chiuso** (31/08, ENV-W): l'id di un punto Qdrant è
`uuid5(NAMESPACE, "topic:partition:offset")` e non più un contatore in RAM.
**T0.8 XFAIL → PASS**, falsificato rimettendo il contatore, suite piena **10 PASS
/ 2 XPASS / 1 XFAIL** senza regressioni. Prova diretta su tutta la collection
attraverso un riavvio: **0 punti preesistenti cambiati, 0 spariti**, +10 nuovi
tutti con id UUID. Report:
[`20260831-1209-envw-db4c22a-a3.md`](../runs/20260831-1209-envw-db4c22a-a3.md).

**T-SOAK-24h è in corso** — il primo del progetto, lanciato il 31/08 alle
16:44:38Z su ENV-W: **`RUN_ID 20260831-1644-envw-4d5f24a`**, intervallo 60 s,
durata 86 400 s, `--exclusivity shared` — **dichiarazione sbagliata, in senso conservativo**: `caliper-flowise` si era fermato alle 16:19:47Z, 25 min prima del lancio, e l'host è stato libero da estranei per tutto il run (addendum in fondo al file) —, distaccato sotto **PPID 1**, con
`SHA256SUMS` che il run scrive da sé a fine corsa. Fine attesa **01/09 ~16:44Z**.
Lo stack è stato riavviato **a freddo** (19 container, 22 min di assestamento
dichiarati) proprio per restare confrontabile col "prima": Trino partiva da
**981 MiB** nel soak #2 e stava a **1 470 MiB** sullo stack caldo da 20 h — partire
di lì avrebbe variato due cose invece di una. Primo campione: RSS totale
**7 691,8 MiB**, Qdrant **37 903** punti, slot attivo, `soak.err.log` vuoto.

**Al ritorno, due trappole già identificate.** (1) **Integrità prima del
verdetto**: `seq` contigui, `soak.err.log`, `sha256sum -c SHA256SUMS` — e dire ciò
che manca invece di interpolare. (2) **Il check (a) va calcolato a mano**, perché
`verdict.py:62` implementa ancora quello vecchio (`any(points[i] <= points[i-1])`
→ OK), che su ~1 440 campioni non può fallire e non legge mai il flusso eventi del
DB che §4.3.1 ora richiede: **comanda il piano**. E una **premessa di §4.3.1 si è
sfaldata**: motiva il WARN di (a) con «finché A-3 non è chiuso non esiste una
retention», ma **A-3 è chiuso e la retention non esiste comunque** — l'unico
`maxlen` in `stream-agent/app.py` è il buffer in RAM, niente sulla collection.
La conclusione (niente retention → WARN) regge, la motivazione no.

**Due cose che la prossima sessione deve sapere e non riscoprire.** La
**migrazione è l'opzione (1)**, «non fare nulla»: i 32 841 punti con id intero
restano, quindi **la corruzione storica è nel corpus, congelata** — la
ricreazione della collection (opzione 2) si decide in A-2, che tocca lo stesso
punto. E la DoD «nessun punto con id basso porta un evento più recente di uno con
id alto» **non è applicabile alla lettera**: i legacy conservano per sempre
l'inversione già prodotta, e fra UUID «basso» e «alto» non significano nulla. La
forma che misura la stessa cosa, ed è quella eseguita, è *nessun punto
preesistente cambia payload attraverso un riavvio*.

**Scope della fase** (`docs/piano_ricovero.md` §6, riga v0.0.4): rendere l'agent
robusto. Issue di fase
[#6](https://github.com/danielesalpietro/NORTHSTREAM/issues/6). È **la fase più
costosa del piano** — ridisegno del retrieval, suite EVAL e soak — e tocca
`stream-agent/app.py`, cioè il codice più delicato del progetto.

| Finding | Contenuto | Progression test |
|---|---|---|
| **A-3** | Point-id deterministici da `(topic, partition, offset)` al posto del contatore in RAM | T0.8 |
| **A-2** | Timestamp nel payload + filtro recency in query | T0.9 |
| **A-1** | Rimozione del boost keyword su `KNOWN_SITES`, sostituito da `Filter` su payload | T0.10 |
| **A-5** | `/health` che verifica davvero Kafka, Qdrant, Ollama e il thread consumer | T0.11 |
| — | `group_id` Kafka, logging strutturato, `query_points` al posto della API deprecata | — |

**A-3 ha priorità, e non per l'ordine alfabetico.** La Fase 2 l'ha osservata in
produzione e riclassificata: **non è crescita illimitata, è distruzione
silenziosa di dati**. Il punto `id=3` portava un evento delle 13:41:55Z mentre
`id=27413` ne portava ancora uno delle 12:31Z — il contatore riparte da zero a
ogni riavvio dell'agent e risale sopra il corpus esistente. Finché A-3 è aperto:

- i check **(a) e (c)** del soak falliscono per costruzione, quindi **T-SOAK-24h
  non si prenota** (spenderebbe 24 ore per rimisurare un guasto noto);
- il corpus su cui il RAG risponde non è ricostruibile, quindi **nessuna misura
  EVAL fatta prima della chiusura di A-3 è confrontabile** con quelle dopo.

**Ereditato dalla Fase 2, da non riscoprire**
- Il retrieval attuale contiene il boost keyword su `KNOWN_SITES` (A-1): va
  **rimosso** in questa fase, non "sistemato" per altre vie.
- T0.10 **non è robusto** ([#40](https://github.com/danielesalpietro/NORTHSTREAM/issues/40)):
  colto in flagrante il 28/08 con XPASS alle 12:40Z e XFAIL alle 12:47Z **sullo
  stesso stack**. Quella coppia è il caso di prova per irrobustirlo, non un
  aneddoto. Va sistemato **prima** di usarlo come progression test di A-1.
- L'XPASS di T0.9 è stato lasciato intatto: due letture concordi non bastano a
  dichiarare A-2 chiuso.

**Regole della Fase 2 che valgono qui**
1. **Un test nuovo va falsificato prima di essere creduto**: si rompe di
   proposito la condizione che asserisce e si verifica che diventi rosso.
2. **Un confronto prima/dopo varia una cosa sola** (`piano_ricovero.md` §4.3.2).
3. **Una soglia scritta a tavolino è un'ipotesi**, non un fatto: tre soglie di
   §4.3.1 sono state corrette in due giorni, tutte perché applicate alla lettera
   invece che aggirate.
4. **Un run lungo si archivia da solo**, con checksum, come ultimo passo.

**Aperto all'ingresso in fase**: #23 (ENV-L, tier misurati e `preflight.ps1` su
Windows) · #44 **verificato a runtime il 31/08** (lettura per-device prodotta e consumata dal gate; ramo di contesa non esercitato) · #47 (warm-up gate) · `RUN_NIGHTLY`
spenta · T-SOAK-24h **in corso** (`20260831-1644-envw-4d5f24a`, fine attesa 01/09 ~16:44Z).

**Prossimo passo**: **#40**, irrobustire T0.10 — è infrastruttura di test, quindi
anticipabile, e **sblocca A-1**; T0.10 ha dato XPASS anche il 31/08, terzo esito
discordante. Poi **A-2**, dove va decisa anche l'opzione (2) sulla ricreazione
della collection.

---

## 2026-08-31 — ENV-W (Z8) — sessione operativa A-3

- **Obiettivo della sessione**: chiudere **A-3** — point-id deterministici da
  `(topic, partition, offset)` in `stream-agent/app.py` — e far flippare **T0.8**.

- **Fatto** (commit in coda a questa entry):
  - `stream-agent/app.py`: via il contatore in RAM `_point_id`/`next_point_id()`, al suo
    posto `point_id(topic, partition, offset)` = `uuid5(POINT_ID_NAMESPACE, "t:p:o")`, con
    il namespace **fissato come costante** e la derivazione scritta nel commento.
  - `bench/t0/tests/t0.08_qdrant_restart_ids.sh`: l'asserzione ora copre il contratto che
    l'intestazione prometteva già.
  - `bench/t0/expected/current.json`: `T0.8: PASS`, `T0.8` tolto da `flips`, `target`
    invariato.
  - Report: [`docs/runs/20260831-1209-envw-db4c22a-a3.md`](../runs/20260831-1209-envw-db4c22a-a3.md);
    grezzi in `~/NORTHSTREAM-archive/20260831-1209-envw-db4c22a-a3/`, 35 file con
    `SHA256SUMS` verificato.

- **Decisioni prese**:
  1. **`uuid5`, non un intero da SHA-256.** L'handoff ammetteva entrambe. Ho scelto l'UUID
     perché non richiede di scegliere quanti byte troncare, e ogni troncamento è una
     decisione sulla probabilità di collisione che nessuno rivede mai. L'alternativa
     scartata resta valida se un giorno servisse un id numerico.
     Prova che `hash()` era la trappola giusta da evitare, misurata su tre processi con
     `PYTHONHASHSEED` diverso: `uuid5` identico tutte e tre le volte, `hash()` diverso
     tutte e tre.
  2. **Migrazione: opzione (1), «non fare nulla».** I 32 841 punti con id intero restano.
     Distruggere dati per chiudere un finding di distruzione dati sarebbe una risposta
     bizzarra, e la ricreazione della collection (opzione 2) tocca lo stesso punto di A-2:
     si decide lì, col filtro recency davanti. **Conseguenza agli atti: la corruzione
     storica resta nel corpus, congelata.**
  3. **La definition of done è stata eseguita in una forma diversa da come è scritta, e il
     perché è la notizia** — v. sotto.

- **Test eseguiti** (Docker reale, 19 container, `release/v0.0.4` @ `db4c22a`):
  - T0.8 sul codice **vecchio**, con l'asserzione nuova → **XFAIL/KO in 33 s**:
    «10 of 200 sampled points changed payload across the restart».
  - T0.8 col **fix** → **XPASS/OK**: «count grew by 12 and all 200 sampled points kept
    their payload».
  - T0.8 con la **falsificazione** (contatore rimesso apposta, rebuild vero) → **XFAIL/KO**,
    stesso messaggio del primo caso. Il test può ancora fallire.
  - Suite `full` dopo il ripristino → **10 PASS / 2 XPASS / 1 XFAIL**, `RESULT: OK (no
    regression)`. I 9 PASS precedenti reggono, T0.8 è il decimo.
  - Prova diretta su **tutta** la collection attraverso un riavvio: 32 984 → 32 994 punti,
    **0 preesistenti cambiati, 0 spariti**, 10 nuovi tutti con id UUID.

- **L'assurdo, riferito invece che aggirato**: la DoD chiede «dopo un riavvio, nessun punto
  con id basso porta un evento più recente di uno con id alto». Con la scelta (1) quella
  condizione **non può passare** — non perché il difetto sia aperto, ma perché i punti
  legacy conservano per sempre l'inversione già prodotta: sono cicatrici, non ferite. E sui
  punti nuovi è **inesprimibile**, perché fra UUID «basso» e «alto» non significano nulla.
  Un criterio che diventa insensato proprio quando il fix funziona non può essere il
  criterio. La forma che misura la stessa cosa — *nessun punto preesistente cambia payload
  attraverso un riavvio* — vale per legacy e nuovi insieme, ed è quella eseguita.

- **Costo della sessione**: **non misurabile** (sessione bridge).

- **Non funziona / sospeso**:
  - **T0.10 di nuovo XPASS** (7 s): terzo esito discordante sullo stesso test.
    [#40](https://github.com/danielesalpietro/NORTHSTREAM/issues/40) va chiuso prima di
    usarlo come gate di A-1. Non toccato: fuori scope.
  - **T0.9 XPASS** (324 s), coerente con la lettura precedente. Lasciato intatto.
  - **Ollama gira ancora 100% CPU** dal riavvio del 30/08: non invalida questo run (il fix
    è sull'id, non sul vettore) ma ogni tempo qui è un tempo su CPU.
  - **Limite residuo dichiarato**: l'id è unico finché il topic non viene ricreato. Se
    Kafka perde il volume, gli offset ripartono e la stessa terna indicherebbe un evento
    diverso. È ciò che farebbe un `down -v`, già vietato per P-10/#42.
  - **Non ero in `tmux`**: detto all'owner prima di iniziare.

- **Prossimo passo per la sessione successiva**: **#40** (irrobustire T0.10 — è
  infrastruttura di test, anticipabile, e sblocca A-1), poi **A-2**, dove va anche decisa
  l'opzione (2) sulla ricreazione della collection.

- **Decisioni richieste all'owner**:
  1. La DoD «id basso / id alto» va **riscritta** nella forma eseguita, altrimenti resterà
     impossibile da soddisfare per chiunque la applichi alla lettera.
  2. Confermare che questa sessione può committare codice: `CLAUDE.md` §2 dice di no, il
     briefing di fase dice di sì. Ho seguito il briefing e l'ho dichiarato.

---

## 2026-08-31 — ENV-W (Z8) — sessione operativa T-SOAK-24h

- **Obiettivo della sessione**: lanciare il primo T-SOAK-24h del progetto e
  metterlo al sicuro, non sorvegliarlo.

- **Fatto**:
  - **Identificato l'host prima di ogni altra cosa**: `berlin-3eie`, 2× Xeon Gold
    6244 (32 thread), 235 GiB, RTX 3090 + RTX 5060 Ti → **è la Z8, ENV-W**. Prova
    indipendente oltre alle specifiche: `~/NORTHSTREAM-archive/` contiene i run del
    27 e 28/08, quindi è la stessa macchina che ha prodotto il "prima". Tag
    `--env envw`, e questo run **è** il "dopo" dei due soak da 7,4 h.
  - Allineata la working copy viva `~/claude/ns-work` a `release/v0.0.4` @
    `4d5f24a` (**19 commit avanti** a `develop`).
  - Precondizioni verificate una per una: `bench/soak/run.sh` presente ·
    `grep -c uuid5 stream-agent/app.py` → **3** · `open-webui` `mem_limit: 1024m`.
  - Stack riavviato **a freddo**: `down` (senza `-v`: volumi named preservati,
    corpus Qdrant e slot di replica intatti) + `./start-addon.sh --gpu`. Bring-up
    chiuso alle **16:22:18Z**, **19 container** in esecuzione, i due job one-shot
    (`create-minio-bucket`, `execute-migrate-all`) usciti come atteso.
  - Assestamento **22 minuti** (16:22:18Z → 16:44:27Z), sopra il minimo di 15.
  - Soak lanciato: **`RUN_ID 20260831-1644-envw-4d5f24a`**, cartella
    `results/20260831-1644-envw-4d5f24a`, `--interval 60 --duration 86400
    --env envw --exclusivity shared`, distaccato sotto **PPID 1** (PID 3469766).
    - follow: `tail -f results/20260831-1644-envw-4d5f24a/soak.out.log`
    - stop:   `pkill -f "soak/run.sh.*20260831-1644-envw-4d5f24a"`
    - fine attesa: **2026-09-01 ~16:44Z**, con `SHA256SUMS` scritto dal run stesso.

- **Decisioni prese**:
  - **Teardown prima del lancio, invece di partire sullo stack caldo.** Lo stack
    era su da 20 h e Trino stava a **1 470 MiB** contro i **981 MiB** del primo
    campione del soak #2, che partì da freddo. Lanciare da lì avrebbe misurato la
    pendenza di un Trino già assestato, non la curva freddo→assestato che ha
    misurato il "prima": due variabili invece di una, contro §4.3.2. **Alternativa
    scartata**: il solo `./start-addon.sh --gpu`, che con `--build` avrebbe
    ricreato il solo `stream-agent` lasciando caldi gli altri diciotto — uno stack
    di età mista, peggio di entrambi gli estremi perché il difetto non si vede.
  - **`--exclusivity shared`, non `exclusive`.** Le GPU sono libere (0 processi
    compute), ma sull'host gira `caliper-flowise` (altro progetto compose, up da
    20 h). Il campo chiede «era ENV-W nostro solo», non «era libera la GPU».
    Coerente col precedente del gate 29/08, che dichiarò non esclusivo per un
    container estraneo effimero.
  - **`--gpu` mantenuto** benché il soak non sia GPU-sensibile: è la
    configurazione del "prima". Per la stessa ragione `docker-compose.gpu.yml`
    resta a `count: all` — fissare la scheda è corretto (blocco aperto del 30/08)
    ma è una modifica di comportamento, e non va infilata dentro il run che deve
    fare da termine di paragone.

- **Test eseguiti**:
  - `python3 bench/lib/gpu_exclusivity.py` → `state: exclusive`,
    `gpu_max_free_single_device_mib:` **24567**, `gpu_free_mib: 40868`, 0 processi
    estranei, 2 device. **Prima verifica a runtime di `e5588c9` (#44)**: il campo
    per-device viene prodotto ed è quello che `preflight.sh` usa per il gate — la
    somma resta solo come dato riportato, col commento che la chiama «a false
    green». *Limite dichiarato*: il ramo di contesa **non** è stato esercitato (0
    processi estranei sulle GPU), quindi è verificata la lettura, non lo scatto
    del FAIL.
  - Connettore CDC `northstream-postgres-connector`: `RUNNING`, task `RUNNING`
    (la config è sopravvissuta al teardown nel topic di Kafka).
  - Slot di replica: `active = t`, **3 760 B** trattenuti.
  - Postgres: `orders` **55 663**, `sensor_readings` **55 565** (il soak #2 partì
    da 14 233 / 14 238: i dati sono persistiti attraverso il teardown).
  - Qdrant: collection `stream_events`, **37 482** punti — il report A-3 citava
    32 984 → 32 994, quindi il corpus **cresce invece di essere riscritto**.
  - Agent `/health` → `ok`, 56 eventi in buffer. Ollama vede entrambe le schede.
  - Primo campione del soak: **19 container**, RSS totale **7 691,8 MiB** (contro
    la mediana 7 986 del soak #2 — coerente), `qdrant.points_count` 37 903, slot
    `active: true`, `table_counts` popolati, `soak.err.log` **vuoto**.

- **Costo della sessione**: non misurabile (sessione Claude CLI locale, il campo
  `usage` non è esposto — §4 vieta di stimarlo).

- **Non funziona / sospeso**:
  - **La ricetta di verifica del `mem_limit` produce un falso negativo.**
    `grep -A3 "northstream-open-webui" docker-compose-northstream-ai.yml | grep
    mem_limit` non restituisce **nulla**: `northstream-open-webui` è il
    `container_name`, la chiave di servizio è `open-webui:` (riga 392) e il
    `mem_limit` sta alla **402**, fuori dalla finestra `-A3`. Il valore vero è
    `1024m`. Presa alla lettera, la ricetta **ferma una sessione che è sul branch
    giusto**. Va riscritta ancorandola alla chiave di servizio.
  - **`verdict.py:62` implementa ancora il check (a) vecchio**:
    `plateaued = any(points[i] <= points[i-1])` → `OK`. Su ~1 440 campioni basta un
    solo campione non crescente per tingere di verde l'intero check, e non legge
    mai il flusso eventi del DB che §4.3.1 ora richiede. **Al ritorno comanda il
    piano**, e la divergenza va scritta nel report.
  - **Premessa sfaldata in `docs/piano_ricovero.md` §4.3.1.** La riga «Nessuna
    retention configurata (stato di oggi, A-3) → **WARN, mai OK**» è motivata con
    «finché A-3 non è chiuso non esiste una retention». **A-3 è chiuso e la
    retention continua a non esistere**: l'unico `maxlen` in `stream-agent/app.py`
    è il buffer in RAM (`recent_events = deque(maxlen=MAX_BUFFER)`), niente sulla
    collection Qdrant. La *conclusione* regge (niente retention → WARN), la
    *motivazione* no — il piano lega le due cose come se chiudere A-3 producesse
    una retention. Da riscrivere prima che qualcuno legga «A-3 chiuso» e ne deduca
    che (a) può ora dare OK.
  - **Due working copy sullo stesso host.** `~/claude/ns-work` è quella viva (è la
    `working_dir` con cui sono composti i container); `~/claude/NORTHSTREAM` è
    ferma su `release/v0.0.2` con sei file modificati non committati, e ha
    `trino/catalog` di proprietà **root** (creata da un container il 26/08, è il
    P-12) che fa fallire le operazioni git. Le modifiche sono in `stash@{0}`
    etichettato `leftovers-release-v0.0.2-pre-TSOAK24h-20260831`, **non
    cancellate**. Residuo di una delle quattro archiviazioni della sessione bridge.
  - **`tmux` ancora non applicato**: il soak è protetto da `--detach` (PPID 1), non
    da `tmux`. `bench/env-w/start-session.sh` esiste ma questa sessione non l'ha
    usato, perché opera via SSH dal laptop dell'owner e non come sessione CLI sulla
    Z8.

- **Prossimo passo per la sessione successiva**: al termine del run (atteso
  **2026-09-01 ~16:44Z**) verificare **prima l'integrità** di
  `results/20260831-1644-envw-4d5f24a` — `seq` contigui senza buchi, `soak.err.log`,
  `sha256sum -c SHA256SUMS` — e dichiarare ciò che manca invece di interpolare; poi
  emettere il verdetto sui quattro check di §4.3.1, **calcolando (a) a mano** perché
  `verdict.py` diverge dal piano, e scrivere il report in `docs/runs/`.

- **Decisioni richieste all'owner**: nessuna bloccante per il run in corso.
  1. `verdict.py` check (a) da riallineare a §4.3.1 (oggi non può fallire).
  2. La motivazione di §4.3.1 su retention/A-3 da riscrivere (v. sopra).
  3. `caliper-flowise` resta acceso sull'host: non l'ho toccato perché è di un
     altro progetto. Se i run futuri devono essere `exclusive`, spegnerlo è una
     scelta dell'owner.

### Addendum 2026-09-01 06:0xZ — `exclusivity: shared` nel manifest è sbagliato (in senso conservativo)

Su segnalazione dell'owner («`caliper-flowise` non dovrebbe partire, fermalo pure»)
è emerso che **il container era già fermo**, e da prima del lancio:

| Fatto | Valore misurato |
|---|---|
| `caliper-flowise` `FinishedAt` | **2026-08-31T16:19:47Z**, `ExitCode 0` (log: «Shutting down Flowise...») |
| Soak `started_at` | **2026-08-31T16:44:38Z** — **25 minuti dopo** |
| Container estranei in esecuzione durante il run | **nessuno** |

Quindi **per l'intera durata del run l'host è stato libero da estranei**: il valore
vero era `exclusive`, non `shared`.

**Come è nato l'errore, che è la parte utile.** La dichiarazione è stata presa da uno
`docker ps` delle ~16:1xZ — *prima* del teardown — e **non è stata ri-verificata al
momento del lancio**, 25 minuti dopo. È lo stesso modo di sbagliare delle tre lezioni
già in `CLAUDE.md` §5: un campo dichiarato da un ricordo invece che da una misura. Il
rimedio è meccanico e va nell'harness, non nella buona volontà: **`--exclusivity`
dovrebbe essere ri-verificato da `run.sh` all'istante del lancio** e la dichiarazione
del lanciatore confrontata con lo stato osservato, con un avviso in caso di divergenza.

**Perché il manifest non è stato corretto.** Il campo è documentato come «declared by
whoever launches the run, not inferred». È il verbale di una dichiarazione: riscriverlo
a posteriori farebbe dire all'archivio che era stato dichiarato `exclusive`, che è
falso. La correzione sta qui, accanto al dato, non al posto suo — in un progetto che si
è già bruciato con misure aggiustate dopo il fatto. `SHA256SUMS` non era ancora scritto,
quindi la scelta è deliberata e non forzata dalla tecnica.

**Effetto sul verdetto: nessuno.** L'errore è nella direzione conservativa — dichiara
condizioni peggiori di quelle reali. Chi emette il verdetto legga `shared` nel manifest
e **questa riga** come correzione: le condizioni erano migliori del dichiarato.

**Causa dello stop: non attribuita.** Il teardown di northstream girava attorno alle
16:19Z, ma non può averlo toccato — `caliper-flowise` ha label di progetto `caliper` ed
era attaccato alla sola rete `caliper_caliper-ai`, mai a quella di northstream (il
`down` ha rimosso `wap-northstream-lab_default` senza errori di endpoint attivi). Il
buffer eventi di Docker non copre più quell'istante. Essere rimasto giù per 14 h con
`restart=always` indica uno **stop esplicito**, non un crash. Registrato come non
spiegato invece che dedotto dalla coincidenza temporale.

**Azione eseguita** (autorizzata dall'owner): `docker update --restart=no
caliper-flowise` — era `always`, ora `no`, container `exited`. Non ripartirà al
prossimo riavvio del daemon o dell'host. Gli altri dieci container del progetto
`caliper` sono tutti `Exited` e hanno `unless-stopped` (tranne `caliper-flowise-init`,
già `no`): **non sono stati toccati**, perché l'owner ha nominato solo `flowise`. Se il
progetto `caliper` non deve tornare su del tutto, è una decisione a parte.

### Addendum 2026-09-01 ~10:15Z — controllo in corsa: VRAM a 9 MiB, e cosa c'è sotto

Controllo richiesto dall'owner dopo aver visto `nvidia-smi` a **9 MiB / 10 MiB,
«No running processes found»** contro i **362 MiB** stazionari dei soak del 27-28/08.
Solo letture: lo stack non è stato toccato e il soak non è stato interrotto.

**Il flusso è vivo e non perde.** Su 991 campioni (16:44:39Z → 10:10:21Z, 17 h 26 min):

| | primo | ultimo | delta |
|---|---|---|---|
| `orders` | 55 881 | 65 463+ | **+9 582** |
| `sensor_readings` | 55 775 | 65 419+ | **+9 644** |
| `qdrant.points_count` | 37 903 | 57 130+ | **+19 227** |

DB **+19 226** contro Qdrant **+19 227**: coincidono a meno di uno. Il divario
`db − qdrant` resta **73 752 ±2 per tutti i 991 campioni** — è l'offset storico
(righe che precedono il corpus), non una perdita che si accumula. Nessun contatore
ha smesso di crescere. **Non siamo nel caso FAIL di §4.3.1(a).**

**La VRAM a 9 MiB non ha nessuna delle due spiegazioni benigne attese.** `ollama ps`:

```
NAME                    SIZE    PROCESSOR    UNTIL
granite-embedding:30m   66 MB   100% CPU     4 minutes from now
```

Il modello **è caricato** — quindi non è `keep_alive` scaduto né ricarica a ogni
chiamata. Gira **100% CPU**. È l'anomalia già aperta il 30/08 in `CLAUDE.md`
(«Ollama gira 100% CPU dal riavvio del 30/08»), che **sopravvive a un avvio a freddo
con `--gpu`** e a un container che vede entrambe le schede (verificato al lancio con
`nvidia-smi -L` dentro il container).

**Conseguenza da non perdere: i numeri VRAM di questo run non servono a dimensionare
le schede.** Confronto sui campioni, con le finestre dichiarate:

| | VRAM mediana | campioni > 100 MiB | ollama RSS mediana |
|---|---|---|---|
| **prima** — soak #2, 420 campioni, 7,4 h | **362,0 MiB** | **420 / 420** | 686,1 MiB |
| **dopo** — questo run, 991 campioni, 17,4 h | **19,0 MiB** (9+10 a vuoto) | **22 / 991** (max 1 312) | 507,2 MiB |

Il "prima" aveva l'embedding **residente in GPU** per l'intero run; il "dopo" lo ha in
CPU. **È una seconda variabile cambiata fra prima e dopo**, non voluta, e §4.3.2 dice
che un confronto ne varia una sola: va dichiarata in testa al report. Non invalida (a),
(b), (c) — che non passano dalla GPU — ma tocca (d), perché `ollama` è il servizio
esente il cui RSS va riportato a parte, e qui è **più basso** in CPU (507 contro 686),
non più alto.

**Due picchi di carico, e 250 fallimenti che non hanno prodotto perdita.**
`docker logs -t` sull'agent: **1 solo** fallimento alle 16:23:14Z (warm-up, prima del
lancio, ed è l'unico con la firma di Ollama —
`HTTPConnectionPool(host='ollama'...) Read timed out (read timeout=30)`), poi
**niente per ~16 ore**, poi **250 fallimenti** tutti con testo **`timed out` nudo**,
in due raffiche che coincidono esattamente con due picchi di `load1`:

```
08:30:27Z load1=2.25   08:35:40Z load1=30.27   08:39:49Z load1=6.25
08:48:09Z load1=4.82   08:52:18Z load1=27.92   08:55:26Z load1=10.51
```

Nella finestra 08:20Z → 10:10Z: **db +2058, qdrant +2058, differenza esattamente 0.**
Se i 250 eventi fossero stati persi mancherebbe il 12% del corpus. Non manca.

**Il meccanismo non è stabilito, e non lo deduco.** Il codice è A-4 alla lettera —
`except Exception as e: print("embedding/upsert failed:", e)`, nessun retry, nessuna
coda — e il consumer **non ha `group_id`** (`auto_offset_reset="latest"`), quindi non
committa offset e **non c'è redelivery**: un messaggio fallito è perso davvero. Due
candidati, nessuno provato:

1. **Timeout lato client su scritture che sono comunque atterrate.** Il testo `timed
   out` nudo è la firma del client Qdrant (`QdrantClient(url=...)`, senza timeout
   esplicito), diversa da quella di Ollama vista alle 16:23. Sotto `load1` a 30 il
   client rinuncia ad aspettare mentre il server scrive. Spiegherebbe zero perdita e
   250 righe di errore. **È l'ipotesi che preferisco**, per la firma dell'eccezione.
2. **I messaggi falliti non corrispondono a righe di tabella** (metadati Debezium che
   cadono nel `TOPIC_PATTERN`): perderli non allargherebbe il divario.

Discriminarli è una lettura, non un esperimento: basta correlare gli offset Kafka dei
fallimenti con gli id `uuid5` presenti in Qdrant. **Va fatto prima del verdetto**,
perché decide se il check (c) può dire «zero eventi persi» o soltanto «zero righe di
tabella mancanti».

**L'origine dei due picchi di `load1` a 30 su 32 thread non è spiegata.** Il progetto
`caliper` era fermo e nessun container estraneo girava. Da annotare, non da dedurre.

**Difetto nei dati del "prima", da conoscere prima di rileggerli.** Il soak #2 ha
**12 campioni su 420** in cui `containers` non contiene i 19 servizi ma la sola chiave
`_error: "docker: timed out after 30s"`. Sommandoli ingenuamente danno **RSS totale 0**
— infatti il minimo della serie risulta `0.0 MiB`. Chi calcola minimo o media sulla
serie del "prima" ottiene un numero sbagliato: **un campione fallito si legge come
consumo bassissimo invece che come misura assente.** È la stessa famiglia della lezione
di §5 sul campo derivato che deve distinguere «falso» da «non l'ho potuto sapere», e
la stessa forma del corollario di §4.3.1 («un tetto troppo stretto si legge come poco
consumo»). I campioni `_error` vanno **esclusi**, non sommati.
