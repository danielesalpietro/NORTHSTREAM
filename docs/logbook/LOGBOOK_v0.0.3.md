# LOGBOOK — Fase 2: Stack onesto sulle risorse (v0.0.3)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata al 2026-08-28, finestra ENV-W in corso

**Dove siamo**: #22, #21 e #44 implementati e validati **staticamente** (nessuna
delle sessioni che li ha scritti aveva Docker o GPU); **nessuno dei tre è ancora
verificato a runtime**, ed è esattamente ciò che la finestra ENV-W aperta fino
alle ~22:00Z del 28/08 deve chiudere, nell'ordine T0.7 → #44 → T-PROF → soak #2
(ordine dettato dall'interferenza: #44 occupa VRAM di proposito e T-PROF cambia
la composizione dello stack, quindi entrambe contaminerebbero la serie del soak
se eseguite mentre gira). Base: tag `v0.0.2` → `966422d` (annotato), `develop`
allineato col merge `cfc98f3`. La Fase 1 ha chiuso P-1 nel comportamento (T0.6
PASS con modelli veri) e la famiglia P-11/P-12/P-13; il suo esito distillato è in
`docs/logbook/SINTESI_fasi_chiuse.md`.

**Il numero che la fase ha già prodotto**: il soak parziale
`20260827-1406-envw-c6b56d3` (427 campioni contigui su 7,39 h, archiviato con
checksum) è il **"prima" di P-5** — RSS mediana 14 174 → picco 15 985 MiB, di cui
**Trino da solo 4 109 → 7 119 MiB (+73%)**, mentre Elasticsearch (`-Xmx1g` fisso)
e Kafka restano piatti. È la prova diretta che il finding P-5 è una JVM senza
tetto, e nessuna suite che parte e chiude in quindici minuti avrebbe potuto
vederla. Il run ha anche mostrato che il piano non dichiarava le soglie di (b) e
(d) del soak: scritte ora in `docs/piano_ricovero.md` §4.3.1, ancorate ai numeri
misurati.

