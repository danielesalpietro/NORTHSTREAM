# Changelog — NORTHSTREAM

Formato: [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) ·
Versioning: [SemVer](https://semver.org/lang/it/), release train definito in
[`docs/piano_ricovero.md`](docs/piano_ricovero.md) §6.

Regola (da `CLAUDE.md` §4): ogni commit che cambia comportamento aggiunge una riga
sotto `[Unreleased]` citando il finding o l'obiettivo che chiude; al rilascio la
sezione prende versione e data, e ogni riga deve avere il suo test di riscontro.

## [Unreleased]

### Changed
- `docker-compose-northstream-ai.yml`: `bitnamilegacy/kafka:3.7.1` sostituito con
  `apache/kafka:4.3.1`, pinnato a versione+digest (P-3, P-4, O3.2,
  [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17)). Le env
  `KAFKA_CFG_*` di Bitnami diventano `KAFKA_*` nel formato dell'immagine
  ufficiale Apache; comportamento del broker (singolo listener `PLAINTEXT`,
  ancora irraggiungibile dall'host) **invariato** in questo commit — il doppio
  listener è #16, deliberatamente separato per non riscrivere la stessa
  configurazione due volte su due immagini diverse.
- `docker-compose-northstream-ai.yml` e `docker-compose.addon.yml`: le altre
  sette immagini oggi su `:latest`/tag mobili pinnate a versione+digest —
  `kafka-ui` (`v0.7.2`), `adminer` (`5.5.1`), `minio` (`RELEASE.2025-09-07T16-13-09Z`),
  `mc` (`RELEASE.2025-08-13T08-35-41Z`), `qdrant` (`v1.19.0`), `ollama` (`0.33.1`),
  `open-webui` (`v0.11.1`) — digest risolti via API del registry (token anonimo
  Docker Hub / GHCR), nessun demone Docker disponibile in questa sessione
  (P-4, O3.2, [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17)).
- `docker-compose-northstream-ai.yml`: doppio listener Kafka — `INTERNAL`
  (`kafka:9092`, usato dagli altri servizi del compose) ed `EXTERNAL`
  (`localhost:29092`, pubblicato per un client sull'host), con
  `advertised.listeners` coerente per ciascuno. Prima era un solo listener
  `PLAINTEXT` annunciato come `kafka:9092` a tutti, compreso l'host — la causa
  esatta di P-1 (T0.6). Progression test dichiarato della release: **T0.6
  XFAIL → PASS** (P-1, O3.1, [#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16)).
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
