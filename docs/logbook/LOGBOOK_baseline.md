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

## 2026-08-26 (2ª entry) — sessione remota (senza ambiente Docker) — Claude Code

- **Obiettivo della sessione**: strutturare su GitHub tutte le fasi di sviluppo
  come issue tracciabili, collegate al nuovo Project dell'owner.
- **Fatto**:
  - Create 6 issue di fase: #3 (Fase 0 → v0.0.1), #4 (Fase 1 → v0.0.2),
    #5 (Fase 2 → v0.0.3), #6 (Fase 3 → v0.0.4), #7 (Fase 4 → v0.0.5),
    #8 (Fase 5 → v0.1.0-beta1), ciascuna con gate di chiusura e regola del
    train ("la fase N non si apre finché la N−1 non è taggata").
  - Create 30 sub-issue collegate ai parent: #9–#15 (Fase 0), #16–#20 (Fase 1),
    #21–#24 (Fase 2), #25–#30 (Fase 3), #31–#33 (Fase 4), #34–#38 (Fase 5).
    Ogni sub-issue cita finding chiusi e progression test (XFAIL→PASS).
  - Aggiornata tabella "Stato corrente" di CLAUDE.md con il tracking fasi.
- **Decisioni prese**: la struttura rispecchia 1:1 la tabella release del piano
  (§6); l'aggiunta delle issue al Project board non è automatizzabile dagli
  strumenti disponibili in sessione → va fatta dall'owner o con il workflow
  auto-add del Project.
- **Test eseguiti**: nessuno (sessione senza Docker, lavoro solo issue/docs).
- **Non funziona / sospeso**: invariato dalla entry precedente (tag baseline,
  harness, RP-0, merge branch sessione).
- **Prossimo passo per la sessione successiva**: eseguire la Fase 0 nell'ordine
  delle sub-issue: #9 (tag+merge) → #10 (collaudo in macchina) → #11 (harness)
  → #12 (CI) → #13 (run baseline) → #14 (fix documentali) → #15 (release v0.0.1).
