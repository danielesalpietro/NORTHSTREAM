# Changelog — NORTHSTREAM

Formato: [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) ·
Versioning: [SemVer](https://semver.org/lang/it/), release train definito in
[`docs/piano_ricovero.md`](docs/piano_ricovero.md) §6.

Regola (da `CLAUDE.md` §4): ogni commit che cambia comportamento aggiunge una riga
sotto `[Unreleased]` citando il finding o l'obiettivo che chiude; al rilascio la
sezione prende versione e data, e ogni riga deve avere il suo test di riscontro.

## [Unreleased]

### Fixed
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