**Scope della fase** (`docs/piano_ricovero.md` §6, riga v0.0.3 — obiettivo O4):
smettere di mentire sulle risorse. Issue di fase
[#5](https://github.com/danielesalpietro/NORTHSTREAM/issues/5).

| Sub-issue | Contenuto | Finding | Stato |
|---|---|---|---|
| [#22](https://github.com/danielesalpietro/NORTHSTREAM/issues/22) | `trino/catalog/postgresql.properties` + configurazione memoria Trino | **P-2** | Implementato, verificato solo staticamente |
| [#21](https://github.com/danielesalpietro/NORTHSTREAM/issues/21) | Compose profiles `core`/`lakehouse`/`governance` + `mem_limit` per servizio | **P-5** | Implementato, verificato solo staticamente |
| [#23](https://github.com/danielesalpietro/NORTHSTREAM/issues/23) | Tier hardware riscritti sui numeri misurati + **T-PROF** | §4.2/4.3 review | Non iniziato (ENV-L, altra sessione) |
| [#44](https://github.com/danielesalpietro/NORTHSTREAM/issues/44) | Esclusività dell'host: pre-check, run-check, post-run nel `manifest.json` | — (nato dalla Fase 1) | Implementato, verificato solo staticamente/con `nvidia-smi`/`docker` simulati |
| [#24](https://github.com/danielesalpietro/NORTHSTREAM/issues/24) | Release v0.0.3: gate, CHANGELOG, tag | — | Non iniziato |

**Decisioni prese, con il perché**
- **Catalogo chiamato `postgresql.properties`, non `postgres.properties`**:
  il test T0.7 (scritto prima di questa sessione) e la tabella del piano
  §4.1 puntano entrambi su `postgresql.public.orders` — il nome del file
  Trino fissa il nome del catalogo. La review §4.2 lo chiama "postgres.properties"
  di sfuggita, ma non è il contratto vincolante; il test lo è. Rinominare
  avrebbe fatto fallire T0.7 in silenzio.
- **Heap Trino fisso (`-Xms1G -Xmx2G`) al posto del default `MaxRAMPercentage=80`**:
  senza un `mem_limit` di container quel default dimensiona l'heap sull'80%
  della RAM **dell'host**, non del laptop — è esattamente il comportamento
  che P-5 denuncia. Fissarlo nello stile già usato per Elasticsearch
  (`-Xmx1g`) risolve il problema anche prima che #21 introduca `mem_limit`,
  e resta corretto dopo. **Dichiarato come stima**, non misura: nessun run
  reale lo ha ancora esercitato.
- **`schema-registry` (Apicurio) in `lakehouse`, non in `core`, con la
  dipendenza forte di `kafka-ui` rimossa**: la review lo classifica
  scenografia (Debezium gira con `schemas.enable=false`, nessuno schema è
  mai registrato). Tenerlo comunque in `core` solo per non rompere
  `kafka-ui` avrebbe vanificato lo scopo di P-5. La `KAFKA_CLUSTERS_0_SCHEMAREGISTRY`
  resta configurata: kafka-ui mostra quel pannello vuoto se Apicurio non
  gira, non si rifiuta di avviarsi. *Alternativa scartata*: spostare
  `kafka-ui` fuori da `core` — ma la review (§4.3b) lo elenca esplicitamente
  nel profilo sempre-attivo.
- **`start-addon.sh`/`.ps1` di default avviano tutti e tre i profili**, non
  solo `core`: senza questo cambio, l'introduzione dei profili avrebbe
  silenziosamente ridotto lo stack che `ci-nightly` avvia (via `--gpu`, non
  `--profile`) da 19-21 container a 11, facendo sparire Trino dalla suite
  `full` proprio mentre T0.7 dovrebbe iniziare a passarci. Regola CLAUDE.md
  §5/piano rispettata: comportamento di default dichiarato esplicitamente,
  non lasciato a un effetto collaterale. Nuovo flag opt-in `--profile
  <nome>[,<nome>]` per chi vuole lo stack snello.
- **`mem_limit` dichiarati come stime, non misure**, tranne due: Trino
  (2560m, margine sopra l'heap fisso di 2G appena scritto) ed Elasticsearch
  (1536m, margine sopra `-Xmx1g` preesistente) sono ancorati a un valore
  reale già nel compose, non a una sensazione. Gli altri 18 derivano dal
  profilo tipico della tecnologia per un carico da laboratorio. `debezium-connect`
  ha margine maggiore (1536m) degli altri singoli servizi JVM (1024m)
  perché è l'unico esercitato sotto carico CDC reale a ogni push di
  `ci-smoke`: una stima troppo stretta lì si manifesta come OOM-kill
  silenzioso, non come errore leggibile — rischio che gli altri servizi non
  hanno nello stesso grado. **Ollama deliberatamente senza `mem_limit`**:
  il fabbisogno dipende dal modello/tier scelto (350m→32b), un tetto fisso
  romperebbe un tier o sarebbe inutile per un altro — decisione per-tier
  rimandata a #23 su numeri misurati.
- **T0.7 non promosso nella suite `ci`** (a differenza di T0.6 in v0.0.2):
  `ci-smoke` avvia un sottoinsieme di servizi nominati esplicitamente che
  **esclude Trino di proposito** (commento nel workflow: tenere Elasticsearch/
  OpenMetadata/Flink/Trino fuori da un runner da 16 GB). Promuovere T0.7 in
  `SUITE_CI` senza avviare anche Trino in `ci-smoke` lo farebbe SKIPpare per
  sempre — suite membership decorativa, non un segnale reale, la lezione
  opposta a quella di T0.6. Aggiungere Trino a `ci-smoke` è ora più
  sostenibile in RAM grazie all'heap fisso da 2G, ma resta una decisione
  aperta perché richiede anche coprire la dipendenza `minio` e Trino non ha
  ancora un healthcheck (P-8) — **rimandata**, non fatta di nascosto dentro
  #21/#22. T0.7 gira comunque nelle suite `core` e `full`.
- **`expected/current.json` non toccato**: T0.7 resta `XFAIL` finché non è
  misurato su Docker reale (ENV-L o nightly ENV-W), stessa disciplina già
  seguita per T0.6 in v0.0.2 — il file non si piega al codice scritto, solo
  al comportamento osservato.
- **#44 — attribuzione dei processi GPU per container (cgroup), non per
  soglia di memoria**: distingue il nostro stesso Ollama a modello caricato
  da un tenant vast.ai, cosa che una soglia unica di VRAM usata non può
  fare (il piano stesso esce da questa ambiguità solo dichiarando VRAM
  *libera contro quella richiesta*, non un tetto assoluto). `unknown` è
  distinto sia da `exclusive` sia da `shared` in ogni ramo in cui l'host
  non può essere letto (niente `nvidia-smi`, niente `docker`): un host
  senza GPU non diventa mai "shared" per costruzione.
- **RAM/load average solo descrittivi nel pre-check**, mai un gate con
  soglia inventata: il piano dichiara un requisito verificabile solo per la
  VRAM (`--require-vram-mib`); un `--require-ram-mib` esiste ma è
  **dichiarato dal chiamante**, mai un default derivato da `--tier` — un
  numero che nessuno ha scelto sarebbe la stessa costante travestita da
  misura di cui parla CLAUDE.md §5.
- **Campionamento del run-check fra un test e l'altro, non un timer in
  background**: per una suite T0 (~15 minuti, 12-14 test), un campione per
  test è granularità sufficiente e non introduce un processo indipendente
  da terminare a fine suite — il vincolo "non deve mai uccidere il run" vale
  a maggior ragione se il campionatore stesso non è un processo separato.

**Verificato in questa sessione (nessun demone Docker disponibile)**
- `docker compose config -q` verde su tutte e tre le combinazioni (base,
  base+addon, base+addon+gpu) e su tutte le combinazioni di profilo
  (nessuno, `core`, `core+lakehouse+governance`).
- `docker compose --profile core config --services` → esattamente gli 11
  servizi attesi (landing-page, kafka, kafka-ui, postgres, adminer,
  debezium-connect, ollama, open-webui, qdrant, stream-agent, data-generator);
  senza `--profile` (default) → **gli stessi 11**, non i 19-21 di prima —
  è il cambiamento di comportamento voluto da P-5, isolato dal comportamento
  di `start-addon.sh` (che invece resta invariato di default, v. sopra).
  Con tutti e tre i profili → i 21 servizi di sempre (invariato).
- `bench/t0/run.sh --suite static` → 3 PASS, nessuna regressione, prima e
  dopo ogni modifica.
- `yamllint -c .yamllint.yml` sui due file compose modificati: un solo
  warning, **preesistente** (riga lunga sul digest immagine MinIO, già
  presente prima di questa sessione — confermato con `git stash`), nessun
  warning nuovo introdotto.
- **Non verificato, e non verificabile da questa sessione**: che lo stack
  parta davvero sotto i nuovi `mem_limit` senza OOM-kill, che T0.7 flippi a
  PASS, che il profilo `core` resti sotto i 14 GB di T-PROF. Serve un run
  reale — `bench/t0/run.sh --suite core` (o `full`) su ENV-L, oppure la
  prossima `ci-smoke`/nightly.
- **#44 — 22/22 asserzioni PASS** su un test dedicato (monkeypatch di
  `subprocess.run`, non committato) contro tutti i rami di
  `bench/lib/gpu_exclusivity.py`: nessuna GPU, host pulito, tenant estraneo,
  `--query-compute-apps` che fallisce (pulito/non pulito), `docker` assente
  (con/senza processi), output malformato, processo nostro, mix nostro+estraneo.
  `preflight.sh --gpu` verificato con `nvidia-smi`/`docker` simulati:
  FAIL con causa/sintomo/rimedio su contesa dichiarata, WARN forzato con
  `--allow-contention`, OK quando il margine libero copre il requisito
  dichiarato. `bench/t0/run.sh` verificato a produrre `manifest.json.exclusivity`
  con `declared`/`detected` distinti quando i due divergono.

**Gate di chiusura**: tutti i PASS di v0.0.2 restano PASS — in particolare T0.6,
T0.2 e T0.3, misurati con modelli veri — CI verde, e nessun nuovo XFAIL non
dichiarato.

**Ereditato dalla Fase 1, chiuso da questa fase**
- **#44 era già iniziato su `feature/soak-harness`** (`fe91a74`, `cdde3a7`,
  non mergiato, solo letto): `--exclusivity` dichiarato e le condizioni
  iniziali del soak (connettore, slot di replica) restano lì per quell'harness.
  La classificazione **automatica** exclusive/shared che mancava — dichiarata
  esplicitamente fuori scope in `fe91a74` — è ora in `bench/lib/gpu_exclusivity.py`,
  usata da `preflight.sh`/`.ps1` (pre-check) e `bench/t0/run.sh` (run-check +
  post-run). Non portata nel soak stesso: resta lavoro futuro per quando
  `feature/soak-harness` confluirà in una release (v0.0.4, T-SOAK-24h).
- **ENV-W ha due stati** (manutenzione / noleggio vast.ai) e le finestre GPU si
  prenotano con anticipo: piano §2.1. Prima di una finestra prenotata, prova a
  secco dello stesso comando.
- **`RUN_NIGHTLY` resta spenta**: #44 è chiuso lato codice ma non lato DoD
  finché la verifica a tre stati non gira su ENV-W (v. sotto); l'altro
  prerequisito resta #47 (Fase 3).

**Numeri misurati**: nessuno nuovo in questa fase — il metro resta
`docs/runs/20260826-2053-envw-5eb456a-baseline.md`, più i run di v0.0.2 elencati
nell'ESITO FASE 1. I `mem_limit` di questa entry sono stime dichiarate, non
misure (v. sopra); i risultati di #44 sono verifiche di logica simulata, non
misure su hardware reale (v. sopra).

**Prossimo passo**: (a) eseguire `bench/t0/run.sh --suite core` (o `full`) su
un ambiente con Docker reale (ENV-L, o la prossima nightly ENV-W) per far
flippare T0.7 e aggiornare `expected/current.json`, e per osservare se
qualche `mem_limit` stimato è troppo stretto; (b) verificare #44 su ENV-W col
protocollo a tre stati (macchina libera → passa; contesa deliberata → fallisce
con causa/sintomo/rimedio; risanata → passa), stesso protocollo già usato per
P-11 in v0.0.2 — **richiesto all'owner**, non eseguibile da una sessione
remota senza Docker/GPU. Poi #23 (tier misurati + T-PROF, ENV-L) e #24
(release v0.0.3: gate, CHANGELOG, tag).

---

## 2026-08-27 — remota, nessun demone Docker — sessione operativa C (Fase 2)

- **Obiettivo della sessione**: #22 (catalogo Trino + memoria, P-2, T0.7) e
  #21 (compose profiles + `mem_limit`, P-5), in quest'ordine, su
  `release/v0.0.3`.
- **Fatto** (commit `c471707`, dopo rebase su `199fd8d`/sessione D — SHA annotato a push avvenuto, come da regola su branch condiviso):
  - `trino/catalog/postgresql.properties`: catalogo JDBC verso
    `postgres:5432/sales`. Nome file `postgresql.properties`, non
    `postgres.properties`: T0.7 e il piano §4.1 fissano il nome del
    catalogo su `postgresql.public.orders`.
  - `trino/etc/jvm.config`: heap fisso `-Xms1G -Xmx2G` al posto del
    `MaxRAMPercentage=80` di default dell'immagine, montato su
    `/etc/trino/jvm.config` (nuovo volume nel servizio `trino`).
  - `docker-compose-northstream-ai.yml`, `docker-compose.addon.yml`:
    `mem_limit` su 20/21 servizi (Ollama escluso di proposito, v. sotto);
    profili `lakehouse` (flink-jobmanager, flink-taskmanager, minio,
    create-minio-bucket, trino, schema-registry) e `governance`
    (openmetadata-db, elasticsearch, execute-migrate-all, openmetadata);
    `core` = nessun tag (landing-page, kafka, kafka-ui, postgres, adminer,
    debezium-connect, ollama, open-webui + l'addon).
  - Rimossa la dipendenza forte `kafka-ui → schema-registry` (bloccava
    `--profile core` da solo: "depends on undefined service"), scoperta
    durante la validazione statica, non nella specifica originale.
  - `start-addon.sh` / `start-addon.ps1`: default a tutti e tre i profili
    (comportamento invariato), nuovo flag opt-in `--profile`/`-Profile`.
  - `CHANGELOG.md`: voce `[Unreleased]` per #22 e #21.
- **Decisioni prese**: v. SINTESI DI FASE sopra, aggiornata da questa stessa
  sessione — non duplicate qui per evitare la stessa lezione della Fase 0
  (compressione quasi gratuita se la sintesi resta viva a ogni sessione).
- **Test eseguiti**:
  - `docker compose config -q` → PASS su base, base+addon, base+addon+gpu,
    e su tutte le combinazioni di profilo (nessuno / `core` / tutti e tre).
  - `docker compose --profile core config --services` e la variante senza
    flag → entrambe i soli 11 servizi attesi; con tutti e tre i profili →
    i 21 di sempre.
  - `bench/t0/run.sh --suite static` → 3 PASS (T0.1, T0.12, T-REPRO),
    eseguito prima e dopo le modifiche, nessuna regressione.
  - `yamllint -c .yamllint.yml` sui due compose modificati → un solo
    warning, verificato preesistente con `git stash` (riga lunga sul
    digest MinIO, non introdotta da questa sessione).
  - **Non eseguiti, dichiarato esplicitamente** (nessun demone Docker in
    questa sessione): `docker compose up` reale, T0.7 end-to-end, T-PROF,
    qualunque verifica che i nuovi `mem_limit` non causino OOM-kill.
- **Costo della sessione**: `claude-sonnet-5`, sessione remota cloud
  (`session_01Np7X8P4C4cUQAikUz4FDHP`). `get_session` non espone un campo
  `usage`/token per questa sessione in questo momento — costo non
  misurabile da qui, non stimato (CLAUDE.md §5: un campo assente si nota,
  non si finge una misura).
- **Non funziona / sospeso**: T0.7 non promosso nella suite `ci` — motivato
  sopra (Trino escluso di proposito da `ci-smoke` per RAM del runner;
  promuoverlo senza avviare Trino lì lo farebbe SKIPpare per sempre, non è
  un segnale reale). Resta nelle suite `core`/`full`.
- **Prossimo passo per la sessione successiva**: eseguire
  `bench/t0/run.sh --suite core` (o `full`) su Docker reale — ENV-L, o la
  prossima nightly `ci-nightly` su ENV-W — per far flippare T0.7 in
  `expected/current.json` e per scoprire se un `mem_limit` stimato è troppo
  stretto.
- **Decisioni richieste all'owner**: nessuna bloccante. Segnalazione per
  quando qualcuno guarda #23: se le misure ENV-L mostrano che aggiungere
  Trino a `ci-smoke` è ora sostenibile in RAM (grazie all'heap fisso a 2G),
  vale la pena riconsiderare la promozione di T0.7 in `SUITE_CI` — oggi
  bloccata solo dall'assenza di un healthcheck Trino (P-8) e dalla
  dipendenza `minio` non ancora avviata lì.

---

## 2026-08-27 — remota, nessun Docker né GPU — sessione operativa D (Fase 2)

- **Obiettivo della sessione**: #44 — esclusività dell'host: pre-check,
  run-check, post-run, su `release/v0.0.3`.
- **Onboarding**: CLAUDE.md, `docs/piano_ricovero.md` (§2, §2.1, §3, §6 riga
  v0.0.3), `docs/logbook/SINTESI_fasi_chiuse.md`, testa + ultima entry di
  questo file, `CHANGELOG.md` `[Unreleased]`, i due run indicati
  (`20260827-1115-envw-c424928-vram32b.md`, `20260827-1148-envw-6b377a3.md`),
  issue #44 per intero (testo + DoD). Letto anche `fe91a74`/`cdde3a7` su
  `feature/soak-harness` (non mergiato, solo letto, come richiesto) per non
  riscrivere il lavoro della sessione A: `--exclusivity` dichiarato,
  `sample.py --mode init`, e il riepilogo min/max GPU per-campione in
  `verdict.py` erano già lì per il soak — mancava solo, per costruzione
  (dichiarato esplicitamente nel messaggio di `fe91a74`), la classificazione
  **automatica** exclusive/shared, che è esattamente lo scope di questa
  sessione.
- **Fatto** (commit `3232e38`, dopo rebase su `60929e8`/sessione C — SHA
  annotato a push avvenuto, come da regola su branch condiviso):
  - **`bench/lib/gpu_exclusivity.py`** (nuovo, condiviso fra preflight e
    run.sh): risponde "la GPU è tutta nostra in questo momento?" —
    `nvidia-smi --query-compute-apps` per i processi di calcolo, attribuiti
    a un container di questo compose project via match dell'id a 64 esadecimali
    in `/proc/<pid>/cgroup` contro `docker ps --no-trunc --filter
    label=com.docker.compose.project=...`. Un processo non attribuibile
    (pid irraggiungibile, o cgroup senza match) è **foreign**, mai ignorato
    né assunto "nostro". Stato `exclusive`/`shared`/`unknown` — mai un
    booleano: `unknown` quando `nvidia-smi` non c'è (host senza GPU: "non
    applicabile", non contesa) o quando l'attribuzione non è possibile
    (Docker irraggiungibile) e l'uso misurato non è al livello base pulito;
    solo in quel caso "pulito" (≤ 64 MiB, il margine oltre i 9 MiB misurati
    nei due run di riferimento) lo stato resta `exclusive` anche senza poter
    attribuire nulla, perché non c'è nulla da attribuire.
  - **Pre-check**: `preflight.sh --gpu` guadagna `--require-vram-mib N`,
    `--require-ram-mib N` (dichiarati da chi lancia, mai inferiti da
    `--tier`: un default fabbricato sarebbe un numero che nessuno ha
    dichiarato) e `--allow-contention` (bypass esplicito, sempre loggato
    come WARN, mai silenzioso). RAM libera (`MemAvailable`, non solo il
    totale già controllato) e load average (solo descrittivo — nessuna
    soglia dichiarata nel piano per "questo load average è contesa": inventarne
    una sarebbe la stessa costante travestita da misura di cui parla
    CLAUDE.md §5). `preflight.ps1` replica gli stessi flag ma **senza
    attribuzione per container** (Docker Desktop gira nella propria VM
    WSL2, invisibile da un processo host): dichiarato esplicitamente nel
    commento, non finto — coerente con "mai collaudato su Windows" già in
    CLAUDE.md §2.
  - **Run-check**: `bench/t0/run.sh` guadagna `--exclusivity
    exclusive|shared|unknown` (default `unknown`, stessa disciplina del
    soak) e campiona GPU + RAM disponibile **fra un test e l'altro** (12-14
    campioni per la suite `full`, più uno finale) — mai un demone in
    background: un campionatore che gira nel corpo del loop non può mai
    uccidere la suite che misura, a differenza di un timer indipendente.
  - **Post-run**: `manifest.json.exclusivity` — `declared` (l'operatore) e
    `detected` (i campioni), **mai fusi**: un operatore che dichiara
    `exclusive` su un host che i campioni mostrano `shared` è esattamente
    il disaccordo che va preservato, non risolto a favore di uno dei due.
    Più `gpu_free_mib`/`gpu_foreign_used_mib`/`ram_available_mib` (min/max)
    e `contention_first_seen` (test id + timestamp del primo campione
    `shared`). Riga corrispondente aggiunta a `summary.md`.
  - **`docs/piano_ricovero.md`** riga ENV-W: la frase "finché il controllo
    automatico di #44 non è in piedi" sostituita con il comando reale, come
    richiesto dalla DoD dell'issue.
  - **Cinque report** in `docs/runs/` privi del campo (tre ENV-W precedenti
    alla release, due `ci-smoke` GitHub-hosted dove il concetto GPU non si
    applica nello stesso modo) **annotati** con `unknown` in coda al file —
    non riscritti, per la stessa disciplina di CLAUDE.md §4 sui logbook.
  - `CHANGELOG.md`: voce `[Unreleased]` per #44.
- **Decisioni prese** (e perché — alternative scartate):
  - **Attribuzione per cgroup, non per soglia di memoria**: la prima idea
    (qualunque uso GPU sopra un certo numero è "shared") non distingue il
    nostro stesso Ollama che ha caricato un modello dal tenant vast.ai — un
    falso "shared" ogni volta che lo stack gira col profilo GPU. L'attribuzione
    per container rende il run-check utilizzabile *mentre* il nostro stack
    usa la GPU, non solo prima che parta — motivo per cui il pre-check (dove
    nulla di nostro dovrebbe già essere sulla GPU) è più semplice del
    run-check e non ne ha bisogno per la sua stessa correttezza, ma la
    condivide comunque per un'unica implementazione testata.
  - **RAM/load average solo descrittivi in preflight, mai un gate
    fabbricato**: il piano non dichiara da nessuna parte quale load average
    o quale frazione di RAM mancante significhi "macchina condivisa" — solo
    la VRAM ha un requisito dichiarabile in modo esplicito
    (`--require-vram-mib`). Inventare una soglia per RAM/load avrebbe
    prodotto esattamente l'errore che CLAUDE.md §5 vieta (una costante
    travestita da misura), nello stesso modo in cui `verdict.py` del soak
    dichiara `UNKNOWN` invece di inventare le soglie di Qdrant/RSS che il
    piano non fissa. *Deciso comunque* un `--require-ram-mib` **dichiarabile**
    dal chiamante (mai un default implicito), per lo stesso motivo di
    `--require-vram-mib`: un numero che l'operatore sceglie non è una
    costante fabbricata da questo script.
  - **Campionamento fra i test, non un timer in background**, per il
    run-check di `bench/t0/run.sh`: la suite `full` impiega ~12-15 minuti in
    12-14 test sequenziali (run di riferimento v0.0.2), granularità
    sufficiente per individuare quando compare un tenant, a costo di
    implementazione e di rischio (nessun processo indipendente da
    terminare a fine suite) molto più bassi di un vero campionatore
    periodico come quello del soak (che ha invece bisogno del timer perché
    gira per 24 ore, non 15 minuti). *Alternativa scartata*: riusare
    `bench/soak/lib/sample.py` con un timer — scartata per la suite T0
    perché introdurrebbe un processo di background da avviare/fermare
    attorno a un run che oggi non ne ha bisogno.
  - **`bench/lib/` nuovo, non dentro `bench/t0/lib/` o `bench/soak/lib/`**:
    `gpu_exclusivity.py` serve sia a `preflight.sh` (fuori da `bench/t0/`)
    sia a `bench/t0/run.sh`; metterlo sotto `bench/t0/lib/` avrebbe reso
    innaturale l'uso da `preflight.sh` alla radice del repo.
  - **Non toccato `feature/soak-harness`**: l'istruzione era di leggerlo,
    non fonderlo; la classificazione automatica costruita qui vive nel
    codice di questa release (`bench/lib/`, `preflight.*`, `bench/t0/run.sh`)
    e resta disponibile a chi porterà lo stesso schema nel soak quando
    quell'harness confluirà in una release.
- **Test eseguiti**:
  - **Nessun demone Docker né GPU in questa sessione** (dichiarato secondo
    CLAUDE.md §5): tutti i test sono statici o con `nvidia-smi`/`docker`
    simulati.
  - `python3 /tmp/.../test_gpu_exclusivity.py` (script di test dedicato,
    non committato — monkeypatcha `subprocess.run` e l'attribuzione per
    pid): **22/22 asserzioni PASS**, tutti i rami di `snapshot()` — nessun
    `nvidia-smi`, host pulito, tenant estraneo, `--query-compute-apps` che
    fallisce (pulito e non pulito), `docker` assente (con e senza processi),
    output `nvidia-smi` malformato, processo attribuito al nostro
    container, mix di un processo nostro e uno estraneo.
  - `bash -n preflight.sh`, `bash -n bench/t0/run.sh` → puliti.
  - `ruff check bench/ stream-agent/ data-generator/` → puliti
    (`bench/lib/gpu_exclusivity.py` incluso).
  - `preflight.sh --gpu` con `nvidia-smi`/`docker` reali della sandbox
    (assenti) → `GPU exclusivity (#44): could not be determined` (unknown,
    non shared) — corretto: non è contesa, è "non applicabile".
  - `preflight.sh --gpu` con `nvidia-smi`/`docker` simulati (18000/24576 MiB,
    un processo pid non attribuibile) → `shared`; con `--require-vram-mib
    19000` → **FAIL** con causa/sintomo/rimedio; con l'aggiunta di
    `--allow-contention` → **WARN**, forzato, mai silenzioso; con
    `--require-vram-mib 5000` (che ci sta nei 6576 liberi) → WARN
    informativo, non FAIL. `--require-ram-mib` verificato allo stesso modo
    (FAIL / WARN forzato / OK a seconda della soglia dichiarata).
  - `bench/t0/run.sh --suite static` → 3 PASS invariati, prima e dopo,
    `manifest.json.exclusivity` presente con `detected: "unknown"` (nessun
    GPU/docker reali) e `ram_available_mib` popolato.
  - `bench/t0/run.sh --suite static --exclusivity exclusive` con
    `nvidia-smi`/`docker` simulati (contesa) → `declared: "exclusive"`,
    `detected: "shared"` — **i due valori restano distinti nel manifest**,
    la verifica che contava di più.
  - `bench/t0/run.sh --suite ci` (nessun container in questa sandbox) → 1
    PASS + 6 SKIP (containers not running — limite dell'ambiente, non
    regressione), `manifest.json.exclusivity` presente e coerente.
  - `bench/t0/run.sh --only T0.12` dopo l'annotazione dei cinque report →
    ancora PASS (il linter di verità documentale non si rompe).
  - Rebase pulito su `60929e8` (sessione C, #22/#21): nessun file in comune,
    nessun conflitto.
- **Verifica reale, dichiarata come non eseguibile da questa sessione**: i
  tre stati del pre-check (macchina libera → passa; contesa deliberata →
  fallisce con causa/sintomo/rimedio; risanata → passa) vanno riprodotti su
  ENV-W con `nvidia-smi`/Docker veri, stesso protocollo già usato per P-11 in
  v0.0.2. Richiesta all'owner, non eseguibile da qui.
- **Costo della sessione**: `claude-sonnet-5`, sessione cloud
  (`session_01HVaaYgFTssQc54oiojLzqQ`). `get_session` non espone un campo
  `usage`/token in questa chiamata — costo non misurabile da qui, non
  stimato (stesso limite già osservato dalla sessione C in questa fase).
- **Non funziona / sospeso**: nulla di bloccante. Il run-check di
  `bench/soak/run.sh` (24h) non è stato toccato — resta il campionamento
  periodico via timer già presente su `feature/soak-harness`, senza la
  classificazione automatica costruita qui; portarla nel soak è lavoro
  futuro, non richiesto da questa sessione.
- **Prossimo passo per la sessione successiva**: verifica reale su ENV-W
  (protocollo a tre stati sopra); poi #23 (tier misurati + T-PROF, ENV-L) e
  #24 (release v0.0.3: gate, CHANGELOG, tag) possono procedere — #44 è
  chiuso lato codice, resta la verifica su hardware reale come condizione
  per considerarlo chiuso lato DoD.
- **Decisioni richieste all'owner**: nessuna bloccante. Quando si pianifica
  la prossima finestra ENV-W (§2.1), includere la verifica a tre stati di
  #44 insieme a quanto già in coda (T0.7 end-to-end, i `mem_limit` di #21).

---

## 2026-08-28 — supervisione (sessione cloud) — soglie soak, §2, e la lezione dell'interruzione

- **Obiettivo della sessione**: rimettere in moto la finestra ENV-W dopo la
  sospensione per esaurimento crediti, e chiudere il buco che il primo soak ha
  reso visibile — due verdetti UNKNOWN su soglie che il piano non dichiarava.

- **Fatto**:
  - `docs/piano_ricovero.md` **§4.3.1** — scritte le soglie di (b) *replication
    slot* e (d) *RSS totale*, mancanti dal piano e causa dei due UNKNOWN del
    primo soak. Sono ancorate ai numeri misurati, non scelte a sensazione.
  - `docs/piano_ricovero.md` **§4.3.2** — regola metodologica: un confronto
    prima/dopo varia una cosa sola.
  - `CLAUDE.md` §2 — righe *Ultimo run T0*, *Prossima azione*, *Finestra ENV-W*,
    *Sessioni operative attive*, *Blocchi aperti* riallineate. La sessione ENV-W
    aveva giustamente **rifiutato** di aggiornare §2 dal proprio branch, indietro
    di 42 righe: scriverci sopra avrebbe creato una divergenza peggiore del
    ritardo. L'aggiornamento va fatto da `release/v0.0.3`, ed è questo.

- **Decisioni prese, e perché**
  - **La soglia dello slot è di tendenza, non di dimensione.** Il modo di guasto
    vero non è "lo slot è grosso", è "lo slot ha smesso di avanzare": il WAL si
    accumula finché il disco finisce. Un tetto da solo verrebbe superato troppo
    tardi. Il criterio combina quindi attività (`active` vero in ≥ 99% dei
    campioni, mai 3 consecutivi non-attivi), pendenza (≤ 1 MiB/h sulla seconda
    metà del run) e un tetto di sicurezza a 256 MiB. **Alternativa scartata**:
    un solo tetto assoluto, semplice da scrivere e cieco al caso che conta.
    I 256 MiB stanno tre ordini di grandezza sopra i **0,060 MiB** misurati su
    7,4 ore: intercettano uno slot bloccato molto prima del disco.
  - **Il tetto RSS non è una costante: è la somma dei `mem_limit` dichiarati.**
    Così si aggiorna da solo quando cambia il compose, non richiede di ricordarsi
    di riallineare un numero in un documento, e misura la cosa che interessa —
    se lo stack sta dentro ciò che dichiara di volere. **Alternativa scartata**:
    fissare "≤ 16 GiB per lo stack pieno" a partire dal picco misurato, che
    sarebbe invecchiato al primo servizio aggiunto e avrebbe legittimato il
    consumo attuale invece di misurarlo. Aggiunta la condizione per-servizio
    (nessuno oltre il 90% del proprio tetto per ≥ 10 campioni consecutivi): un
    servizio che vive al 95% non ha ancora fallito, ma è a un picco dall'OOM
    killer, e un verdetto sul solo totale non lo vedrebbe mai.
  - **UNKNOWN è stato l'esito corretto, non una lacuna della sessione ENV-W.**
    Il piano non dichiarava le soglie; inventarne una da riga di comando avrebbe
    prodotto un verde senza referente. Vale la regola di `CLAUDE.md` §5 sul campo
    derivato che deve distinguere "falso" da "non l'ho potuto sapere". La
    correzione va nel piano, non nel run.
  - **Il primo soak resta UNKNOWN su (d) per costruzione** — è stato eseguito su
    uno stack *precedente* ai `mem_limit` di #21, quindi non esisteva un tetto
    contro cui misurarlo. Non è un difetto: è ciò che lo rende il "prima" di P-5.
  - **Ordine dei lavori nella finestra dettato dall'interferenza.** T0.7 → #44 →
    T-PROF → soak #2, in quest'ordine: #44 richiede di occupare VRAM di proposito
    e T-PROF richiede una composizione di stack diversa, quindi eseguirle
    *durante* il soak #2 ne contaminerebbe la serie. Ieri l'ordine non era
    disponibile perché il soak era già in corso quando le altre misure sono
    diventate possibili.
  - **Il soak #2 va lanciato con tutti i profili attivi.** Dopo O4.1 un
    `docker compose up` nudo avvia il solo `core`: un "dopo" lanciato così
    misurerebbe un sistema diverso dal "prima" a 19 container, e la differenza
    sarebbe dominata dai sette container mancanti invece che dai tetti aggiunti.
    Scritto in §4.3.2 perché è un errore che si commette una volta sola e
    invalida silenziosamente il confronto.

- **Test eseguiti**: nessuno da questa sessione — non ha Docker né GPU. Le misure
  citate vengono dal run `20260827-1406-envw-c6b56d3` archiviato dalla sessione
  ENV-W (427 campioni, checksum verificati, `c83bdff` su `feature/soak-harness`).

- **Costo della sessione**: `claude-opus-5`, sessione di supervisione cloud,
  lunga e a contesto compresso più volte — `usage` non riletto a questa entry,
  non stimato.

- **Non funziona / sospeso**: T0.7, #44 e T-PROF restano da eseguire (in corso
  su ENV-W nella finestra fino alle ~22:00Z). `preflight.ps1` mai collaudato su
  Windows. #23 attende ENV-L.

### Lezione di processo: un run lungo deve mettersi al sicuro da solo

L'esaurimento crediti del 27/08 sera ha ucciso la sessione ENV-W mentre il soak
era in corso. Il campionatore era distaccato (PPID 1) e **ha continuato a
lavorare**: al recupero, 427 campioni contigui, `soak.err.log` a zero byte,
nessuna riga persa. La scelta di staccare il processo dalla sessione ha retto
esattamente al guasto per cui era stata fatta.

Ma i dati sono rimasti **non archiviati per circa quindici ore**, in attesa che
qualcuno tornasse a raccoglierli. Se il container fosse stato reclamato, o se
l'owner avesse restituito la macchina al noleggio, sette ore di misura non
riproducibili sarebbero sparite — e sarebbero sparite *dopo* essere state
prodotte correttamente, che è il modo più stupido di perdere un dato.

**Regola che ne segue**: un run lungo archivia da sé al termine — checksum e
copia in `~/NORTHSTREAM-archive/` come ultimo passo dello script, non come primo
passo della sessione successiva. La sessione che torna deve trovare un archivio
già chiuso da verificare, non un file JSONL da mettere in salvo. Da valutare in
`bench/soak/run.sh` prima del T-SOAK-24h di v0.0.4, dove la finestra di
esposizione sarebbe di 24 ore invece di 7.

Corollario minore ma reale: l'intervallo di campionamento effettivo è **62,4 s**,
non 60 — il campionamento stesso costa. I 430 campioni attesi erano una stima; i
427 osservati sono il numero giusto. Un harness che pianifica una durata a
partire dal numero di campioni deve tenerne conto.

- **Prossimo passo per la sessione successiva**: raccogliere da ENV-W gli esiti
  di T0.7, #44 e T-PROF, far flippare T0.7 in `bench/t0/expected/current.json`,
  e portare i numeri di T-PROF nella tabella tier di #23. Poi #24.

- **Decisioni richieste all'owner**: nessuna bloccante. Da sapere: la finestra
  ENV-W corrente scade alle ~22:00Z del 28/08; se il soak #2 parte dopo le
  ~16:00Z servirà o una coda più corta o un'estensione.

---

## Sessione ENV-W (Z8) — 28/08/2026, 12:31–12:55Z — T0.7, #44 a tre stati, suite completa su hardware reale

- **Ruolo**: host di verifica. Unica modifica al repo oltre a report e
  logbook: `bench/t0/expected/current.json`, `T0.7: XFAIL → PASS`.
- **Stack ricreato da zero** (12:31:43→12:34:35Z): quello in esecuzione era
  partito il 27/08 alle 14:06, **prima** dei commit di configurazione di
  v0.0.3 — era il vecchio Trino senza `jvm.config` né `mem_limit`, e
  qualunque misura presa lì avrebbe descritto un sistema che non è quello
  della release. **Teardown senza `-v`**: otto volumi di stato superstiti,
  `ollama_data` compreso (P-10/#42).
- **Tre precondizioni verificate prima di prendere qualunque numero**, perché
  ognuna ha già prodotto una misura falsa: `DeviceRequests` non `null` (GPU
  davvero passata — il 27/08 un `up -d` senza override l'aveva tolta in
  silenzio producendo un falso "100% CPU"); `-Xmx2G` davvero montata in
  `/etc/trino/jvm.config`; `postgresql.properties` davvero in
  `/etc/trino/catalog`.
- **T0.7 → PASS, e l'attesa è stata flippata.** Ma **il test ha un difetto e
  il flip non poggia su di lui**: T0.7 riporta `282026124836 rows`, che non
  è un conteggio — è la data della riga di WARNING di jline con i non-cifre
  rimossi. Il test fa `head -1` sull'output di `trino --execute` (prendendo
  il WARNING) e poi `tr -dc '0-9'`: **la riga del conteggio non viene mai
  letta**. *Controprova decisiva*: con
  `SELECT count(*) ... WHERE 1=0`, che restituisce `"0"`, il test estrae
  `282026123512` e **passerebbe con un conteggio di zero**. La prima
  asserzione (`grep '"postgresql"'` su `SHOW CATALOGS`) è invece reale.
  La sostanza l'ho misurata a mano: `psql` 13 754 contro Trino 13 755 allo
  stesso istante, generatore attivo — **la metà Trino di P-2 è chiusa**.
  Da aprire come issue: la correzione è di una riga (ultima riga invece della
  prima, e pretendere la forma `"<cifre>"`), ma è codice di test e non la
  scrivo io.
- **#44 verificato su hardware reale, tre stati più il caso non misurabile.**
  Precondizione voluta: Ollama scaldato di proposito, così che lo stato A
  verificasse l'**attribuzione** di due processi reali (entrambi risolti al
  cgroup di `northstream-ollama`) e non il caso banale a zero processi.
  A libera → `exclusive`; B con un container CUDA **senza** il label di
  progetto e 1,5 GiB allocati → `shared`, `foreign_used_mib: 1896`;
  C risanata → `exclusive`, il terzo pid sparito.
  **Il caso `unknown` è stato provato nel modo scomodo**: `nvidia-smi`
  nascosto **mentre la contesa era realmente in corso**. Risposta `unknown`
  con tutti i campi `null` e *"not evidence of contention"* — non `shared`.
  Un modulo che collassasse "non lo so" su "condiviso" avrebbe dato la
  risposta giusta per caso.
  Cancello: `--require-vram-mib 20000` sotto contesa → **FAIL exit 1**;
  `+ --allow-contention` → WARN exit 0; soglia 8000 che ci sta → WARN exit 0;
  nessuna soglia → WARN "reporting only". Tutti e quattro discriminano.
- **Auto-correzione registrata**: il primo tentativo di nascondere
  `nvidia-smi` era `PATH=/usr/bin:/bin` — ma `nvidia-smi` **sta** in
  `/usr/bin`. Il modulo rispose `shared`: la risposta giusta a una domanda
  che non avevo posto. Me ne sono accorto solo perché avevo stampato
  `nvidia-smi visibile? -> …` accanto al risultato. Rifatto con un PATH
  sandbox di soli symlink.
- **Suite completa, due esecuzioni consecutive** (12:40Z e 12:47Z):
  `{"PASS": 9, "XFAIL": 3, "XPASS": 1}`, `RESULT: OK (no regression)`.
- **Il reperto della giornata sui test**: **T0.10 dà XPASS alle 12:40 e
  XFAIL alle 12:47** — stesso stack, stessa SHA, sette minuti di distanza.
  È **#40 colta in flagrante**, ed è la prima osservazione *diretta* della
  sua non-determinatezza: prima era un'inferenza. Un XPASS di T0.10 non va
  mai letto come "A-1 risolto".
- **T0.9 in XPASS su entrambi i run** (323 s e 321 s), atteso XFAIL fino a
  v0.0.4 per A-2. Due osservazioni concordi sono più di quanto avessi per
  T0.10, ma **non bastano**: resta da stabilire se il test discrimini in
  queste condizioni o se lo stato del corpus lo renda vero per costruzione.
  **Attesa di T0.9 non toccata** — è una decisione di analisi, non
  un'esecuzione, e non è mia. Lasciata come reperto.
- **Nota di igiene**: la prima esecuzione porta il tag `envx` perché avevo
  omesso `NS_ENV`; è il default documentato in `run.sh`, non un difetto.
  Rieseguita con `--env envw`, ed è servita a qualcosa: senza la seconda
  osservazione, l'instabilità di T0.10 non sarebbe emersa.
- **Domanda dell'owner sulla VRAM, risposta dai 427 campioni archiviati**:
  mediana **e** p90 **e** p95 tutti a **362 MiB**, p99 1 649, max 2 671;
  sopra 1 GiB solo 5 campioni su 427 (**~5,2 minuti su 7,4 ore**). È un
  **footprint stazionario con picchi brevi, non 6,5 GiB sostenuti** — ma
  durante quel soak **non c'è stata chat**: quello è il costo del solo
  ingest. Con la chat la coppia `granite4:1b`+`granite-embedding:30m` occupa
  **6 489 MiB** (misurato oggi), e il 32b in EVAL **19 788 MiB** (27/08). I
  tre numeri sono lontanissimi: la scelta della scheda dipende da quale dei
  tre usi si vuole coprire, e non è una domanda a cui un numero solo risponda.
- **Grezzi**: `~/NORTHSTREAM-archive/20260828-1247-envw-9e71cd5/`,
  `SHA256SUMS` verificato, incluse le evidenze integrali di #44 e la
  controprova del difetto di T0.7.
- **Costo della sessione**: **non misurabile** (sessione bridge).
- **Prossimo passo**: T-PROF parte 1 (profilo `core` da freddo, con il minuto
  di lettura dichiarato), poi il soak #2 con tutti e tre i profili.
- **Decisioni richieste all'owner**: nessuna. Due issue da aprire a chi
  possiede `bench/`: il difetto di estrazione di T0.7, e l'analisi dell'XPASS
  di T0.9.
