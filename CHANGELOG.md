# Changelog — NORTHSTREAM

Formato: [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) ·
Versioning: [SemVer](https://semver.org/lang/it/), release train definito in
[`docs/piano_ricovero.md`](docs/piano_ricovero.md) §6.

Regola (da `CLAUDE.md` §4): ogni commit che cambia comportamento aggiunge una riga
sotto `[Unreleased]` citando il finding o l'obiettivo che chiude; al rilascio la
sezione prende versione e data, e ogni riga deve avere il suo test di riscontro.

## [Unreleased]

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
- `.yamllint.yml` — configurazione del linter YAML usata da ci-static.
- `.gitignore` — esclude `results/` (gli output grezzi dei run non stanno nel repo).
- `docs/review_tecnica.md` — review tecnica critica della baseline (issue #2).
- `docs/piano_ricovero.md` — piano di ricovero verso v0.1.0-beta1 (O1–O7, suite T0/EVAL/soak, release train).
- `CLAUDE.md` — direttive vincolanti di onboarding e chiusura per ogni sessione (O1.2, anti-dispersione memoria).
- `CHANGELOG.md`, `docs/logbook/LOGBOOK_baseline.md` — avvio della disciplina documentale per fase.

### Fixed
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
