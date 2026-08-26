# LOGBOOK — Fase 0: Baseline (pre-v0.0.1)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.

---

## SINTESI DI FASE — aggiornata al 2026-08-26, 21:10 UTC

**Dove siamo**: Fase 0 quasi chiusa. Tag `v0.0.0-baseline` → `5eb456a` pubblicato.
Su `release/v0.0.1`: harness `bench/t0/` (12 test), tre workflow CI, fix
documentali. Restano #10 (collaudo in macchina) e #13 (run T0 con LLM veri) sulla
Z8, poi #15 (tag `v0.0.1`, azione dell'owner).

**Decisioni prese, con il perché**
- **Storyline README accorciata, non costruita**: i layer non collegati (Flink,
  Apicurio, MinIO, Trino, OpenMetadata) sono dichiarati tali invece di
  implementarli. Costruirli erano settimane per una pipeline vista tre minuti in
  demo; un diagramma con frecce inventate è un rischio reputazionale.
- **Niente PR flow, CI con smoke test al suo posto**: a bus factor 1 la review di
  sé stessi è cerimonia; i difetti reali (P-1, P-2) non si vedono in un diff, si
  vedono eseguendo. PR flow al secondo contributor.
- **Boost keyword su `KNOWN_SITES` resta fino a v0.0.4**, solo dichiarato nel
  demo-script: rimuoverlo prima romperebbe la demo senza il sostituto pronto.
- **Scenografia congelata** fino a dopo v0.1.0-beta1.
- **Issue #1 (Norimberga/MoE)**: decisione rimandata ai numeri della matrice EVAL
  (Fase 5) — la premessa dell'issue era imprecisa, il tier Optimal è già MoE.
- **I tag di release sono un'azione locale**: le sessioni cloud hanno il push dei
  tag rifiutato dal proxy git (HTTP 403, verificato).
- **Le sessioni bridge (CLI locale) si raggiungono solo** via `create_trigger`
  con `persistent_session_id` + `fire_trigger`; non espongono `usage`.
- **P-5 (tier RAM) non è verificabile su ENV-W**: con 256 GB fisici le JVM
  auto-dimensionano l'heap, quindi i numeri sono un limite superiore non
  trasferibile. Serve ENV-L o `mem_limit` espliciti.

**Numeri misurati**
- Run verde `ci-smoke-33008193653`: 4 PASS + 2 XFAIL, zero FAIL.
- **A-3 e A-5 confermati per misura** (erano deduzioni statiche della review).
- **A-8 scoperto per misura**: l'agent resta cieco ai topic CDC per 4 min 46 s
  seguendo l'ordine documentato. Non era nella review. Issue #39, fix in v0.0.4.
- **T0.12 XFAIL → PASS**: è il progression test dichiarato per v0.0.1.
- Costo del processo finora: 81,6 M token letti da cache contro 310 mila
  generati (263:1), ~$103,81 nozionali. Il costo è rilettura, non generazione.
- Percorso di onboarding: 101 KB, ~28.800 token.

**Aperto**
- #10 e #13 in corso sulla Z8; #15 (tag `v0.0.1`) attende l'owner.
- RP-0 (probe DinD su RunPod) non eseguito.
- Runner self-hosted `env-w` e variabile `RUN_NIGHTLY` da configurare.
- Limite settimanale `claude-fable-5` esaurito fino al ~28/08.

**Prossimo passo**: alla consegna della Z8, verificare il gate di v0.0.1 e
chiedere all'owner il tag.

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

## 2026-08-26 (3ª entry) — supervisione (sessione remota) — Claude Code

- **Obiettivo della sessione**: attivare le sessioni operative della Fase 0 e
  coordinarle.