- **Decisioni richieste all'owner**: abilitare l'auto-add del Project (o
  aggiungere manualmente #3–#38 al board) e, se gradito, configurare le colonne
  per fase.

## 2026-08-26 (3ª entry) — sessione remota (ENV: nessuno — niente demone Docker) — Claude Code, sessione operativa Fase 0

- **Obiettivo della sessione**: eseguire le sub-issue #9, #11, #12, #14 della
  Fase 0: tag baseline e apertura di `release/v0.0.1`, harness `bench/t0/`,
  workflow CI, fix documentali O2.
- **Vincolo d'ambiente dichiarato** (CLAUDE.md §5): questa sessione **non ha un
  demone Docker** (`docker info` → `dial unix /var/run/docker.sock: no such
  file`). Il CLI `docker` c'è, quindi `docker compose config` è eseguibile, ma
  nessun container può essere avviato in locale. Tutto ciò che richiede lo stack
  acceso è stato verificato **sulla CI GitHub-hosted**, non dichiarato a memoria.
- **Fatto** (branch `release/v0.0.1`, creato da `develop@5eb456a`):
  - Tag annotato `v0.0.0-baseline` su `5eb456a` creato in locale. **Il push del
    tag è stato rifiutato**: `HTTP 403` dal proxy git della sessione remota, a
    fronte di push di branch che invece funzionano. Riprovato due volte, stesso
    esito → è una restrizione dell'ambiente, non un errore transitorio.
    **Decisione richiesta all'owner**, sotto.
  - `0067d37` — merge di `claude/project-plan-review-473nje` in `release/v0.0.1`
    (review, piano, CLAUDE.md, CHANGELOG, logbook: sola documentazione).
  - `b7c13ed` — harness `bench/t0/` (#11): 12 test script indipendenti
    dall'ordine, `run.sh --suite ci|static|core|full`, valori sentinella fissi
    (77.31, 91.73, Depot-9/93.17), JSON per test, `manifest.json` + `summary.md`
    per run, attese in `expected/baseline.json` e `expected/current.json`,
    semantica PASS/XFAIL/FAIL/XPASS/SKIP. Il linter T0.12
    (`lib/doc_truth.py`) è anche standalone. `bench/ci/mock-ollama` sostituisce
    Ollama con uno stub deterministico (embedding da hash, echo del contesto).
  - `977dc63` — workflow `ci-static`, `ci-smoke`, `ci-nightly` (#12).
  - `531aa47` — fix documentali O2 (#14): storyline accorciata + tabella
    "Layer status", endpoint `localhost:9092` rimosso dalla tabella servizi,
    layout allineato al reale, License = MIT, doppio header Granite, placeholder
    di clone, sezione "How the retrieval really works" nel demo-script,
    `.env` → `.env.example` + `.gitignore`.
  - `5762546` — fix di due difetti del harness trovati dal primo run reale di
    ci-smoke (v. "Test eseguiti").
- **Decisioni prese**:
  - **T0.12 più severo di quanto scritto nel piano**: oltre ai tre controlli
    (a) layout, (b) endpoint, (c) License, il linter verifica anche gli header
    di tabella duplicati e i placeholder residui. Motivo: il piano chiede che
    ogni fix abbia un test di riscontro, e i due difetti puntuali di D-2 non ne
    avrebbero avuto uno. Documentato in `bench/README.md`.
  - **Endpoint Kafka: rimosso, non corretto.** In tabella servizi resta
    `kafka:9092` (in-network) con una nota che spiega perché l'host non lo usa.
    Il doppio listener è di v0.0.2 (O3.1): anticiparlo qui avrebbe cambiato il
    comportamento del sistema in una release che deve solo misurarlo.
  - **Servizi CI elencati per nome invece dei profili compose.** Lo scheletro
    del piano (§5) usa `--profile core`, ma i profili arrivano in v0.0.3:
    elencare i servizi nel workflow ottiene lo stesso risultato senza toccare i
    compose file in questa release.
  - **`expected/` diviso in due file** (`baseline.json`, `current.json`): le
    attese non sono una proprietà del harness ma del target misurato. Un run
    contro il tag baseline usa `baseline.json`; il branch di release usa
    `current.json`, che differisce solo per T0.12 (il progression test dichiarato).
  - **`ci-nightly` dormiente**: `if: vars.RUN_NIGHTLY == 'true' || dispatch`.
    Senza il runner self-hosted lo schedule accumulerebbe run che nessuno può
    servire. Si accende registrando il runner e la variabile.
  - **`demo-script.md` resta in inglese** benché stia in `docs/`: è
    documentazione d'uso pubblica, già in inglese, e mescolare le lingue dentro
    un documento presentato al cliente sarebbe peggio della regola violata.
- **Test eseguiti**:
  - `bench/t0/run.sh --suite static --expected expected/baseline.json`
    (locale, senza Docker) → **T0.1 PASS** (3/3 combinazioni compose valide),
    **T0.12 XFAIL** (12 violazioni: 8 path inesistenti, endpoint 9092, License,
    header duplicato, placeholder). È la misura della baseline documentale.
  - `bench/t0/run.sh --suite static` (dopo i fix #14) → **T0.1 PASS,
    T0.12 PASS**: il progression test dichiarato per v0.0.1 è flippato.
  - `docker compose config` prima/dopo la pulizia degli spazi nel compose e
    prima/dopo la rimozione di `.env` dal tracking → **output byte-identico**
    in entrambi i casi: nessun cambio di comportamento runtime in v0.0.1.
  - Stub mock-ollama avviato in locale con python → vettori 384-dim
    deterministici e normalizzati, `/api/generate` che restituisce il contesto.
  - **CI `ci-static`**: **verde** dal secondo run in poi. Il primo era rosso
    *solo* sullo step T0.12 (prima dei fix #14): yamllint, ruff, i tre hadolint
    e il syntax check passavano già. Quindi la CI ha visto il flip XFAIL→PASS
    di T0.12 esattamente come la verifica locale.
  - **CI `ci-smoke`** (run `33006019554`, prima esecuzione reale dello stack CDC
    su runner GitHub con mock-ollama) — **primi esiti misurati del progetto**:

    | Test | Esito | Nota |
    |---|---|---|
    | T0.1 | PASS (0s) | 3/3 combinazioni compose |
    | T0.2 | FAIL (420s) | `not reachable within 420s: kafka` — **difetto del harness** |
    | T0.3 | FAIL (5s) | sentinella 77.31 non vista — **stesso difetto del harness** |
    | T0.4 | PASS (1s) | `agent buffered the sentinel in 0s` |
    | T0.8 | XFAIL (41s) | `count grew by only 3 after restart: points are being overwritten` |
    | T0.11 | XFAIL (10s) | `/health still reports ok with qdrant down` |

    Lettura: **T0.4 verde con T0.3 rosso** è la firma del fatto che la pipeline
    CDC funziona (l'evento sentinella arriva davvero all'agent) e che a fallire
    erano le due probe che entrano nel container Kafka. **A-3 e A-5 della review
    sono ora misurati, non più dedotti**: erano deduzioni statiche (review §6),
    adesso hanno un output osservato.
- **Non funziona / sospeso**:
  - **Secondo difetto del harness trovato e corretto** (`f62bcbc`): T0.2 e T0.3
    entravano nel container Kafka con `bash -lc`. La login shell ricostruisce il
    `PATH` e perde `/opt/bitnami/kafka/bin`, quindi `kafka-topics.sh` e
    `kafka-console-consumer.sh` risultavano inesistenti. L'healthcheck del
    compose usa `sh -c` e infatti passava: ora le probe fanno lo stesso, e T0.3
    conserva lo stderr del consumer così un prossimo fallimento dirà *perché*.
    Aggiunti budget espliciti in ci-smoke (stack 240 s, index 180 s, per-test
    300 s): nel run rotto un singolo test bruciava 420 s dei 25 minuti di job.
  - **Primo difetto del harness trovato e corretto** (`5762546`): T0.3 usava
    `kafka-console-consumer --timeout-ms`, che scade solo dopo N ms *senza
    messaggi*; col generatore che inserisce ogni 3 s un messaggio arriva sempre,
    quindi il consumer non usciva mai. Ora il consumer è limitato dall'orologio
    e ogni test gira sotto `timeout` (`NS_TEST_TIMEOUT`, default 600 s): un test
    bloccato diventa un KO con durata registrata, non un job che muore al limite
    della CI.
  - Tag `v0.0.0-baseline` **non pubblicato** (403, v. sopra).
  - Suite T0 completa con modelli reali: **mai eseguita** — richiede ENV-L/ENV-W
    (issue #13). Nessun esito di T0.5, T0.6, T0.7, T0.9, T0.10 è stato osservato:
    le attese in `expected/` restano dichiarazioni del piano, non misure.
  - `docs/runs/` conterrà il primo report vero solo dopo il run baseline (#13).
- **Prossimo passo per la sessione successiva**: su ENV-L o ENV-W eseguire
  `bench/t0/run.sh --suite full --repo <checkout del tag baseline> --expected
  bench/t0/expected/baseline.json --env envl` e committare
  `docs/runs/<RUN_ID>-baseline.md` (issue #13); poi #15 per il tag `v0.0.1`.
- **Decisioni richieste all'owner**:
  1. **Push del tag `v0.0.0-baseline`** (issue #9): la sessione remota riceve
     `HTTP 403` sui push di tag. Il tag esiste solo in locale qui, quindi va
     ricreato e pushato dall'owner:
     `git tag -a v0.0.0-baseline 5eb456a -m "..." && git push origin v0.0.0-baseline`.
     Finché non è pubblicato, il punto di riferimento del piano non esiste per
     chiunque non sia questa macchina.
  2. **Runner self-hosted su ENV-W** + variabile di repository `RUN_NIGHTLY=true`
     per attivare `ci-nightly` (issue #12).
  3. Conferma che `release/v0.0.1` resti aperto fino al run baseline (#13):
     questa sessione **non** ha taggato v0.0.1, come da scope.
