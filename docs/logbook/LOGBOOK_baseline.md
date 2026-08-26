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
