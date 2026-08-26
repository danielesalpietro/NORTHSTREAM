# Changelog — NORTHSTREAM

Formato: [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) ·
Versioning: [SemVer](https://semver.org/lang/it/), release train definito in
[`docs/piano_ricovero.md`](docs/piano_ricovero.md) §6.

Regola (da `CLAUDE.md` §4): ogni commit che cambia comportamento aggiunge una riga
sotto `[Unreleased]` citando il finding o l'obiettivo che chiude; al rilascio la
sezione prende versione e data, e ogni riga deve avere il suo test di riscontro.

## [Unreleased]

### Added
- `docs/review_tecnica.md` — review tecnica critica della baseline (issue #2).
- `docs/piano_ricovero.md` — piano di ricovero verso v0.1.0-beta1 (O1–O7, suite T0/EVAL/soak, release train).
- `CLAUDE.md` — direttive vincolanti di onboarding e chiusura per ogni sessione (O1.2, anti-dispersione memoria).
- `CHANGELOG.md`, `docs/logbook/LOGBOOK_baseline.md` — avvio della disciplina documentale per fase.

*(Nessun cambiamento a codice o configurazione: il comportamento runtime è ancora
identico alla baseline `v0.0.0-baseline`.)*

## [v0.0.0-baseline] — 2026-07-06
Stato del branch `develop` @ `5eb456a` al momento dell'avvio del piano di ricovero:
stack compose (Kafka, Debezium, Postgres, Flink, Apicurio, MinIO, Trino,
OpenMetadata, Ollama, Open WebUI) + addon Stream Context Agent (Qdrant,
stream-agent, data-generator). Difetti noti censiti in `docs/review_tecnica.md`;
tag da apporre come prima azione della Fase 0 (v. `CLAUDE.md` §2).
