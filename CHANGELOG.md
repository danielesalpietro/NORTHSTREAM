# Changelog — NORTHSTREAM

Formato: [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) ·
Versioning: [SemVer](https://semver.org/lang/it/), release train definito in
[`docs/piano_ricovero.md`](docs/piano_ricovero.md) §6.

Regola (da `CLAUDE.md` §4): ogni commit che cambia comportamento aggiunge una riga
sotto `[Unreleased]` citando il finding o l'obiettivo che chiude; al rilascio la
sezione prende versione e data, e ogni riga deve avere il suo test di riscontro.

## [Unreleased]

*(v0.0.3 — Fase 2, stack onesto sulle risorse. In coda: tier riscritti sui
numeri misurati (T-PROF, [#23](https://github.com/danielesalpietro/NORTHSTREAM/issues/23)).)*

### Added
- `trino/catalog/postgresql.properties` — catalogo JDBC verso il Postgres
  operativo (`postgres:5432/sales`, utente `demo`). Il nome del file fissa
  il nome del catalogo: **`postgresql`**, non `postgres` come lo cita di
  sfuggita `docs/review_tecnica.md` §4.2 — vincolato dal test T0.7 e dalla
  tabella `docs/piano_ricovero.md` §4.1, entrambi scritti prima di questa
  sessione e già puntati su `postgresql.public.orders` (**P-2**,
  [#22](https://github.com/danielesalpietro/NORTHSTREAM/issues/22)).
  Chiude l'altra metà di P-2 — la prima, la directory `trino/catalog`
  mancante, era già chiusa dal `.gitkeep` di P-12 in v0.0.2. **Non
  verificato in questa sessione** (nessun demone Docker): verificabile solo
  staticamente (`docker compose config`), il flip XFAIL→PASS di T0.7 resta
  da misurare su ENV-L o nightly ENV-W — `bench/t0/expected/current.json`
  **non è stato toccato** di proposito, per lo stesso motivo per cui non lo
  fu per T0.6 finché non fu misurato con modelli veri (v0.0.2).
- `trino/etc/jvm.config` (montato su `/etc/trino/jvm.config`, sola lettura)
  — sostituisce l'heap percentuale di default dell'immagine
  (`-XX:InitialRAMPercentage=80 -XX:MaxRAMPercentage=80`, che senza un
  `mem_limit` di container dimensiona l'heap sull'80% della RAM **dell'host**,
  non del laptop) con un heap fisso `-Xms1G -Xmx2G`, nello stile già in uso
  per Elasticsearch (`-Xmx1g`). **Stima dichiarata, non misura**: 2G è
  dimensionato per un catalogo singolo con due tabelle operative piccole e
  nessun carico Iceberg/lakehouse dietro — i numeri veri sul profilo
  `lakehouse` sono compito di [#23](https://github.com/danielesalpietro/NORTHSTREAM/issues/23)
  su ENV-L (P-2/P-5, §4.2-4.3 della review, issue #22).
- `docker-compose-northstream-ai.yml`, `docker-compose.addon.yml`: profili
  Compose `core` (nessun tag — sempre attivo, comportamento invariato di
  default per chi passa i nomi servizio espliciti o nessun `--profile`),
  `lakehouse` (Flink, MinIO, Trino, e lo schema registry Apicurio — v. nota
  sotto) e `governance` (l'intero stack OpenMetadata: db, Elasticsearch, il
  job di migrazione, il server) — **P-5**,
  [#21](https://github.com/danielesalpietro/NORTHSTREAM/issues/21).
  `docker compose --profile core up` avvia gli 11 servizi della pipeline che
  funziona davvero (landing page, Kafka, Kafka UI, Postgres, Adminer,
  Debezium Connect, Ollama, Open WebUI + l'addon: Qdrant, stream-agent,
  data-generator) invece dei 19-21 di sempre.
- `mem_limit` per **20 dei 21 servizi** del compose (P-5, issue #21). La
  maggioranza sono **stime dichiarate**, non misure: derivate dal profilo
  tipico della tecnologia (JVM di default, app leggere Python/Go/Node) per
  un carico di laboratorio, non da un run osservato — i numeri misurati
  arrivano da [#23](https://github.com/danielesalpietro/NORTHSTREAM/issues/23)
  su ENV-L. Due sole eccezioni sono ancorate a un valore reale invece che
  a una sensazione: **Trino** (2560m, margine sopra l'heap fisso di 2G appena
  introdotto) ed **Elasticsearch** (1536m, margine sopra `-Xmx1g`, l'unica
  eccezione già vincolata dalla review). **Ollama è l'unico servizio senza
  `mem_limit`, deliberatamente**: il suo fabbisogno dipende dal modello
  caricato, cioè dal tier scelto (`examples/*/.env`, da 350m a 32b) — un
  tetto fisso o farebbe crashare il tier `optimal` o sarebbe inutile per il
  `minimal`; una decisione per-tier è compito di #23, non di questa sessione.
  `debezium-connect` ha un margine più ampio (1536m, non 1024m come gli
  altri singoli servizi JVM) perché è l'unico servizio JVM esercitato sotto
  carico CDC reale a ogni push da `ci-smoke`: una stima troppo stretta lì
  fallirebbe come un OOM-kill silenzioso, non come un errore leggibile.

### Fixed
- `docker-compose-northstream-ai.yml`: `open-webui` passa da `mem_limit: 512m` a
  **`1024m`**. Il tetto stimato di [#21](https://github.com/danielesalpietro/NORTHSTREAM/issues/21)
  stava **sotto il footprint misurato** e teneva il container in **crashloop**:
  `RestartCount` da 134 a 142 in quaranta secondi su ENV-W, `Health` mai una volta
  `healthy`. Il sintomo era ingannevole — `docker stats` mostrava una media **bassa**
  di 265 MiB a dente di sega, perché **un tetto troppo stretto si legge come poco
  consumo, non come troppo**. Footprint reale una volta che il container parte:
  679,7 MiB (T-PROF) e 687 MiB sullo stack senza tetti del soak #1; 1 GiB lascia
  ~1,5× su entrambe le letture (**P-5**, [#21](https://github.com/danielesalpietro/NORTHSTREAM/issues/21)).

- `bench/t0/tests/t0.07_trino_catalog.sh` — l'asserzione sul conteggio non
  poteva fallire. Il comando univa stderr a stdout (`2>&1`) e ricavava il
  numero da `head -1 | tr -dc '0-9'`: la prima riga è il WARNING di jline del
  CLI Trino, e il suo timestamp sopravvive allo strip come un intero positivo
  grande. Una query che restituiva **0 righe** veniva quindi valutata **OK** —
  dimostrato su ENV-W il 28/08. Ora stderr resta fuori dal valore (riportato
  come osservazione, non parsato) e si accetta **solo** una riga che sia un
  intero puro dopo aver tolto le virgolette del CLI, esattamente una. Il
  merito del ritrovamento è della sessione ENV-W, che ha dichiarato il difetto
  invece di appoggiarsi al verde (**P-2**, [#22](https://github.com/danielesalpietro/NORTHSTREAM/issues/22)).

- `docker-compose-northstream-ai.yml`: `kafka-ui` dipendeva
  (`depends_on: schema-registry: condition: service_started`) da un servizio
  ora tag `lakehouse`. Compose rifiuta un servizio sempre-attivo che dipende
  da un servizio dietro un profilo non richiesto — `--profile core` da solo
  falliva con "depends on undefined service". `schema-registry` è comunque
  solo un endpoint opzionale nell'ambiente di `kafka-ui`
  (`KAFKA_CLUSTERS_0_SCHEMAREGISTRY`), non un requisito di avvio: la
  dipendenza forte è stata rimossa, l'endpoint resta configurato e kafka-ui
  mostra semplicemente quel pannello vuoto se Apicurio non gira (issue #21,
  scoperto durante la validazione statica di questa sessione).
- `start-addon.sh` / `start-addon.ps1`: senza modifica, l'introduzione dei
  profili avrebbe cambiato silenziosamente il comportamento di default di
  questi script da "avvia tutto" (19-21 container) a "avvia solo `core`"
  (11), perché un `docker compose up` senza `--profile` attiva solo i
  servizi non taggati. `ci-nightly` chiama `./start-addon.sh --gpu` e si
  aspetta lo stack pieno per la suite `full` (T0.7 compreso) — esattamente
  il rischio di regressione silenziosa che CLAUDE.md §5/il piano vietano.
  Gli script ora passano **tutti e tre i profili di default**
  (`core,lakehouse,governance`), preservando il comportamento di oggi, e
  accettano `--profile <nome>[,<nome>...]` (`-Profile` in PowerShell) per
  chi vuole esplicitamente lo stack snello (issue #21).

### Added
- **Esclusività dell'host (#44)** — pre-check, run-check, post-run, sui tre
  momenti dichiarati dal piano. `bench/lib/gpu_exclusivity.py` (nuovo,
  condiviso) risponde "la GPU è tutta nostra?" attribuendo ogni processo di
  calcolo GPU (`nvidia-smi --query-compute-apps`) a un container di questo
  compose project via match dell'id a 64 esadecimali in `/proc/<pid>/cgroup`
  contro `docker ps --filter label=com.docker.compose.project=...`; un
  processo non attribuibile è **foreign**, mai ignorato. Stato
  `exclusive`/`shared`/`unknown` — mai un booleano che collassa "falso" su
  "non l'ho potuto sapere" (CLAUDE.md §5): l'host senza `nvidia-smi` è
  `unknown` ("non applicabile"), non `shared`.
  - **Pre-check**: `preflight.sh`/`preflight.ps1` `--gpu` guadagnano
    `--require-vram-mib N`, `--require-ram-mib N` (dichiarati dal
    chiamante, mai inferiti da `--tier`) e `--allow-contention` (bypass
    esplicito, sempre loggato). Rifiuta con causa/sintomo/rimedio quando la
    VRAM libera o la RAM libera non coprono quanto dichiarato; su
    `preflight.ps1` l'attribuzione per container non ha equivalente pulito
    (Docker Desktop gira nella propria VM WSL2) ed è dichiarata come tale,
    non finta.
  - **Run-check**: `bench/t0/run.sh` campiona GPU/RAM fra un test e l'altro
    (mai un demone in background: non deve mai poter uccidere la suite) e
    registra il primo campione in stato `shared` (`contention_first_seen`),
    senza abortire il run.
  - **Post-run**: `manifest.json.exclusivity` — `declared` (da
    `--exclusivity exclusive|shared|unknown`, default `unknown`, come già
    su `feature/soak-harness` per il soak) e `detected` (calcolato dai
    campioni), **mai fusi in un solo valore**: un operatore che dichiara
    `exclusive` su un host che i campioni mostrano `shared` è esattamente
    il disaccordo da preservare. Riga corrispondente in `summary.md` /
    `docs/runs/<RUN_ID>.md`.
  - I cinque report già archiviati in `docs/runs/` privi del campo
    (precedenti a questa release, o su runner GitHub-hosted dove il
    concetto non si applica nello stesso modo) sono **annotati** con
    `unknown` in coda al file, non riscritti.

## [v0.0.2] — 2026-08-27

**Che cosa rilascia questa versione**: raggiungibilità e riproducibilità dello
stack (obiettivo O3 del piano). Kafka è raggiungibile dall'host come il README
promette da sempre, senza più il divario fra racconto e comportamento aperto
da P-1 in v0.0.1; le immagini sono pinnate a versione+digest invece di tag
mobili; tutte le porte sono legate a `127.0.0.1` invece che a `0.0.0.0`; un
preflight fallisce con causa/sintomo/rimedio invece di lasciar morire un
container in silenzio. Il lavoro ha anche scoperto e chiuso, nello stesso giro
di verifica su hardware reale, una classe di difetti che nessuna quantità di
CI verde poteva vedere: P-11/P-12/P-13, lo stesso meccanismo — Docker che gira
come root e lascia in giro stato che l'utente non può toccare — visto da tre
lati (un volume, una directory su un workspace CI, la stessa directory dentro
un clone esistente).

**Progression test dichiarato**: **T0.6** (client host ottiene metadata
Kafka utilizzabili) da XFAIL a **PASS** — misurato **con modelli veri**, non
solo in CI con mock-ollama: due nightly reali consecutive su ENV-W contro
`6b377a3` danno T0.6 PASS in entrambe (`broker 1 at localhost:29092`).

**Run di riferimento**: [`docs/runs/20260827-1148-envw-6b377a3.md`](docs/runs/20260827-1148-envw-6b377a3.md)
— due nightly consecutive su ENV-W in stato **esclusivo**, suite `full` con
modelli reali. T0.6 PASS in entrambe; T0.2/T0.3 PASS in entrambe (nessuna
regressione dal cambio immagine di #17/#18); `actions/checkout` verde in
entrambe (P-12 dimostrato sul workspace CI). Il metro resta
[`docs/runs/20260826-2053-envw-5eb456a-baseline.md`](docs/runs/20260826-2053-envw-5eb456a-baseline.md)
(baseline, 5 PASS + 6 XFAIL + 1 XPASS): tutti e cinque i PASS di riferimento
restano PASS in questa release, nessuna regressione.

**Qualificazione da riportare, non da nascondere**: nelle due nightly di
riferimento, T0.4 e T0.5 concludono `failure` **a stack freddo**, con tre
insiemi diversi di FAIL su tre run distinti — non è una regressione di questa
release (è la finestra cieca di A-8, [#39](https://github.com/danielesalpietro/NORTHSTREAM/issues/39)),
ed **entrambi passano 2 volte su 2 a stack caldo** (attesa di 6 minuti oltre
la finestra A-8). Ma "non è una regressione" e "la nightly è una guardia di
non-regressione affidabile" sono due affermazioni diverse, e solo la prima è
dimostrata: finché non esiste un *warm-up gate*
([#47](https://github.com/danielesalpietro/NORTHSTREAM/issues/47)), un FAIL
di T0.4/T0.5 sulla nightly a freddo non è interpretabile da solo.

**Finding chiusi in questa release**. Verificati su ENV-W con hardware (e,
dove rilevante, modelli) reali, non solo in CI con mock-ollama o
staticamente: **P-1** (#16), **P-3/P-4** (#17), **P-9** (#41), **P-10** (#42),
**P-11** (#45), **P-12** (#46), **P-13** (#48). Verificati solo staticamente
in questa sessione (nessun demone Docker) e non su ENV-W — **P-6** (#19: la
Z8 ha già `vm.max_map_count` preconfigurato, quindi non riproduce il difetto
che il preflight rileva, coerentemente con quanto la review aveva già
osservato) e **P-7** (#18: verificato via `docker compose config`, non con un
tentativo di connessione dalla LAN).

### ⚠ Breaking (lab esistenti) — leggere PRIMA di `git pull`

Se stai aggiornando un checkout NORTHSTREAM che ha già fatto girare lo stack
(non un `git clone` nuovo), esegui **questi comandi, in quest'ordine, prima
di `git pull`** — farlo dopo, o non farlo, lascia l'albero a metà o il
broker in crash-loop:

```bash
# 1. Rimuovi la directory che Docker ha creato come root (P-13): se esiste,
#    blocca 'git pull'/'git checkout' con "Permission denied" a metà operazione.
sudo rm -rf trino/catalog trino

# 2. SOLO ORA, git pull:
git pull

# 3. Rimuovi il volume Kafka della vecchia immagine (P-11): dato locale
#    effimero, nessuna perdita — CDC lo ricostruisce dal primo avvio.
docker volume rm wap-northstream-lab_kafka_data 2>/dev/null || true
# oppure, per un reset completo dello stack:
docker compose down -v
```

**Perché**: `bitnamilegacy/kafka:3.7.1` → `apache/kafka:4.3.1` (#17) cambia
anche l'utente del container Kafka, da `uid=1001 gid=0(root)` a
`uid=1000(appuser) gid=1000`. Un volume `kafka_data` popolato dalla vecchia
immagine resta `0:0` modo `775` — scrivibile dal gruppo root, di cui il
vecchio broker faceva parte e il nuovo no — e il broker va in crash-loop con
`AccessDeniedException`, un errore che non nomina né i permessi né il cambio
d'immagine (**P-11**, [#45](https://github.com/danielesalpietro/NORTHSTREAM/issues/45)).
`trino/catalog` non esiste nel repository ed è sempre stata creata da
Docker al primo `up`; quando la crea come `root:root` (bind-mount di una
directory assente), l'utente del checkout non può più toccarla — su un
workspace CI ripulito a ogni run questo bloccava solo la nightly successiva
alla prima (**P-12**, [#46](https://github.com/danielesalpietro/NORTHSTREAM/issues/46));
sullo stesso clone di chi usa il lab da tempo, blocca direttamente `git
pull` (**P-13**, [#48](https://github.com/danielesalpietro/NORTHSTREAM/issues/48)).

**P-11, P-12 e P-13 sono lo stesso difetto visto da tre lati**: Docker gira
come root e lascia in giro stato (un volume, una directory, la stessa
directory dentro un clone) che l'utente non può toccare — e nessuno dei tre
è visibile alla CI, perché ogni run parte da zero ed esercita sistematicamente
l'unico caso che funziona. `preflight.sh`/`.ps1` (#19) ora rileva **entrambe**
le condizioni prima dell'avvio (volume Kafka incompatibile, directory non
scrivibili nell'albero del repository) e fallisce con causa, sintomo e
rimedio — ma non sostituisce questi comandi per un clone già bloccato: non
può correre finché `git pull` non ha già portato la sua stessa versione
aggiornata sulla macchina.

### Changed
- `docker-compose-northstream-ai.yml`: `bitnamilegacy/kafka:3.7.1` sostituito con
  `apache/kafka:4.3.1`, pinnato a versione+digest (P-3, P-4, O3.2,
  [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17)). Le env
  `KAFKA_CFG_*` di Bitnami diventano `KAFKA_*` nel formato dell'immagine
  ufficiale Apache. **Verificato**: T0.2/T0.3 (consumo CDC interno) PASS in
  due nightly reali consecutive su ENV-W —
  [`docs/runs/20260827-1148-envw-6b377a3.md`](docs/runs/20260827-1148-envw-6b377a3.md)
  — nessuna regressione dal cambio immagine.
- `docker-compose-northstream-ai.yml` e `docker-compose.addon.yml`: le altre
  sette immagini oggi su `:latest`/tag mobili pinnate a versione+digest —
  `kafka-ui` (`v0.7.2`), `adminer` (`5.5.1`), `minio` (`RELEASE.2025-09-07T16-13-09Z`),
  `mc` (`RELEASE.2025-08-13T08-35-41Z`), `qdrant` (`v1.19.0`), `ollama` (`0.33.1`),
  `open-webui` (`v0.11.1`) — digest risolti via API del registry (token anonimo
  Docker Hub / GHCR), nessun demone Docker disponibile in questa sessione
  (P-4, O3.2, [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17)).
  **Verificato**: nuovo test **T-REPRO** (v. sotto), PASS in ogni run statico.
- `docker-compose-northstream-ai.yml`: doppio listener Kafka — `INTERNAL`
  (`kafka:9092`, usato dagli altri servizi del compose) ed `EXTERNAL`
  (`localhost:29092`, pubblicato per un client sull'host), con
  `advertised.listeners` coerente per ciascuno. Prima era un solo listener
  `PLAINTEXT` annunciato come `kafka:9092` a tutti, compreso l'host — la causa
  esatta di P-1 (T0.6). Progression test dichiarato della release: **T0.6
  XFAIL → PASS** (P-1, O3.1, [#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16)).
  **Verificato con modelli veri**, non solo mock-ollama: T0.6 PASS in due
  nightly reali consecutive su ENV-W —
  [`docs/runs/20260827-1148-envw-6b377a3.md`](docs/runs/20260827-1148-envw-6b377a3.md).
- `bench/t0/run.sh`: **T0.6 promosso nella suite `ci`** (oltre a `core`/`full`),
  così il progression test della release gira a ogni push via `ci-smoke`
  invece di aspettare la nightly su ENV-W — requisito esplicito del piano
  per questa release ([#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16)).
- `bench/t0/lib/common.sh`: default di `NS_KAFKA_HOST_BOOTSTRAP` spostato da
  `localhost:9092` a `localhost:29092`, coerente col nuovo listener esterno
  ([#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16)).
- `bench/t0/`: nuovo test statico **T-REPRO** (`t_repro_digest_pin.sh`) —
  verifica che le 8 immagini di P-3/P-4 restino pinnate a versione+digest;
  aggiunto alle suite `static`, `core` e `full`. `run.sh` ora risolve anche
  id di test non numerici (`test_script()`), non solo `T0.N`
  ([#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17)).
- `bench/t0/expected/current.json`: `T0.6` da `XFAIL` a `PASS`, `T-REPRO`
  aggiunto come `PASS`; `expected/baseline.json` **non toccato** (è il
  contratto congelato della baseline, non si piega ai risultati di release
  successive — CLAUDE.md §3.8/decisioni Fase 0).

- `docker-compose-northstream-ai.yml`, `docker-compose.addon.yml`,
  `bench/ci/mock-ollama.yml`: tutti i port mapping passano da
  `porta:porta` (pubblicato su `0.0.0.0`) a `127.0.0.1:porta:porta` — 17
  porte in totale, comprese quelle appena introdotte da #16 e #17.
  Rende vero il claim "local testing only" del README (P-7,
  [#18](https://github.com/danielesalpietro/NORTHSTREAM/issues/18)).
  Verificato programmaticamente su `docker compose config`: ogni porta
  pubblicata ha `host_ip: 127.0.0.1`; `localhost` risolve comunque a
  `127.0.0.1` sull'host, quindi T0.6 (`localhost:29092`) e `ci-smoke`
  (che gira `curl` sullo stesso host dei container) restano coerenti.

### Added
- `preflight.sh` / `preflight.ps1`: script di preflight (P-6) — verifica
  `vm.max_map_count ≥ 262144` (prima causa concreta del bootstrap loop di
  Elasticsearch/OpenMetadata su Linux nativo, dove Docker Desktop/WSL2 non lo
  preimposta), RAM e spazio disco disponibili contro le soglie del tier
  scelto (`--tier minimal|recommended|optimal`, default `minimal`, soglie
  allineate alla tabella hardware del README), driver NVIDIA con `--gpu`.
  Fallisce con un messaggio azionabile invece di lasciar morire un
  container in silenzio. **Passo esplicito, non invocato automaticamente**
  da `start-addon.sh`/`.ps1` in questa release — motivato nel logbook di
  fase ([#19](https://github.com/danielesalpietro/NORTHSTREAM/issues/19)).
  Verificato in questa sessione (nessun demone Docker, ma bash sì): su
  questo host sandbox rileva correttamente `vm.max_map_count=65530` (sotto
  soglia), 15 GiB di RAM e 29 GiB liberi (entrambi sotto la soglia
  `minimal`), ed esce con `FAIL` e i tre rimedi; `preflight.ps1` non è
  eseguibile in questa sessione (nessun PowerShell) — scritto per
  simmetria con `start-addon.ps1`, da collaudare su ENV-L/host Windows.
- `preflight.sh` / `preflight.ps1`: nuovo controllo per **P-11** — rileva un
  volume `kafka_data` preesistente (via le label `com.docker.compose.*` che
  compose assegna, non un nome hardcoded) e verifica che sia scrivibile
  dall'utente `1000:1000` di `apache/kafka` con un container `busybox`
  usa-e-getta; fallisce con il comando di rimedio (`docker volume rm ...`)
  se non lo è, distinguendo un vero permission-denied da un errore
  generico (docker non raggiungibile, pull fallito) che diventa un
  `WARN`, non un falso positivo
  ([#45](https://github.com/danielesalpietro/NORTHSTREAM/issues/45)).
  **Non verificabile in CI per costruzione** (`ci-smoke`/`ci-nightly`
  partono sempre da un volume inesistente, l'unico caso che funziona).
  **Verificato su ENV-W sui tre stati reali**: volume assente → `OK`,
  exit 0; volume ricreato con la vecchia proprietà (`0:0` modo 775, file
  `1001:0`) → `FAIL` con causa/sintomo/rimedio, exit 1; volume creato
  dalla nuova immagine → `OK`, exit 0. Il preflight **discrimina**, non
  fallisce a prescindere.
- `trino/catalog/.gitkeep` — la directory non esisteva nel repository
  (metà del finding P-2): Docker la creava `root:root` al primo `up` sul
  runner self-hosted, e alla nightly successiva `actions/checkout` moriva
  con `EACCES` nel ripulire il workspace (**P-12**,
  [#46](https://github.com/danielesalpietro/NORTHSTREAM/issues/46)). Con
  la directory già presente in git, Docker non la ricrea come root.
  **Verificato su ENV-W**: due nightly consecutive sullo stesso workspace,
  `actions/checkout` verde in entrambe —
  [`docs/runs/20260827-1148-envw-6b377a3.md`](docs/runs/20260827-1148-envw-6b377a3.md).
- `preflight.sh` / `preflight.ps1`: nuovo controllo per **P-13** — cerca
  directory non scrivibili dall'utente corrente nell'albero del
  repository (`find -type d -not -writable` / un test di scrittura reale
  in PowerShell), non solo il volume Docker di P-11: stesso meccanismo,
  una directory come `trino/catalog` creata da un container che gira come
  root invece di un volume, ma con lo stesso effetto — bloccare `git
  pull`/`git checkout` con `Permission denied` a metà operazione
  ([#48](https://github.com/danielesalpietro/NORTHSTREAM/issues/48)).
  **Non verificabile in CI per costruzione, come P-11.** **Verificato su
  ENV-W** con lo stesso protocollo a tre stati di P-11, **più una
  controprova sull'istanza reale**: il preflight è stato puntato sul
  clone reale che quella mattina non riusciva più a fare `git pull`, e ha
  rilevato entrambe le directory compromesse — il controllo cattura il
  caso vero, non solo un'imitazione sintetica.

### Fixed
- `bench/t0/lib/doc_truth.py`: `kafka_advertises_host()` cercava solo la
  chiave Bitnami `KAFKA_CFG_ADVERTISED_LISTENERS`. Dopo la migrazione a
  `apache/kafka` (#17) quella chiave non esiste più nel compose: il linter
  T0.12 sarebbe rimasto **silenziosamente cieco** al comportamento reale del
  broker (falso negativo su P-1) nel momento esatto in cui il README verrà
  aggiornato con l'endpoint `localhost:29092` a fine release. Ora legge anche
  `KAFKA_ADVERTISED_LISTENERS` ([#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16),
  [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17)).
- Bit di esecuzione impostato sui tre script del Quick Start (`start-addon.sh`,
  `register-connector.sh`, `demo-compare.sh`), committati `100644` invece di
  `100755`: su un clone pulito il primo comando del Quick Start falliva con
  `Permission denied` (exit 126) (P-9, [#41](https://github.com/danielesalpietro/NORTHSTREAM/issues/41)).
- Teardown di `ci-nightly` non usa più `down -v`: rimuove esplicitamente solo i
  volumi di stato esercitati dalla suite T0 (Kafka, Postgres, Qdrant),
  preservando `ollama_data` — evita di ricancellare i modelli Granite a ogni
  notte (P-10, [#42](https://github.com/danielesalpietro/NORTHSTREAM/issues/42)).
- `bench/t0/tests/t0.02_stack_health.sh` e `t0.03_cdc_sentinel.sh` chiamavano
  `kafka-topics.sh`/`kafka-console-consumer.sh` per nome nudo, contando sul
  PATH. Nell'immagine Bitnami quei binari erano in PATH; in `apache/kafka:4.3.1`
  (#17) stanno in `/opt/kafka/bin/` e non lo sono — verificato dalla sessione
  ENV-W con `docker run --entrypoint sh apache/kafka:4.3.1 -c 'command -v
  kafka-topics.sh; ls /opt/kafka/bin/kafka-topics.sh'`. **Difetto della sonda,
  non del broker**: T0.6 (client host) e l'healthcheck del compose, che già
  usa il path assoluto, restavano verdi durante il run rosso di `ci-smoke`
  (33057147479). Entrambi i test ora provano il path assoluto per primo, con
  fallback al nome nudo — lo stesso pattern già in uso nell'healthcheck —
  così l'harness resta valido anche su un'immagine che li mettesse in PATH.
  Corregge la regressione di T0.2/T0.3 introdotta da #17
  ([#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16),
  [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17)).
  **Verificato**: `ci-smoke` tornato verde sul push successivo, e T0.2/T0.3
  confermati PASS con modelli veri in due nightly reali su ENV-W —
  [`docs/runs/20260827-1148-envw-6b377a3.md`](docs/runs/20260827-1148-envw-6b377a3.md).

## [v0.0.1] — 2026-08-26

**Che cosa rilascia questa versione**: la capacità di *misurare* il progetto, e la
verità documentale. Il comportamento runtime dello stack e dell'agent è
**identico** alla baseline `v0.0.0-baseline`: v0.0.1 non ripara il sistema, lo
rende osservabile e smette di raccontarlo male.

**Progression test dichiarato**: T0.12 (verità documentale) da XFAIL a **PASS** —
12 violazioni azzerate.

**Run di riferimento**: [`docs/runs/20260826-2053-envw-5eb456a-baseline.md`](docs/runs/20260826-2053-envw-5eb456a-baseline.md)
— suite `full` contro il tag baseline su ENV-W con modelli reali: 5 PASS + 6 XFAIL
+ 1 XPASS, `RESULT: OK (no regression)`. Sei finding della review passano da
deduzione statica a misura (P-1, P-2, A-2, A-3, A-5; P-6 non riproducibile su host
preconfigurato). Due finding nuovi emersi dalla misura: **A-8** (ritardo di scoperta
dei topic, variabile in [0, 5 min]) e **P-9**; uno segnalato dall'esecuzione:
**P-10**.

### Added
- `bench/t0/` — harness della suite T0: 12 test indipendenti dall'ordine, valori
  sentinella fissi (77.31, 91.73, Depot-9/93.17), output JSON per test, semantica
  PASS/XFAIL/FAIL/XPASS/SKIP e attese dichiarate in `expected/` (O1.2, issue #11).
- `bench/t0/lib/doc_truth.py` — linter di verità documentale, il test T0.12:
  layout README vs file reali, endpoint della tabella servizi vs compose, sezione
  License vs LICENSE, header di tabella duplicati, placeholder residui
  (D-1, D-2, P-1 doc).
- `bench/ci/mock-ollama.yml` + `bench/ci/mock-ollama/` — stub HTTP deterministico
  che sostituisce Ollama in CI: embedding da hash del testo, `/api/generate` che
  fa eco al contesto. Testa la pipeline, non il modello (issue #11).
- `.github/workflows/ci-static.yml` — yamllint, ruff, hadolint, syntax check del
  harness e suite T0 statica (T0.1 + T0.12) su ogni push (piano §5, issue #12).
- `.github/workflows/ci-smoke.yml` — stack CDC completo su runner GitHub con
  mock-ollama, suite T0 `ci` (T0.1–T0.4, T0.8, T0.11), timeout 25 min, log dei
  container e report come artifact (piano §5, issue #12).
- `.github/workflows/ci-nightly.yml` — suite completa con modelli reali su runner
  self-hosted `[self-hosted, env-w]`, schedule + `workflow_dispatch`, dormiente
  finché l'owner non registra il runner e la variabile `RUN_NIGHTLY` (issue #12).
- `bench/t0/run.sh`: ogni run genera `SHA256SUMS` (verificato subito) e registra nel
  `manifest.json` la sezione `stack` con image id e digest dei container in esecuzione
  più i modelli Ollama caricati — l'archiviazione di `docs/piano_ricovero.md` §3 non
  richiede più passaggi manuali (issue #11, lacuna emersa dal run di riferimento ENV-W).
- `.yamllint.yml` — configurazione del linter YAML usata da ci-static.
- `docs/runs/` — report dei run T0 eseguiti in CI: `ci-smoke-33006019554.md`
  (primo run, rosso, con le prime misure di A-3 e A-5) e `ci-smoke-33008193653.md`
  (primo run verde: 4 PASS + 2 XFAIL, più la misura del ritardo di scoperta
  topic dell'agent: 4 min 46 s).
- `.gitignore` — esclude `results/` (gli output grezzi dei run non stanno nel repo).
- `docs/review_tecnica.md` — review tecnica critica della baseline (issue #2).
- `docs/piano_ricovero.md` — piano di ricovero verso v0.1.0-beta1 (O1–O7, suite T0/EVAL/soak, release train).
- `CLAUDE.md` — direttive vincolanti di onboarding e chiusura per ogni sessione (O1.2, anti-dispersione memoria).
- `CHANGELOG.md`, `docs/logbook/LOGBOOK_baseline.md` — avvio della disciplina documentale per fase.

### Changed
- README: storyline accorciata al flusso realmente implementato
  (Postgres → Debezium → Kafka → agent → Qdrant → LLM) e nuova tabella
  "Layer status" che dichiara quali servizi sono collegati e quali no
  (O2.1, review §2 e §4.4, issue #14). Progression test: T0.12.
- README: "Suggested Repository Layout" → "Repository Layout", allineato ai file
  che esistono davvero (D-1); rimossi i path mai esistiti (`trino/catalog/*`,
  `docs/architecture.md`, `docs/roadmap.md`, `examples/sample-*`) e aggiunti
  quelli omessi (`docker-compose.gpu.yml`, `dashboard.html`, script, `bench/`).
- README: la tabella servizi non pubblicizza più `localhost:9092` come endpoint
  Kafka utilizzabile e spiega perché il broker è raggiungibile solo dalla rete
  Docker, con il test T0.6 che ne fissa il comportamento (P-1, parte doc).
- README: sezione License riscritta su MIT, coerente con il file `LICENSE`
  (D-2); rimosso il placeholder `<your-repository-url>` dal Quick Start.
- README: "Demo Narrative" riscritta senza i passaggi (Flink, lakehouse, Trino,
  OpenMetadata) che la pipeline non esegue (D-1).
- README e `docs/demo-script.md`: dichiarato il ritardo di scoperta dei topic
  dell'agent (finding **A-8**, misurato in CI a 4 min 46 s) con il workaround
  `docker restart northstream-stream-agent` subito dopo la registrazione del
  connettore. Mitigazione **solo documentale**: il fix strutturale è in v0.0.4
  ([#39](https://github.com/danielesalpietro/NORTHSTREAM/issues/39), test T0.13).
- `docs/demo-script.md`: nuova sezione "How the retrieval really works" che
  dichiara il boost keyword su `KNOWN_SITES`, i suoi limiti sui siti fuori lista
  e la sostituzione prevista in v0.0.4, più la nota sul trade-off
  `decimal.handling.mode: double` (D-3, A-1 dichiarato, issue #14).
- `.env` non è più tracciato: diventa `.env.example` e `.env` entra in
  `.gitignore` (P-8, O3.5). Verificato che l'output di `docker compose config`
  resta identico: i default del compose coincidono coi valori del vecchio `.env`.

### Fixed
- `bench/t0/`: i default erano internamente incoerenti — `NS_RECENCY_SECONDS=900`
  superava il tetto per-test `NS_TEST_TIMEOUT=600`, quindi **T0.9 con i soli default
  veniva sempre ucciso dal timeout** e non avrebbe mai potuto flippare in v0.0.4.
  Ora la soglia di recency è 300 di default e il tetto del singolo test si deriva dai
  suoi parametri (`NS_RECENCY_SECONDS + 300`): chi vuole l'asserzione più forte passa
  900 e il timeout lo segue da solo. Scelta documentata in `bench/README.md` (#11).
- README: rimossa la doppia riga di header nella tabella dei modelli Granite,
  che rompeva il rendering (D-2).
- `docker-compose-northstream-ai.yml`: rimossi spazi a fine riga e aggiunta la
  newline finale (igiene per yamllint in ci-static). Cambiamento di sola
  formattazione: l'output di `docker compose config` è byte-identico a prima.

*(Il comportamento runtime dello stack e dell'agent è ancora identico alla
baseline `v0.0.0-baseline`: v0.0.1 aggiunge misura e verità documentale, non
modifica il sistema misurato.)*

## [v0.0.0-baseline] — 2026-07-06
Stato del branch `develop` @ `5eb456a` al momento dell'avvio del piano di ricovero:
stack compose (Kafka, Debezium, Postgres, Flink, Apicurio, MinIO, Trino,
OpenMetadata, Ollama, Open WebUI) + addon Stream Context Agent (Qdrant,
stream-agent, data-generator). Difetti noti censiti in `docs/review_tecnica.md`;
tag da apporre come prima azione della Fase 0 (v. `CLAUDE.md` §2).
