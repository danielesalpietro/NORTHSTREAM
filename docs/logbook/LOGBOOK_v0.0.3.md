# LOGBOOK — Fase 2: Stack onesto sulle risorse (v0.0.3)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata al 2026-08-27, dopo #22/#21 (sessione C) e #44 (sessione D)

**Dove siamo**: #22, #21 e #44 implementati e validati **staticamente** (nessun
demone Docker né GPU in nessuna delle due sessioni); **nessuno dei tre è
ancora verificato a runtime**. Base: tag `v0.0.2` → `966422d` (annotato),
`develop` allineato col merge `cfc98f3`. La Fase 1 ha chiuso P-1 nel
comportamento (T0.6 PASS con modelli veri) e la famiglia P-11/P-12/P-13; il
suo esito distillato è in `docs/logbook/SINTESI_fasi_chiuse.md`.

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
- **Fatto**:
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
