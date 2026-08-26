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

## 2026-08-26 (5ª entry) — ENV-W (HP Z8 G4) — sessione `session_012WiW8ep5PVnGmm7exagMDu` — **ricostruita a posteriori**

> Entry scritta dalla sessione ENV-W successiva (`session_76a19823`, #10/#13) come
> impone `CLAUDE.md` §6: la sessione qui descritta è stata archiviata da un timeout
> della sessione SSH mentre attendeva un monitor, senza completare la checklist di
> chiusura. Ricostruzione da: tag pubblicato su origin, stato della macchina
> (container, worktree, immagini, modelli), log lasciati in `/tmp` e trascritto
> della sessione. **Nessun commit** è stato prodotto da quella sessione: l'unico
> artefatto durevole è il tag.

- **Obiettivo della sessione**: #10 (collaudo in macchina) + apposizione del tag
  `v0.0.0-baseline`, primo accesso reale a un demone Docker del progetto.
- **Fatto** (nessuno SHA di commit: non ha committato nulla):
  - **Tag `v0.0.0-baseline` creato in locale** su `5eb456a` (annotato, poi
    ri-taggato col messaggio indicato dalla supervisione: "Baseline: stato di
    develop all'avvio del piano di ricovero"). **Il push è fallito**, due volte:
    `fatal: could not read Username for 'https://github.com'` (exit 128). La
    sessione ha mandato una notifica push all'owner e non è mai tornata.
  - **Correzione a un'attribuzione della 4ª entry.** Lì si legge che il tag su
    origin "l'ha pubblicato la sessione ENV-W": non è così. Il tag che oggi esiste
    su `origin` è **lightweight** e porta la firma dell'owner
    (`DanieleS <59105724+danielesalpietro@users.noreply.github.com>`), mentre
    quello locale su ENV-W è **annotato** con tagger `Daniele Salpietro`. Stesso
    commit (`5eb456a`), quindi la baseline non è ambigua nei contenuti; ma
    l'oggetto tag è diverso e chi lo ha pubblicato è l'owner, non una sessione.
    O1.1 è comunque soddisfatto.
  - Checkout di lavoro su `/home/admin/claude/NORTHSTREAM` (branch
    `claude/project-plan-review-473nje`) + due worktree, impostazione che questa
    sessione ha ereditato e mantenuto:
    `ns-baseline/` detached su `v0.0.0-baseline` (**sistema sotto test**) e
    `ns-harness/` su `release/v0.0.1` (**harness**).
  - Verificato per diff che fra `5eb456a` e `release/v0.0.1` il runtime non cambia:
    `docker-compose-northstream-ai.yml` differisce solo per spazi bianchi, l'unica
    altra modifica è `.env` → `.env.example` con default identici.
  - Stack avviato **dal working tree byte-identico alla baseline**: base
    19:37:28Z → ~19:57Z (≈20 min, quasi tutti di pull delle 16 immagini);
    addon+GPU 20:10:16Z → 20:13Z (build delle due immagini locali).
    Passthrough GPU verificato con `nvidia-smi` dentro il container Ollama.
  - Modelli scaricati: `granite4:1b` e `granite-embedding:30m` (20:26Z → ~20:32Z).
  - Sonda su 13 endpoint dall'host: tutti rispondenti.
- **Decisioni prese**:
  - `--expected baseline.json` (non `current.json`) per il run contro il tag:
    `current.json` attende `T0.12 PASS`, che è la progression di v0.0.1, non della
    baseline. Decisione mantenuta e usata dal run di riferimento (#13).
  - Non toccare i permessi dei file per aggirare il difetto trovato (v. sotto):
    ha eseguito gli script con `bash <script>`, lasciando il working tree pulito.
- **Test eseguiti**:
  - `docker compose config -q` sulle 3 combinazioni (base; +addon; +addon+gpu) →
    **exit 0 su tutte e tre** (equivalente manuale di T0.1 PASS).
  - Nessun test del harness: la sessione si è interrotta prima.
- **Non funziona / sospeso**:
  - **Nuovo difetto misurato, non presente nella review**: `start-addon.sh`,
    `register-connector.sh` e `demo-compare.sh` sono **`100644` in git**, quindi
    su un clone pulito i comandi documentati `./start-addon.sh` e
    `./register-connector.sh` falliscono con "Permission denied". Verificato da
    questa sessione: `git ls-files -s` → `100644` per i tre script (e `100755`
    per `bench/t0/run.sh`, che invece è corretto). Proposto come finding **P-9**
    (v. 6ª entry).
  - **Connettore CDC non registrato**: l'ultimo comando della sessione è stato
    `bash register-connector.sh`, ma alle 20:47Z `GET /connectors` rispondeva `[]`
    e Kafka non aveva alcun topic `northstream.*`. La registrazione non è andata a
    buon fine (o non è mai partita): la sessione è morta lì.
  - **Push impossibile da ENV-W**: nessuna credenziale HTTPS, `gh` non
    autenticato, chiave SSH non abilitata su GitHub
    (`git@github.com: Permission denied (publickey)`). È lo stesso blocco che ha
    fermato anche la 6ª entry.
  - Nessuna entry di logbook, nessun `docs/runs/`, nessun archivio: checklist §6
    non eseguita.
- **Prossimo passo per la sessione successiva**: registrare il connettore e
  proseguire con #10 e #13 — fatto nella 6ª entry.

## 2026-08-26 (6ª entry) — ENV-W (HP Z8 G4) — Claude Code, sessione operativa #10 + #13

- **Obiettivo della sessione**: trasformare in misure i finding che la review aveva
  dedotto leggendo il codice (issue #10) ed eseguire il **run T0 di riferimento
  contro il tag `v0.0.0-baseline`** (issue #13). Prima sessione del progetto con un
  demone Docker vero *e* modelli veri.

- **Fatto** (commit `111665a` per #10, `1f77c67` per #13, più un terzo che
  registra questi SHA nel logbook):
  - Ricostruita e scritta la 5ª entry, mancante, della sessione ENV-W archiviata dal
    timeout SSH (`CLAUDE.md` §6). Aveva prodotto un solo artefatto durevole — il tag
    `v0.0.0-baseline` — e lasciato il connettore CDC **non** registrato.
  - Registrato il connettore Debezium (`bash register-connector.sh`, stato
    `RUNNING`/task 0 `RUNNING`) e completato il collaudo di #10.
  - Due run T0 archiviati secondo `docs/piano_ricovero.md` §3, con `SHA256SUMS`
    generato e copia verificata in `~/NORTHSTREAM-archive/`:
    - `20260826-2049-envw-659236a` — suite `core` contro `release/v0.0.1`
      (`docs/runs/20260826-2049-envw-659236a.md`): **6 PASS + 4 XFAIL**.
    - `20260826-2053-envw-5eb456a` — suite `full` contro il tag baseline
      (`docs/runs/20260826-2053-envw-5eb456a-baseline.md`): **5 PASS + 6 XFAIL +
      1 XPASS**, `RESULT: OK (no regression)`. **È il metro di O1.3.**
  - **O1.2 verificato sul campo**: dopo il run contro il tag,
    `git -C ns-baseline status --porcelain` è vuoto e `HEAD` è ancora `5eb456a`.
    Il harness misura il checkout del tag senza modificarlo.

- **Collaudo #10 — tabella confermato / smentito** (comandi e output completi nei
  grezzi archiviati e nei due report in `docs/runs/`):

  | Finding | Atteso | Comando eseguito | Osservato | Esito |
  |---|---|---|---|---|
  | **P-1** Kafka dall'host | confermato | `docker run --rm --network host edenhill/kcat:1.7.1 -b localhost:9092 -L` e `... -C -t connect_configs -c 1 -e` | i metadata *arrivano* (`1 brokers: broker 1 at kafka:9092`), ma il consumo reale muore su `Failed to resolve 'kafka:9092': Name does not resolve`; `getent hosts kafka` non risolve. Controprova dentro la rete Docker: stesso comando, OK | **Confermato** (con precisazione: non è un timeout, è un indirizzo annunciato inutilizzabile) |
  | **P-2** Trino senza cataloghi | confermato | `docker exec northstream-trino trino --execute "SHOW CATALOGS"` | solo `"system"`; `SELECT count(*) FROM postgresql.public.orders` → `Catalog 'postgresql' not found`; `./trino/catalog` esiste sull'host **creata vuota da Docker**, `root:root`, alle 19:53 (primo `up`), e non è tracciata in git né sulla baseline né su `release/v0.0.1` | **Confermato**, incluso il dettaglio della directory creata da Docker |
  | **P-6** `vm.max_map_count` | da verificare su Linux nativo | `sysctl vm.max_map_count`; `docker logs northstream-elasticsearch`; `docker inspect` | `vm.max_map_count = 1048576`, impostato **in modo persistente dall'host** (`/etc/sysctl.d/10-map-count.conf`, non da Docker Desktop: qui non c'è). Elasticsearch `healthy`, `RestartCount=0`, nessuna riga di bootstrap check nei log; OpenMetadata risponde `HTTP 200` | **Non riproducibile su questa macchina** — non "smentito": l'host arriva già configurato, quindi il difetto non è esercitabile qui. Serve un host Linux non preconfigurato (o abbassare temporaneamente il sysctl, fuori scope) |
  | **A-3** id sovrascritti | confermato in CI | T0.8 (harness) | `count grew by only 0 after restart` — su ENV-W con modelli veri, non col mock | **Confermato anche su ENV-W** |
  | **A-5** `/health` non fallisce | confermato in CI | T0.11 (harness) | `/health still reports ok with qdrant down` | **Confermato anche su ENV-W** |
  | **A-2** contesto stantio | dedotto | T0.9 (harness, `NS_RECENCY_SECONDS=300`) | dopo 300 s con generatore fermo il `context_used` contiene ancora l'anomalia invecchiata | **Confermato — prima misura del progetto** |
  | **A-8** ritardo scoperta topic | 4 min 46 s in CI | registrazione connettore alle 20:48:13Z + polling di `/events` ogni 5 s | topic CDC creati entro 1 s; **primo evento in `/events` dopo 8 s** | **Confermato nel meccanismo, magnitudo diversa: v. sotto** |
  | **A-1** retrieval non semantico | XFAIL atteso | T0.10 (harness) + 3 riesecuzioni | `context_used` contiene l'evento `Depot-9` in prima posizione, 3/3 stabile → **XPASS** | **Parzialmente smentito: v. sotto** |
  | **P-5** tier RAM | fuori portata da ENV-W | `docker stats --no-stream` | 19 container, **9 748 MiB ≈ 9,52 GiB** RSS totale + 6 517 MiB di VRAM | **Resta aperto**: la misura non lo verifica |
  | **T0.2–T0.5** stack, CDC, buffer, `/compare` | PASS | harness, suite `core` e `full` | tutti **PASS**; T0.5 verde **al primo tentativo** senza usare il retry tollerato dal piano §4.1 | **Confermati PASS con modelli veri** |

- **Decisioni prese**:
  - **Non ho riavviato lo stack**: era già su dalla sessione precedente, avviato da un
    working tree il cui runtime è byte-identico a `5eb456a` (diff verificato: tocca solo
    `CHANGELOG.md`, `CLAUDE.md`, `docs/`). Rifarlo avrebbe bruciato ~25 minuti per
    misurare lo stesso identico sistema. Costo: T0.2 misura la raggiungibilità (2 s),
    non il tempo di boot — che resta quello ricostruito nella 5ª entry (base ≈ 20 min
    con i pull, addon ≈ 3 min).
  - **Ho misurato A-8 invece di aggirarlo** con il `docker restart` prescritto dal
    README. Serviva una seconda misura indipendente, e l'ha data — con un esito
    inatteso, v. sotto.
  - **Non ho toccato `expected/baseline.json`.** Nessun finding è stato smentito
    *prima* del run, quindi non c'era attesa da correggere in anticipo. L'unico
    scostamento (T0.10) è emerso *dal* run: metterlo a `PASS` a posteriori
    cristallizzerebbe nel metro di riferimento l'idea che la baseline gestisca i siti
    fuori `KNOWN_SITES`, che è esattamente ciò che il run **non** dimostra.
  - **`NS_RECENCY_SECONDS=300`** (invece di 900) per il primo giro, dichiarato nel
    report: T0.9 dimostra che il contesto conserva eventi più vecchi di 5 minuti, non
    di 15. Asserzione più debole, sufficiente al difetto. **`NS_TEST_TIMEOUT=900`**
    (invece di 600) perché altrimenti T0.9 non può proprio finire (v. sotto).
  - **Due report in `docs/runs/`, non uno.** `CLAUDE.md` §4 chiede un report per ogni
    run di test; il run di collaudo con modelli veri contro `release/v0.0.1` è la prima
    esecuzione di T0.5 del progetto e merita di restare agli atti.

- **Test eseguiti**: v. la tabella sopra e i due file in `docs/runs/`. In sintesi:
  `bench/t0/run.sh --suite core --env envw` → `{"PASS": 6, "XFAIL": 4}`;
  `bench/t0/run.sh --suite full --repo <worktree v0.0.0-baseline> --expected
  bench/t0/expected/baseline.json --env envw` → `{"PASS": 5, "XFAIL": 6, "XPASS": 1}`.
  Entrambi `RESULT: OK (no regression)`. Nessun PASS dell'ultimo run archiviato
  (`ci-smoke-33008193653`) è regredito.

- **Non funziona / sospeso**:
  - **A-8 misurato a 8 s, non a ~5 minuti — e il motivo conta.** `kafka-python` 2.0.2
    (verificato dentro il container) ha `metadata_max_age_ms = 300000`: l'agent
    rinfresca i metadata a intervalli fissi **a partire dal proprio avvio**, non dalla
    registrazione del connettore. Qui l'agent era su dalle 20:13:15.69Z, quindi i
    refresh cadevano a …20:43:15, **20:48:15**, 20:53:15; il connettore è stato
    registrato alle 20:48:13Z, **2,7 s prima di un refresh**, e il primo evento è
    comparso alle 20:48:19.99Z. Il ritardo di A-8 non è "circa 5 minuti": è una
    variabile **uniforme in [0, 5 min]**, il cui valore dipende da quanto manca al
    prossimo refresh. I 4 min 46 s misurati in CI sono il caso quasi-peggiore (agent
    appena avviato, connettore registrato subito dopo), non il caso tipico. La gravità
    pratica non cambia — chi segue il README può aspettare fino a 5 minuti — ma la
    formulazione del finding sì. **Proposta a #2**: sostituire "~5 minuti" con "fino a
    `metadata_max_age_ms` (default 5 min), a seconda della fase del refresh".
  - **XPASS su T0.10: A-1 è vero nel meccanismo, non nella conseguenza asserita.**
    `Depot-9` non è in `KNOWN_SITES` (verificato nel codice), quindi il boost keyword
    non contribuisce: il percorso esercitato è quello semantico puro, e ha funzionato,
    3 volte su 3. Ma la collection aveva **61 punti** contro i ~29 000/giorno stimati
    a regime, e con `top_k = 5` su 61 documenti un evento appena indicizzato che
    contiene la stringa `Depot-9` entra nei primi 5 senza bisogno di un embedding
    forte. Che la collection sia così piccola è a sua volta conseguenza di **A-3** (il
    restart dell'agent sovrascrive i punti: è il difetto che T0.8 misura). Quindi
    T0.10, com'è scritto, misura una proprietà **dipendente dalla dimensione del
    corpus**, non il difetto che dichiara di misurare. Segnalato a #11, non riparato:
    `bench/` è chiuso.
  - **Difetto del harness: T0.9 con i soli default non può finire.**
    `NS_RECENCY_SECONDS` vale 900 s e `NS_TEST_TIMEOUT` 600 s, quindi il test viene
    **sempre** ucciso dal `timeout` prima di poter asserire, e il run lo registra come
    KO — cioè come XFAIL "giusto" per il motivo sbagliato. Segnalato a #11.
  - **Difetto del harness: l'archiviazione §3 non è implementata.** `run.sh` non genera
    `SHA256SUMS` e il `manifest.json` non registra "versioni immagini/modelli" come
    richiede `docs/piano_ricovero.md` §3. Per questi due run li ho prodotti a fianco
    (`SHA256SUMS` + un `env.json` con host, kernel, CPU, GPU, versioni Docker, modelli
    Ollama e image id dei 19 container) **senza toccare `bench/`**. Segnalato a #11.
  - **Nuovo finding proposto: P-9 [MAJOR] — i comandi del README non sono eseguibili
    su un clone pulito.** `start-addon.sh`, `register-connector.sh` e `demo-compare.sh`
    sono `100644` in git (`git ls-files -s`), mentre `bench/t0/run.sh` è correttamente
    `100755`. Su un clone fresco `./start-addon.sh` fallisce con "Permission denied":
    è il **primo comando** del Quick Start. Trovato dalla sessione precedente,
    verificato qui. Non riparato: cambiare i modi è un cambiamento di comportamento
    documentato e appartiene a una release (candidato naturale: v0.0.2, insieme al
    preflight O3.4), non a una sessione di misura.
  - **ENV-W non può parlare con GitHub: né push né commenti.** `gh auth status` →
    "not logged into any GitHub hosts"; nessun token nell'ambiente;
    `git config credential.helper` vuoto; `ssh -T git@github.com` →
    `Permission denied (publickey)`. Di conseguenza
    `git push origin local/release-v0.0.1:release/v0.0.1` fallisce con
    `fatal: could not read Username for 'https://github.com'` (exit 128), esattamente
    come era successo alla sessione precedente col tag. **I due commit di questa
    sessione esistono solo sulla Z8** (`111665a` logbook, `1f77c67` report + §2, più il commit che aggiunge questi
    SHA, sul
    branch locale `local/release-v0.0.1` che traccia `origin/release/v0.0.1`), e i
    commenti alle issue #10 e #13 non sono stati postati. La ricostruzione a
    posteriori (§6 di `CLAUDE.md`) esiste proprio per questo caso: chi riprende
    trova qui lo stato, ma **finché l'owner non sblocca le credenziali su ENV-W il
    lavoro non è visibile a nessun'altra sessione**. È il blocco numero uno da
    risolvere: rende ENV-W un ambiente che misura ma non pubblica.
  - **P-6 non esercitabile qui** (v. tabella): serve un host Linux non preconfigurato.

- **Prossimo passo per la sessione successiva**: con il run di riferimento archiviato,
  la DoD di #13 è raggiunta e **#15 (tag `v0.0.1`) è sbloccata** — il CHANGELOG è già
  pronto sotto `[Unreleased]` e il progression test dichiarato (T0.12) è verde su
  `release/v0.0.1` e XFAIL sulla baseline, cioè esattamente il flip che la release
  dichiara. Prima del tag, decidere sui due punti aperti qui sotto.

- **Decisioni richieste all'owner**:
  1. **Sbloccare GitHub su ENV-W — prerequisito di tutto il resto.** Tre commit
     (`111665a`, `1f77c67` e la correzione degli SHA) sono pronti e non pushabili, e i commenti a #10 e #13
     non sono postabili. Basta un `gh auth login` sulla Z8 (che configura anche il
     credential helper per git), oppure una deploy key / un PAT in
     `~/.git-credentials`. Fino ad allora ENV-W misura ma non pubblica: qualunque
     sessione futura sulla Z8 sbatterà sullo stesso muro. In alternativa immediata:
     l'owner esegue `git -C ~/claude/ns-harness push origin
     local/release-v0.0.1:release/v0.0.1` dalla propria sessione sulla Z8.
     Le issue **non** sono state chiuse, come da direttiva.
  1-bis. **Allineare il tag `v0.0.0-baseline`**: su origin è lightweight, in locale
     su ENV-W è annotato (stesso commit). Se si vuole il tag annotato pubblico va
     ri-pubblicato dall'owner con `--force`; se va bene così, cancellare il tag
     locale divergente sulla Z8 per non confondere le sessioni future.
  2. **T0.10 / A-1**: l'XPASS del run di riferimento va sanato prima che qualcuno lo
     legga come "il retrieval funziona sui siti sconosciuti". Tre strade, in ordine di
     preferenza: (a) rafforzare T0.10 con una precondizione sulla dimensione della
     collection e/o distrattori iniettati (scope #11, riapre un file chiuso);
     (b) lasciarlo così e annotare l'XPASS come noto nel metro; (c) correggere la
     formulazione di A-1 in `docs/review_tecnica.md` (scope #2), che va comunque fatta
     perché la frase "l'embedding 30m non li ranka" non regge alla misura.
  3. **A-8, riformulazione del finding** in `docs/review_tecnica.md` (scope #2): da
     "~5 minuti" a "fino a `metadata_max_age_ms`, a seconda della fase del refresh",
     con le due misure indipendenti (4 min 46 s in CI, 8 s su ENV-W) come prova che è
     una variabile e non una costante.
  4. **P-9**: aprire il finding e assegnarlo a una release (proposta: v0.0.2, con
     O3.4). Finché non è chiuso, il Quick Start del README è ineseguibile alla lettera
     su un clone pulito.
  5. **Runner self-hosted ENV-W + `RUN_NIGHTLY`** (issue #12): resta aperto, non era
     nello scope di questa sessione.
