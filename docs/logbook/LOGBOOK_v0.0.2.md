# LOGBOOK — Fase 1: Raggiungibilità e riproducibilità (v0.0.2)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata al 2026-08-27

**Dove siamo**: **Sessione A** attiva su `release/v0.0.2`, ha chiuso lato codice
#41 (P-9) e #42 (P-10) — v. terza entry del 27/08. #41 verificato su clone pulito
(exit 126 sparito). #42 verificato staticamente (YAML valido, `docker compose
config` verde) ma **non ancora con una nightly reale**: serve un
`workflow_dispatch` dalla sessione ENV-W. La sessione di supervisione ha lavorato
**fuori dallo scope di questa release** (solo piano e review, nessuna modifica al
sistema): ha introdotto **O8** e **O9** e la **Fase 6 / v0.0.6** fra governance e
beta1, con la specifica vincolante di O9 (contratto `ChangeFact`, piano §1.1) — v.
l'entry del 27/08.
Base: tag `v0.0.1` → `d3053be`, `develop` allineato. Lo stack sulla Z8 è spento
con i volumi conservati; il runner self-hosted `z8-env-w` è registrato e attivo,
ma `ci-nightly` è dormiente perché `RUN_NIGHTLY` non è impostata — e non va
impostata finché #42 non è **verificato con una nightly reale**, non solo
corretto nel codice.

**Scope della fase** (`docs/piano_ricovero.md` §6, riga v0.0.2 — obiettivo O3):
rendere lo stack raggiungibile dall'host come documentato e riproducibile nel
tempo. Issue di fase [#4](https://github.com/danielesalpietro/NORTHSTREAM/issues/4).

| Sub-issue | Contenuto | Finding |
|---|---|---|
| [#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16) | Doppio listener Kafka (interno `kafka:9092`, esterno `localhost:29092`) | P-1 |
| [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17) | Pin immagini a versione+digest; sostituzione di `bitnamilegacy/kafka` | P-3, P-4 |
| [#18](https://github.com/danielesalpietro/NORTHSTREAM/issues/18) | Binding porte su `127.0.0.1` | P-7 |
| [#19](https://github.com/danielesalpietro/NORTHSTREAM/issues/19) | Script preflight (`vm.max_map_count`, RAM, GPU) | P-6 |
| [#41](https://github.com/danielesalpietro/NORTHSTREAM/issues/41) | Bit di esecuzione sui tre script del Quick Start | **P-9** |
| [#42](https://github.com/danielesalpietro/NORTHSTREAM/issues/42) | Teardown di `ci-nightly` che cancella `ollama_data` | **P-10** |
| [#20](https://github.com/danielesalpietro/NORTHSTREAM/issues/20) | Release v0.0.2: gate, CHANGELOG, tag | — |

**Progression test dichiarati**: **T0.6** (client Kafka dall'host ottiene metadata
utilizzabili) XFAIL → PASS; nuovo **T-REPRO** (due `docker compose pull` a distanza
risolvono gli stessi digest); preflight che fallisce con messaggio chiaro su host
non conforme; per #42, una nightly reale dopo cui `ollama_data` esiste ancora.

**Gate di chiusura**: tutti i PASS di v0.0.1 restano PASS — in particolare i cinque
del run di riferimento — CI verde, e nessun nuovo XFAIL non dichiarato.

**Decisioni prese**:
- **#42: rimozione esplicita dei soli tre volumi di stato che T0 esercita**
  (`kafka_data`, `postgres_data`, `qdrant_data`) al posto di `down -v`, invece di
  "tutti tranne `ollama_data`". *Scartata*: pulizia più ampia di tutti gli altri
  volumi (MinIO, Elasticsearch, OpenMetadata, Open WebUI) — appartengono a
  servizi scenografici congelati (§3.2) e ripulirli non aggiunge garanzie di
  test.
- **`ollama_data` resta interno, non esterno.** *Scartata*: volume esterno,
  più robusto contro un futuro `down -v` per distrazione ma che cambia la
  procedura di primo avvio — rimandata a issue separata se l'incidente si
  ripete.

**Numeri misurati**: (nessuno ancora — il metro di partenza è
`docs/runs/20260826-2053-envw-5eb456a-baseline.md`; la verifica reale di #42
richiede una nightly su ENV-W, non ancora eseguita).

**Aperto**
- **#42 corretto ma non ancora verificato con una nightly reale** (richiede
  `workflow_dispatch` dalla sessione ENV-W). `RUN_NIGHTLY` resta spenta finché
  quella verifica non conferma che `ollama_data` sopravvive al teardown —
  decisione dell'owner anche dopo la conferma.
- Fuori fase ma tracciato: #40 (T0.10 fragile, Fase 3), P-5 (Fase 2, T-PROF),
  RP-0 (opzionale, Fase 5).

**Conseguenza di pianificazione (27/08)**: il release train ha ora **sette** fasi.
La beta1 si sposta da metà a **fine settembre**. Il costo è accettato dall'owner:
senza O8/O9 la beta1 sarebbe un sistema che passa i propri test tecnici e non
dimostra niente a un utente finale.

**Prossimo passo**: `release/v0.0.2` è aperto; Sessione B lavora #17→#16→#18→#19
sui file compose (doppio listener Kafka, il progression test T0.6 dichiarato
della release, resta il suo passo principale). Per Sessione A (#41/#42): far
innescare una nightly reale su ENV-W via `workflow_dispatch` per verificare #42,
poi chiudere entrambe le issue.

---

## 2026-08-27 — sessione remota (cloud, nessun ambiente di esecuzione) — supervisione

- **Obiettivo della sessione**: orientare il piano ai casi d'uso. Domanda dell'owner:
  i test case oggi sono tecnici e non interessano a un utente finale — chi è l'utente
  e quale caso d'uso mostra il beneficio? Poi, su sua indicazione: mantenere G-3 come
  priorità elevata, introdurre **O8**, far diventare i test i casi d'uso, aggiungere
  **O9 — Explain Change**, e infine vincolarne l'implementazione al contratto
  `ChangeFact`.
- **Fatto** (solo documentazione: nessun file di `stream-agent/`, compose o workflow
  toccato — v. Decisioni):
  - `93e8b59` — piano: O8 e O9 in §1; question set EVAL riscritto come **sei classi
    d'uso U1–U6** (§4.2); riga **v0.0.6** nel release train (§6). Review: **G-3
    ripromosso da MINOR a MAJOR** con il perché della classificazione sbagliata.
  - `eb98b57` — CLAUDE.md §2: riga di tracking fasi estesa alla Fase 6.
  - `6a665fa` — piano: nuova **§1.1, specifica vincolante di O9**; sei criteri EVAL
    di O9 in §4.2; riga v0.0.6 aggiornata col criterio di accettazione. Review: G-3
    esteso alle **sequenze controllate**.
  - Issue **[#43](https://github.com/danielesalpietro/NORTHSTREAM/issues/43)** creata
    e poi riscritta col contratto completo.
- **Decisioni prese**:
  - **O9 non estende il RAG: introduce una funzione di change detection.** Il RAG
    restituisce i *k* eventi più simili e non può dire che un tasso è triplicato,
    perché quello è un aggregato sulla finestra. Pipeline: `raw events → window
    comparison → change facts → salience filtering → retrieval → explanation`. Il
    retrieval entra **dopo**: recupera che cosa il cambiamento influenza, non lo
    scopre.
  - **Il calcolo Python di beta1 è ammesso solo come *reference implementation* del
    futuro operatore Flink**, dietro la firma
    `detect_changes(events, current_window, reference_window, policy) -> list[ChangeFact]`.
    *Alternativa scartata*: le ~50 righe dentro il prompt flow dell'agent, come
    scritto nella prima stesura. Più rapida, ma se l'agent legge tutti gli eventi,
    sceglie da sé che cosa confrontare e calcola numeri nel prompt, non stiamo
    prototipando Flink — stiamo costruendo un'architettura parallela da buttare.
    **Il modello riceve i risultati del confronto, non è il motore del confronto.**
    Criterio di accettazione conseguente: sostituire il produttore di `ChangeFact`
    non deve toccare agent, EVAL e demo-script.
  - **La salienza è una policy governata**, deterministica e per metrica
    (`minimum_event_count`, `minimum_absolute_delta`, `minimum_ratio`, richiesti
    tutti insieme). *Alternativa scartata*: un anomaly detector statistico
    general-purpose in beta1 — non è dimostrabile, non è riproducibile in Flink, e
    rende incontrollabile il periodo tranquillo. Motivo di merito: "triplicato" può
    essere rumore (1→3 anomalie) e "+50%" può essere grave (100→150): il rapporto
    da solo non è un criterio.
  - **Tre livelli di spiegazione tenuti separati** — Explain Change (fatto), Explain
    Relevance (collegamento), Explain Risk (inferenza). Fonderli in un'unica frase
    apparentemente fattuale è il modo in cui un sistema di *situational explanation*
    finge di essere forecasting.
  - **Tre casi negativi distinti** che non devono collassare nello stesso "non lo
    so": *quietness* (dati freschi, nessun cambiamento rilevante), *observability*
    (dati insufficienti, confronto non effettuabile), *explainability* (cambiamento
    reale, impatto non determinabile). Sono tre proprietà di fiducia diverse; un'unica
    asserzione le perderebbe tutte e tre.
  - **G-3 alzato ancora**: il generatore non deve produrre eventi *realistici* ma
    **sequenze controllate con baseline, sviluppo, impatto e periodo tranquillo** —
    sono le quattro fasi che i criteri EVAL di O9 asseriscono. Senza baseline non
    esiste finestra di riferimento; senza periodo tranquillo non esiste il controllo
    negativo di quietness.
  - **Il lavoro è di pianificazione, non di release.** Sta fuori dallo scope di
    v0.0.2 e non lo viola: CLAUDE.md §3.2 vincola le modifiche al comportamento del
    sistema, non i documenti di piano. Nessun file eseguibile toccato.
- **Test eseguiti**: **nessuno** — sessione cloud senza Docker né accesso a ENV-W
  (CLAUDE.md §5). Nessun claim di esito.
- **Costo della sessione**: `claude-opus-5` (sessione configurata `claude-sonnet-5`,
  servita da opus-5), ~12 h 50 min di vita della sessione, **21.195.447 token di
  cache read** / **99.915 di output**, **139,50 $** nozionali (abbonamento MAX: non
  fatturati). Conferma la lezione di CLAUDE.md §7: il driver dominante è la
  **lunghezza della sessione**, non il tier — questa ha attraversato l'intera Fase 0
  più la pianificazione della Fase 6, e ogni turno rilegge la conversazione intera.
- **Non funziona / sospeso**: nulla di nuovo. Restano i blocchi di §2 di CLAUDE.md
  (`RUN_NIGHTLY` off finché #42 non è chiuso, #40, P-5).
- **Prossimo passo per la sessione successiva**: aprire `release/v0.0.2` da `develop`
  e avviare #16 (doppio listener Kafka, progression test T0.6) su `claude-sonnet-5`.

## 2026-08-27 (seconda entry) — sessione remota (cloud) — supervisione

- **Obiettivo della sessione**: rispondere alla domanda dell'owner *"con questa
  revisione, è necessario aggiornare anche il README?"* e registrare l'esito dove
  serve, cioè fuori da questa conversazione.
- **Fatto**: verificato che **no**, e per due motivi indipendenti. (a) **Regola**:
  CLAUDE.md §4 — il README descrive lo stato *rilasciato*, si aggiorna solo nel
  release branch come ultimo commit prima del tag, ed è vietato aggiornarlo da
  `develop` fra una release e l'altra; l'unica eccezione è la correzione di un claim
  falso. La revisione di O9 non rilascia niente: descrive un obiettivo di v0.0.6.
  (b) **Verifica di merito**, perché la regola da sola non basta: controllato che la
  revisione non abbia reso falso qualcosa che il README già dice —
  - riga 18-26 (*"What is actually wired today"*) rimanda esplicitamente a
    `docs/piano_ricovero.md` per il work in progress: il README delega, il piano
    dettaglia, nessuna divergenza;
  - tabella **Layer status**, riga Flink — *"Not wired — the cluster runs, no job is
    submitted by this repository"* — **resta vera**: O9.2 è post-beta1 e in beta1 il
    produttore di `ChangeFact` è Python. Sarebbe diventata falsa se il README avesse
    già attribuito a Flink il calcolo dei cambiamenti;
  - **Roadmap**: non contiene Explain Change. È un'**omissione**, non una falsità, e
    le omissioni non attivano l'eccezione.
- **Debito documentale di v0.0.6** (registrato qui perché la sessione che chiuderà
  quella release non dipenda dal ricordo di questa conversazione; riportato anche su
  [#43](https://github.com/danielesalpietro/NORTHSTREAM/issues/43)):
  1. **Roadmap**: aggiungere Explain Change fra le voci implementate, distinguendo
     beta1 (detector Python) da post-beta1 (operatore Flink).
  2. **Layer status, riga Flink**: alla v0.0.6 resta *Not wired*, ma con la
     motivazione aggiornata — è il primo job con una ragione architetturale reale;
     diventa **Wired** solo al porting O9.2.
  3. **Contratto `ChangeFact`**: è l'unica parte di O9 che un utilizzatore esterno
     vede, quindi va descritta nel README come contratto pubblico dell'agent.
  4. **`docs/demo-script.md`**: con O8.3 smette di essere scritto a mano ed è
     **generato** dai casi d'uso — cambia la natura del riferimento dal README, non
     solo il testo.
  **Vincolo su tutti e quattro**: **T0.12 deve restare verde** dopo la modifica. Il
  linter di verità documentale verifica path, endpoint della tabella servizi e
  coerenza della sezione License: il punto 3 non può quindi citare un file di schema
  che non esiste ancora, e il punto 4 non può linkare un demo-script prima che il
  generatore lo produca.
- **Decisioni prese**: nessuna nuova. Confermata l'applicazione di §4 invece di
  un'eccezione *ad hoc*: aggiornare il README "già che ci siamo" è esattamente il
  meccanismo con cui il README torna a raccontare lavoro non rilasciato, che è il
  difetto D-1 da cui è nata la review.
- **Test eseguiti**: nessuno (sessione cloud senza ambiente di esecuzione). La
  verifica sul README è **lettura**, non esecuzione: `grep` sulle sezioni Roadmap,
  Layer status e sui riferimenti a `docs/`.
- **Costo della sessione**: v. entry precedente di oggi (stessa sessione, misura non
  ripetuta per non contarla due volte).
- **Non funziona / sospeso**: nulla di nuovo.
- **Prossimo passo per la sessione successiva**: invariato — aprire `release/v0.0.2`
  da `develop` e avviare #16 su `claude-sonnet-5`.

---

## 2026-08-27 (terza entry) — sessione remota (cloud) — Sessione A Fase 1 (#41, #42)

- **Obiettivo della sessione**: chiudere #41 (P-9, bit di esecuzione) e #42 (P-10,
  teardown `ci-nightly`), nell'ordine dettato dalla dipendenza — con gli script a
  `100644` il primo step di `ci-nightly.yml` (`./start-addon.sh --gpu`) muore
  sempre, quindi #42 non sarebbe verificabile prima di #41.
- **Fatto**:
  - `5f98800` — bit di esecuzione impostato su `start-addon.sh`,
    `register-connector.sh`, `demo-compare.sh` via `git update-index --chmod=+x`
    (`100644` → `100755`).
  - `531ed58` — teardown di `ci-nightly.yml`: `down -v` sostituito con `down` +
    `docker volume rm -f` esplicito sui tre volumi di stato che la suite T0
    esercita (`kafka_data`, `postgres_data`, `qdrant_data`); `ollama_data`
    preservato.
- **Decisioni prese** (e perché — alternative scartate):
  - **Rimozione esplicita dei soli tre volumi nominati (Kafka, Postgres, Qdrant),
    non "tutti tranne `ollama_data`".** Sono gli unici che la suite T0 esercita
    davvero: `minio_data`, `elasticsearch_data`, `open_webui_data`,
    `openmetadata_db_data` appartengono a servizi oggi scenografici (congelati
    per `CLAUDE.md` §3.2), e ripulirli ogni notte non aggiungerebbe garanzie di
    test — solo uno scope più largo di quanto serva per chiudere P-10.
  - **`ollama_data` resta un volume interno, non esterno, per ora.** Un volume
    esterno sarebbe più robusto contro un futuro `down -v` per distrazione, ma
    cambia la procedura di primo avvio (richiederebbe `docker volume create`
    prima del primo `up`) — cambiamento di superficie più ampio del fix minimale
    richiesto da P-10. Rimandata: se un secondo incidente di cancellazione
    accidentale si ripete, va riconsiderata come issue a parte.
  - **Nomi dei volumi hardcoded col prefisso di progetto**
    (`wap-northstream-lab_...`) invece di risolverli dinamicamente: il project
    name è fissato da `name:` in cima al compose base e nessun override lo cambia
    nel workflow, quindi è deterministico — confermato con
    `docker compose config --volumes`.
- **Test eseguiti**:
  - **#41**: `git ls-files -s` sui tre script → `100755` (PASS). Clone pulito in
    `/tmp` + checkout di `release/v0.0.2` → `ls -l` conferma `rwxr-xr-x`;
    `./start-addon.sh --help` non dà più exit 126/`Permission denied` (fallisce
    con exit 1 per assenza del demone Docker in questa sandbox — causa diversa e
    attesa, non P-9). **PASS** sul criterio dichiarato in §4 del briefing.
  - **#42**: `python3 -c "import yaml; yaml.safe_load(...)"` su `ci-nightly.yml`
    → sintassi valida.
    `docker compose -f docker-compose-northstream-ai.yml -f docker-compose.addon.yml config -q`
    → exit 0 (equivalente locale del check `ci-static`).
    `docker compose ... config --volumes` → confermati gli 8 nomi attesi.
    **Verifica reale (nightly con teardown, criterio dichiarato del progression
    test) non eseguibile da questa sessione**: nessun demone Docker in questa
    sandbox. Richiede la sessione ENV-W — v. "Prossimo passo".
  - **Non-regressione**: nessun altro file toccato oltre ai tre script
    (mode-only) e al workflow `ci-nightly.yml`; `ci-static`/`ci-smoke` non
    impattati per costruzione (nessun servizio, path README o compose base
    toccato — #16/#17/#18/#19 restano di competenza della sessione B).
- **Costo della sessione**: `claude-sonnet-5` (sessione configurata e servita,
  nessun fallback osservato). `get_session` non espone il campo `usage`
  (token cache-read/output) per questa sessione/chiamata: **non misurabile** con
  i dati disponibili — non stimato, per non violare CLAUDE.md §4. Durata di
  sessione dalla creazione al push: ~10 minuti (08:39Z–08:4xZ).
- **Non funziona / sospeso**: verifica reale di #42 in attesa della nightly su
  ENV-W (v. sotto). `RUN_NIGHTLY` resta spenta — non è una decisione di questa
  sessione.
- **Prossimo passo per la sessione successiva**: dopo che una nightly reale su
  ENV-W (innescata via `workflow_dispatch` dalla sessione ENV-W di supervisione)
  conferma che il volume dei modelli sopravvive al teardown e `ollama list` li
  elenca ancora, #41 e #42 si possono chiudere. Nessun'altra modifica di codice è
  attesa da questa sessione: lo scope assegnato (#41, #42) è esaurito lato push.
- **Decisioni richieste all'owner**:
  1. Se e quando impostare `RUN_NIGHTLY` a `true`, dopo la conferma della nightly
     di verifica — CLAUDE.md §2 la riserva esplicitamente all'owner.
  2. Se vale la pena promuovere `ollama_data` a volume esterno in una issue
     separata (trade-off descritto sopra, non deciso qui).