- **Fatto**:
  - Creata sessione cloud Fase 0 (`session_01GaPWBapF7LMthmjyPoC9Cd`) per
    #11/#12/#14. Ha eseguito metà di #9 (branch `release/v0.0.1` + merge
    documentazione, commit 0067d37) e si è poi **fermata per esaurimento
    crediti** (limite settimanale su claude-fable-5, reset ~2026-08-28).
    Non è un errore della sessione: il lavoro fatto è valido.
  - Ricreata come `session_01Tbs7yjoazhi7YsdwL2XY8Q` su claude-opus-5, stesso
    scope, con lo stato ereditato dichiarato nel prompt.
  - Assegnata la issue #10 alla sessione Claude CLI sulla Z8
    (`session_012WiW8ep5PVnGmm7exagMDu`, bridge): collaudo in macchina degli 8
    punti di misura + creazione del tag + eventuale runner self-hosted.
- **Decisioni prese**:
  - **Il tag `v0.0.0-baseline` non è creabile dalle sessioni cloud**: il proxy
    git dell'ambiente remoto rifiuta il push dei tag (HTTP 403, verificato).
    Delegato alla Z8. Regola generale: i tag di release li appone una sessione
    locale dell'owner, non le sessioni cloud.
  - Non esiste canale di messaging diretto verso le sessioni bridge: il modo
    funzionante è `create_trigger` con `persistent_session_id` + `fire_trigger`
    (usato per l'assegnazione a ENV-W).
  - #9 risulta eseguita in ordine invertito (merge prima del tag): senza
    conseguenze, perché il tag punta al commit immutabile 5eb456a.
- **Test eseguiti**: nessuno (supervisione senza Docker).
- **Non funziona / sospeso**: tag ancora assente al momento di questa entry;
  `bench/` e `.github/` non ancora esistenti; RP-0 non eseguito.
- **Prossimo passo per la sessione successiva**: verificare il tag, poi #11/#12
  fino a CI verde; alla consegna del collaudo Z8, confrontare gli esiti con i
  finding della review e correggere `docs/review_tecnica.md` se smentiti.
- **Decisioni richieste all'owner**: (a) confermare il secondo runner
  self-hosted per NORTHSTREAM con label `env-w` (opzione A: non tocca il runner
  dell'altro repo); (b) sapere che il limite settimanale su fable-5 è esaurito
  fino al ~28/08: le sessioni vanno create su opus-5 o sonnet-5 nel frattempo.

## 2026-08-26 (4ª entry) — sessione remota (ENV: nessuno — niente demone Docker) — Claude Code, sessione operativa Fase 0

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

### Aggiornamento di chiusura (stessa sessione) — CI verde

- **Esito finale CI**: `ci-static` **verde** e `ci-smoke` **verde** sul commit
  `c3c517d` (run [33008193653](https://github.com/danielesalpietro/NORTHSTREAM/actions/runs/33008193653)):
  `{"PASS": 4, "XFAIL": 2}` → `RESULT: OK (no regression)`. Report committato in
  `docs/runs/ci-smoke-33008193653.md`; il run rosso iniziale resta documentato in
  `docs/runs/ci-smoke-33006019554.md` perché contiene le prime misure di A-3/A-5.
  Definition of done della issue #12 raggiunta: entrambi i workflow verdi.
- **Terzo difetto corretto** (`c3c517d`), questa volta **non** del harness:
  con la suite finalmente veloce è emerso che lo `stream-agent` non vede i topic
  creati dopo la propria iscrizione per pattern, perché `kafka-python` rinfresca
  i metadata ogni 5 minuti (`metadata_max_age_ms` di default). Misurato in CI:
  **4 min 46 s** tra registrazione del connettore e primo evento osservato
  dall'agent. Nei run precedenti era mascherato dai 420 s che T0.2 sprecava.
  In v0.0.1 **non si tocca il comportamento**: ci-smoke aspetta esplicitamente il
  primo evento prima di asserire sulla freschezza, e la misura è registrata.
- **Nuovo finding proposto (decisione all'owner)**: il ritardo di scoperta topic
  colpisce anche la demo dal vivo, perché README e `docs/demo-script.md`
  prescrivono proprio l'ordine "stack su → registra connettore": chi segue le
  istruzioni può vedere `/events` vuoto per minuti e concludere che la pipeline
  non funzioni. Non è nella lista della review (§3.2 non lo cita). Proposta:
  aprirlo come finding A-8 e trattarlo in Fase 3 insieme ad A-4, con rimedio
  `metadata_max_age_ms` basso o iscrizione esplicita ai topic con retry.
  **Non implementato in questa sessione**: fuori dallo scope di v0.0.1.
- **Nota metodologica per le sessioni remote**: in questo ambiente i `sleep` in
  background **non consumano tempo reale** (10 sleep da ~500 s sono passati in
  ~15 minuti di orologio). Per attendere davvero la CI serve un'attesa in
  foreground (`python3 -c "import time; time.sleep(N)"`, verificata con `date`).
  Chi riprende il lavoro da una sessione remota non si fidi dei timer in background.

### Aggiornamento (stessa sessione) — A-8 accettato, mitigazione documentale

- **Preso dal branch di sessione** (merge `dddbfe4`): policy di accesso a ENV-W,
  canale di esecuzione sulla Z8, entry di supervisione, nota sulle misure RAM non
  trasferibili ai tier, regola "una sola sessione per scope", e soprattutto
  `5f8ba96` che formalizza **A-8 [MAJOR]** in `docs/review_tecnica.md` con la
  misura di questa sessione, marcando **A-3 e A-5 come confermati da misura**.
  Conflitti risolti su `CLAUDE.md` (tabella §2: tenute le righe aggiornate di
  entrambe le sessioni) e su questo logbook (entry della supervisione messa in
  ordine cronologico prima della mia, che diventa la 4ª).
- **Tag `v0.0.0-baseline`: risolto, non da me.** `git ls-remote --tags origin` lo
  mostra su `5eb456a`: l'ha pubblicato la sessione ENV-W. Il blocco HTTP 403 che
  avevo segnalato nella issue #9 riguarda le sole sessioni cloud ed è ora una
  regola scritta in CLAUDE.md, non un problema aperto.
- **Mitigazione documentale di A-8** (scope #14, nessuna riga di codice toccata):
  README e `docs/demo-script.md` ora dichiarano il ritardo e prescrivono
  `docker restart northstream-stream-agent` subito dopo `register-connector.sh`,
  con l'alternativa (registrare il connettore prima di avviare l'addon) e il
  rimando a #39 per il fix vero in v0.0.4. Era dovuto sotto #14: finché il
  demo-script prescriveva un ordine che produce una demo apparentemente rotta,
  conteneva un claim non coperto dal comportamento reale.
- **Test eseguiti dopo la modifica**: `bench/t0/run.sh --suite static` →
  T0.1 PASS, T0.12 PASS (la verità documentale regge anche con le nuove sezioni);
  ci-static e ci-smoke verdi sul commit finale.
- **Nota per la sessione ENV-W (#10/#13)**: gli attesi XFAIL di T0.6 (P-1),
  T0.7 (P-2) e la nota P-6 restano **dichiarazioni del piano**, non misure. Se il
  collaudo in macchina ne smentisce uno, l'atteso corrispondente in
  `bench/t0/expected/baseline.json` va corretto **prima** del run di riferimento,
  altrimenti il report registra un XPASS che è solo un'attesa sbagliata. P-5
  (tier RAM) resta fuori portata anche dalla Z8: non costruirci asserzioni.
- **Nota git per chi condivide `release/v0.0.1`**: `git pull --rebase` con un
  **merge commit** nella storia locale non lo preserva — lo appiattisce e
  ririproduce uno per uno i commit del branch mergiato, riaprendo conflitti già
  risolti (successo qui col merge `dddbfe4`). Il rebase è stato annullato senza
  danni (il push aveva già pubblicato il ref corretto, `a6a81a0`). Regola pratica
  per le sessioni che si alternano su questo branch: `git fetch` prima, e **solo
  se** il remoto è davvero avanti integrare con `git merge` (o `pull --rebase
  --rebase-merges`); mai un rebase alla cieca quando la propria storia contiene
  merge.

## 2026-08-26 (5ª entry) — supervisione (sessione remota) — Claude Code

- **Obiettivo della sessione**: coordinare le due sessioni operative fino alla
  consegna, e registrare per la prima volta il **costo del processo** in token.
- **Fatto**:
  - Accettato e formalizzato il finding **A-8** proposto dalla sessione Fase 0
    (agent cieco ai topic CDC per ~5 min seguendo l'ordine documentato, misurato
    a 4m46s); aperta la issue #39 sotto la Fase 3 con progression test T0.13;
    marcati **A-3 e A-5 come confermati da misura** (commit `5f8ba96`).
  - Chiusa la issue #9 (tag `v0.0.0-baseline` creato dall'owner).
  - Gestita la morte della sessione Z8 per timeout SSH e l'allineamento della
    sostitutiva (`session_01DgGUpEVwGvHnPVNWZ4jPgr`) sullo stato reale.
  - `CLAUDE.md`: regola tmux per ENV-W, §3.8 una-sola-sessione-per-scope, §7
    politica di scelta del modello ed economia dei token.
- **Costo del processo — prima misurazione** (dati da `get_session`, prezzi di
  listino API; l'owner è su abbonamento **MAX**, quindi il denaro è nozionale:
  la valuta scarsa sono i **rate limit**):

  | Sessione | Modello | Durata | Cache read | Output | Costo nozionale |
  |---|---|---|---|---|---|
  | Supervisione | opus-5 | 3h15 | 16,1 M | 99.915 | $54,10 |
  | Fase 0 cloud (#11/#12/#14) | fable-5 → opus-5 | 1h30 | 63,1 M | 181.315 | $45,84 |
  | └ di cui parte fable-5 | fable-5 | ~10 min | 1,3 M | 23.876 | $6,41 |
  | Duplicato archiviato | opus-5 | 7 min | 2,4 M | 28.793 | $3,88 |
  | Z8 / ENV-W (2 sessioni) | opus-5 | ~1h40 | — | — | non esposto |
  | **Totale misurabile** | | | **81,6 M** | **310.023** | **$103,81** |

- **Decisioni prese / cose imparate dai numeri**:
  1. **Il costo è rilettura, non generazione**: 81,6 M di token letti dalla cache
     contro 310 mila generati — rapporto 263 a 1. Ottimizzare la lunghezza delle
     conversazioni vale molto più che scegliere un modello più economico.
  2. **La sessione Fase 0 ha letto 63,1 M in un'ora e mezza**, contro i 16,1 M
     della supervisione in tre ore e un quarto: quasi quattro volte tanto in metà
     tempo, perché è rimasta viva attraverso sette cicli di CI con output di tool
     voluminosi. Da qui la regola §7.3: dopo un push che innesca la CI si chiude
     il turno, non si aspetta dentro la sessione.
  3. **Il duplicato è costato $3,88 senza produrre nulla** — errore di
     supervisione che ha generato la regola §3.8.
  4. **fable-5 ha bruciato $6,41 in dieci minuti** per creare un branch e fare un
     merge, poi ha esaurito il limite settimanale bloccando la sessione. Rapporto
     valore/consumo sfavorevole per lavoro meccanico: da qui la tabella §7.
  5. Le sessioni **bridge** (Claude CLI locale) non espongono `usage`: il consumo
     di ENV-W non è misurabile da remoto. Va annotato come tale, non stimato.
- **Test eseguiti**: nessuno (supervisione senza Docker).
- **Non funziona / sospeso**: #10 e #13 in corso sulla Z8; tag `v0.0.1` (#15) in
  attesa; RP-0 non eseguito; runner self-hosted e variabile `RUN_NIGHTLY` da
  configurare.
- **Prossimo passo per la sessione successiva**: alla consegna della Z8,
  verificare il gate di v0.0.1 e chiedere all'owner il tag.
- **Decisioni richieste all'owner**: nessuna nuova. Restano aperte: registrazione
  del runner self-hosted `env-w` e tag `v0.0.1` quando il gate è verde.
