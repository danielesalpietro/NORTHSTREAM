# LOGBOOK — Fase 0: Baseline (pre-v0.0.1)

Memoria di fase secondo `CLAUDE.md` §4. Solo append; ultima entry = punto di
ripartenza della sessione successiva. La fase si chiude con la entry "ESITO FASE"
quando il tag `v0.0.0-baseline` esiste e il branch `release/v0.0.1` è aperto.

---

## 2026-08-26 — sessione remota (senza ambiente di esecuzione Docker) — Claude Code, supervisione con owner

- **Obiettivo della sessione**: riavvio del progetto dopo 51 giorni di fermo:
  fotografare lo stato, individuare i limiti, definire il percorso e le regole
  perché nessuna sessione futura riparta da zero.
- **Fatto** (branch `claude/project-plan-review-473nje`, base `develop@5eb456a`):
  - Project Plan Review preliminare (artifact per l'owner; poi superata dalla review formale).
  - `docs/review_tecnica.md` (commit `3d147a1`) — review critica di sola lettura:
    2 BLOCKER (P-1 Kafka irraggiungibile dall'host ma pubblicizzato `localhost:9092`;
    P-2 `./trino/catalog` inesistente), 7 MAJOR (tra cui A-1 retrieval keyword
    mascherato da semantico, A-2 contesto stantio, A-3 collisioni point-id,
    P-3 immagine Kafka `bitnamilegacy` congelata), serie di MINOR; decisioni
    contestate con alternative pro/contro. Pubblicata come issue #2.
  - `docs/piano_ricovero.md` (commit `415b720`) — piano verso v0.1.0-beta1:
    obiettivi O1–O7, ambienti ENV-L (laptop 5080) / ENV-W (Z8+3090) / ENV-R
    (RunPod, solo carichi GPU single-image finché RP-0 non prova il contrario),
    suite T0 (12 test, semantica PASS/XFAIL con progression test per release),
    EVAL deterministica, soak 24h, CI a tre livelli, runbook di recupero output
    dai pod (checksum prima dello spegnimento).
  - `CLAUDE.md`, `CHANGELOG.md`, questo logbook — direttive di sessione e avvio
    della disciplina documentale.
- **Decisioni prese**:
  - Storyline README da **accorciare** alla parte vera, non da costruire (review §4.4).
  - Niente PR flow fino al secondo contributor: la rete di sicurezza è la CI con
    smoke test (review §4.5) — contraddice l'handoff iniziale, motivato.
  - Boost keyword su `KNOWN_SITES`: si rimuove in v0.0.4 a favore del filtro
    payload Qdrant (site+timestamp); fino ad allora resta e va solo dichiarato.
  - Issue #1 (Norimberga/MoE): premessa imprecisa (il tier Optimal è già MoE);
    decisione GO/NO-GO rimandata ai numeri della matrice EVAL (piano §4.2).
  - Scenografia (Flink, Iceberg, metastore MinIO, K8s) congelata fino a dopo beta1.
- **Test eseguiti**: nessuno — sessione senza ambiente Docker; tutti i finding
  comportamentali sono analisi statica da confermare col primo run T0 (dichiarato
  nella review §6).
- **Non funziona / sospeso**: tag `v0.0.0-baseline` non ancora creato; harness
  `bench/` inesistente; RP-0 (probe DinD RunPod) non eseguito; branch di sessione
  non ancora mergiato in `develop`.
- **Prossimo passo per la sessione successiva**: su una macchina con Docker
  (ENV-L o ENV-W): (1) tag `v0.0.0-baseline` su `5eb456a` + push del tag;
  (2) branch `release/v0.0.1` da `develop`; (3) implementare `bench/t0/` +
  mock-ollama + workflow CI come da piano §5; (4) primo run T0 contro la baseline
  e commit di `docs/runs/<RUN_ID>-baseline.md`; (5) merge del branch di sessione
  (review + piano + direttive) dentro `release/v0.0.1`.
- **Decisioni richieste all'owner**: nessuna bloccante. Facoltative: conferma del
  nome cartella archivio locale (`~/NORTHSTREAM-archive/`) e dell'account RunPod
  da usare per RP-0.
