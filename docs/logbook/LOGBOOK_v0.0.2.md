# LOGBOOK — Fase 1: Raggiungibilità e riproducibilità (v0.0.2)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata al 2026-08-27

**Dove siamo**: fase aperta, nessuna sessione operativa ancora attiva. La sessione di
supervisione ha lavorato **fuori dallo scope di questa release** (solo piano e review,
nessuna modifica al sistema): ha introdotto **O8** e **O9** e la **Fase 6 / v0.0.6**
fra governance e beta1, con la specifica vincolante di O9 (contratto `ChangeFact`,
piano §1.1) — v. l'entry del 27/08.
Base: tag `v0.0.1` → `d3053be`, `develop` allineato. Lo stack sulla Z8 è spento
con i volumi conservati; il runner self-hosted `z8-env-w` è registrato e attivo,
ma `ci-nightly` è dormiente perché `RUN_NIGHTLY` non è impostata — e non va
impostata finché #42 non è chiuso.

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

**Decisioni prese**: (nessuna ancora in questa fase; quelle ereditate dalla Fase 0
sono in `SINTESI_fasi_chiuse.md` e non vanno rimesse in discussione senza un
motivo tecnico nuovo).

**Numeri misurati**: (nessuno ancora — il metro di partenza è
`docs/runs/20260826-2053-envw-5eb456a-baseline.md`).

**Aperto**
- `RUN_NIGHTLY` spenta finché #42 non è chiuso.
- Fuori fase ma tracciato: #40 (T0.10 fragile, Fase 3), P-5 (Fase 2, T-PROF),
  RP-0 (opzionale, Fase 5).

**Conseguenza di pianificazione (27/08)**: il release train ha ora **sette** fasi.
La beta1 si sposta da metà a **fine settembre**. Il costo è accettato dall'owner:
senza O8/O9 la beta1 sarebbe un sistema che passa i propri test tecnici e non
dimostra niente a un utente finale.

**Prossimo passo**: aprire `release/v0.0.2` da `develop` e assegnare #16 — il
doppio listener Kafka è il progression test dichiarato della release, e P-1 è
l'unico BLOCKER della review ancora aperto sul comportamento.

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

## 2026-08-27 (quarta entry) — sessione remota (cloud, nessun ambiente di
esecuzione) — Sessione A, fuori scope Fase 1

- **Nota di collocazione**: questa entry documenta lavoro **non di Fase 1**, per la
  regola `CLAUDE.md` §3.2 ("annotare nel logbook della fase che ospita il lavoro
  anticipato, citando la fase che lo consumerà"). #41 e #42 (lo scope reale di
  questa sessione in Fase 1) sono chiusi — v. terza entry sopra. Questo lavoro è
  arrivato via un nuovo compito della supervisione durante una finestra di
  manutenzione ENV-W dichiarata dall'owner, ed è **infrastruttura di test per
  v0.0.4** (T-SOAK-24h), non una modifica al sistema: ammessa in anticipo dalla
  stessa regola §3.2 (a). Branch **`feature/soak-harness`**, aperto da `develop`
  @ `7ae7181` — **non** `release/v0.0.2` — perché non è scope della release
  corrente.
- **Obiettivo della sessione**: costruire `bench/soak/`, l'harness di
  campionamento di **T-SOAK-24h** (`docs/piano_ricovero.md` §4.3), così la
  finestra di manutenzione ENV-W (12+ ore, prenotata dall'owner) possa misurare
  invece di aspettare che il codice sia pronto.
- **Fatto** (commit `e22f88b` su `feature/soak-harness`):
  - `bench/soak/lib/sample.py` — un campione per invocazione: `points_count` di
    Qdrant, `pg_replication_slots` + conteggio righe (`sensor_readings`,
    `orders`) via `docker exec psql`, RSS per container `northstream-*` via
    `docker stats --no-stream`, più load average/RAM libera/VRAM per issue
    **#44**. Ogni sottosistema è isolato in un proprio try/except: un
    fallimento produce un campo `error` e un valore nullo, mai un crash.
  - `bench/soak/run.sh` — orchestratore: loop a intervallo fisso (default 60 s),
    scrittura append-only una riga per campione, `trap` su `SIGINT`/`SIGTERM`
    per fermarsi in modo pulito dopo il campione in corso. Riusa le convenzioni
    `RUN_ID`/`manifest.json` già stabilite da `bench/t0/run.sh` invece di
    inventarne di nuove.
  - `bench/soak/verdict.py` — script separato che trasforma `samples.jsonl` in
    un verdetto sulle quattro verifiche del piano, più un riepilogo descrittivo
    di esclusività host per #44.
  - `bench/soak/README.md` — uso e schema dei campioni.
- **Decisioni prese** (e perché — alternative scartate):
  - **Due delle quattro verifiche (crescita Qdrant vs retention, RSS vs tier)
    restano `UNKNOWN` finché non si passa esplicitamente una soglia** via
    `--max-replication-mib` / `--rss-ceiling-mib`, invece di un default
    inventato. *Motivo*: la retention non è implementata, e l'unico tetto RSS
    dichiarato nel piano (T-PROF, v0.0.3) vale per il profilo `core`, non per lo
    stack pieno che un soak esercita. Un numero senza base nel piano
    sembrerebbe un gate reale e non lo è — meglio dichiararlo esplicitamente
    sconosciuto che fabbricare falsa fiducia. *Alternativa scartata*: un
    default "ragionevole" hardcoded — scartata perché indistinguibile, nel
    report, da una soglia realmente decisa.
  - **Le altre due verifiche (dimensione replication slot con soglia esplicita,
    eventi persi DB-vs-Qdrant) restano invece verdetti reali**, calcolate dal
    delta fra primo e ultimo campione valido: non richiedono una soglia esterna
    per essere significative.
  - **`host_exclusivity` in `verdict.py` è solo descrittivo**, non implementa il
    pre-check/classificatore di #44 (min/max VRAM, RAM, load per campione, zero
    logica di gate). *Motivo*: #44 è issue propria di Fase 2 (v0.0.3) con una
    definition of done più ampia (pre-check che blocca un run, marcatura
    "contaminato" a metà run, campo `exclusive/shared/unknown` nel manifest);
    implementarla qui sarebbe uscire dallo scope assegnato di questa sessione
    (il campionamento) invadendo quello di un'altra issue. Il compito
    assegnato chiedeva esplicitamente solo "VRAM, RAM libera e load a ogni
    campione" — fatto — non la classificazione.
  - **Ogni riga è un singolo `write()` con `flush()`+`fsync()`**, non un buffer
    che si scrive a intervalli o a fine run: è il modo con cui un campione
    resta leggibile anche se il processo muore a metà (requisito esplicito del
    compito — "se il run muore alla ventitreesima ora, le prime 22 devono
    restare leggibili").
  - **Nessuna riga di CHANGELOG.md per questo commit.** `CLAUDE.md` §4 esenta i
    commit solo-documentazione, ma questo è codice — la ragione è un'altra:
    l'`[Unreleased]` di `CHANGELOG.md` è scope di `release/v0.0.2`
    (`Fase 1`), e questo branch non è quella release. L'aggiunta di
    `bench/soak/` avrà la sua riga quando **v0.0.4** la userà davvero, non ora
    — altrimenti il changelog di una release racconterebbe lavoro di un'altra,
    esattamente il difetto D-1 da cui è nata la review.
- **Test eseguiti** (nessun ambiente Docker in questa sessione — v. `CLAUDE.md`
  §5, "si limita a lavoro statico"):
  - `bash -n bench/soak/run.sh` → sintassi valida. `python3 -m py_compile` su
    `sample.py` e `verdict.py` → sintassi valida. `ruff check bench/soak/` →
    pulito dopo la correzione di due `E731` (lambda → `def`).
  - **Prova a secco richiesta dal compito** (10 min a intervallo ridotto, poi
    ripetuta a 6 s dopo il fix ruff): `bench/soak/run.sh --interval 2|3
    --duration 6|10` senza demone Docker in questa sandbox → 3 campioni
    prodotti, ognuno con i sottosistemi Docker/Qdrant degradati a `error`
    esplicito (nessun crash), `host` comunque popolato (load, RAM; niente GPU,
    coerente — sandbox senza `nvidia-smi`). `verdict.py` sui campioni →
    `UNKNOWN` sulle quattro verifiche (nessun dato Docker) più il riepilogo
    host, exit 0. **Test del segnale**: `SIGTERM` a metà run (dopo 3 campioni)
    → uscita pulita, `samples.jsonl` con 3 righe, tutte JSON valido. Verifica
    superata nei limiti di questa sandbox: **la prova a secco vera, con lo
    stack acceso, resta da fare sulla Z8** — è quanto il compito stesso
    prevedeva ("non hai Docker in questa sessione... la prova a secco vera la
    farà la Z8").
  - Non-regressione: nessun file fuori da `bench/soak/` toccato.
- **Costo della sessione**: `claude-sonnet-5` (configurato e servito, nessun
  fallback). Da `get_session` alla chiusura di questo compito: **7.351.495
  token di cache read**, **235.465 di cache write**, **33.019 di output**,
  **2,74 $** nozionali (abbonamento MAX). Durata di sessione dalla creazione:
  ~1 h 37 min (08:39Z–10:16Z) — include anche il lavoro su #41/#42 di questa
  stessa sessione, non scorporabile a posteriori (v. `CLAUDE.md` §7 sulla
  lunghezza di sessione come driver di costo dominante).
- **Non funziona / sospeso**: la prova a secco reale su ENV-W (stack acceso)
  non è stata eseguita da questa sessione — nessun accesso a ENV-W. Consegnata
  alla sessione ENV-W come riportato sotto.
- **Prossimo passo per la sessione successiva**: sulla Z8, dentro `tmux`,
  checkout di `feature/soak-harness` e:
  ```sh
  tmux new -s northstream-soak
  git fetch origin feature/soak-harness && git checkout feature/soak-harness
  bench/soak/run.sh --interval 30 --duration 600 --env envw   # prova a secco, 10 min
  python3 bench/soak/verdict.py --samples results/<RUN_ID>/samples.jsonl \
      --manifest results/<RUN_ID>/manifest.json --report results/<RUN_ID>
  ```
  Se la prova a secco è verde (campioni leggibili, verdetto calcolato, nessun
  crash), la finestra di manutenzione prenotata parte con
  `bench/soak/run.sh --interval 60 --duration 86400 --env envw` sotto `tmux`.
  Consigliato: lanciare **T-SOAK-24h insieme** allo stack pieno (`--gpu`) così
  la finestra dà anche la prima misura "prima" citata in piano §6-bis.
- **Decisioni richieste all'owner**: nessuna — il branch e lo scope erano già
  decisi dalla supervisione nel compito assegnato.

---

## 2026-08-27 (quinta entry) — sessione remota (cloud) — Sessione A, fix urgente
soak, fuori scope Fase 1 (stessa collocazione della quarta entry)

- **Obiettivo**: correggere un difetto misurato dalla supervisione su ENV-W —
  `bench/soak/lib/sample.py` leggeva `active` dello slot di replica sempre
  `false`, perché il confronto era contro `'t'` mentre Postgres, concatenando
  un booleano con `||`, lo stringifica `'true'`/`'false'`. Una costante
  travestita da misura: 24 h archiviate avrebbero raccontato una pipeline
  scollegata, falso.
- **Fatto** (commit `2b4f4ad` su `feature/soak-harness`):
  - **Fix alla radice**: la query ora forza l'encoding con un `CASE WHEN
    active THEN 't' WHEN NOT active THEN 'f' ELSE 'u' END`, invece di
    fidarsi di come Postgres stringifica implicitamente un booleano
    concatenato (dipendente da versione/contesto, non garantito).
  - **Difesa in profondità**: il parser accetta solo `'t'`/`'f'`; qualunque
    altro valore diventa `active: None` con un warning esplicito — non può
    più collassare silenziosamente su `False`.
  - **Riletti gli altri campi derivati** (richiesto esplicitamente dal
    compito): righe non riconosciute della query postgres, righe non
    parsabili di `docker stats`, container visti da `docker ps` ma assenti
    da `docker stats`, righe `nvidia-smi` non parsabili — tutti ora
    producono un warning/error invece di sparire in silenzio. Gli altri campi
    derivati (`retained_bytes`, i conteggi tabella) erano già corretti:
    usano già `.isdigit()` con fallback a `None`, non a `0`.
  - **Auto-verifica minima**: ogni warning/error di ogni sottosistema è ora
    anche stampato su stderr per ogni campione (non solo il primo — più
    semplice e strettamente più sicuro), che `run.sh` già redirige in
    `soak.err.log`: un dato anomalo è visibile entro un intervallo, non dopo
    24 ore.
- **Decisioni prese**: nessuna scelta libera — il compito chiedeva
  esplicitamente "niente rifacimenti, niente funzionalità in più", quindi il
  fix è il minimo che chiude il difetto segnalato più l'audit richiesto degli
  altri campi. Un'unica scelta di merito: **fix alla radice (query SQL)
  oltre che nel parser**, non solo nel parser — l'alternativa scartata era
  correggere solo il confronto Python contro `'true'`, ma quello resta fragile
  a un futuro cambio di comportamento di Postgres/psql; fissare l'encoding
  lato query lo rende deterministico e testabile.
- **Test eseguiti**:
  - `ruff check bench/soak/` → pulito. `python3 -m py_compile` → sintassi
    valida su entrambi i file toccati.
  - **Test mirato del fix** (mock di `run()`, 4 casi): `active` `'t'` → `True`;
    `'f'` → `False`; un valore inatteso `'true'` (il difetto originale) →
    `None` + warning, **non** `False`; una riga non riconosciuta → warning,
    non scartata in silenzio. Tutti e quattro verificati con `assert` diretti
    sull'output di `sample_postgres`.
  - **Prova a secco end-to-end** (10 s, stack spento, questa sandbox senza
    Docker): 3 campioni, ogni sottosistema degradato con `error` esplicito,
    e — a differenza di prima — **ogni degradazione ora compare in
    `soak.err.log`** per ciascun campione, non solo silenziosamente nel
    JSON. `verdict.py` gira senza eccezioni sui campioni con `_warnings`
    nel dizionario `containers` (bug collaterale trovato e corretto in
    `verdict.py`: iterava su `containers.items()` inclusa la chiave
    `_warnings`, che non ha `.get()` — ora salta le chiavi con prefisso `_`).
  - **Verifica sullo stack reale (ENV-W) non eseguita da questa sessione**:
    nessun accesso Docker qui. Resta alla sessione ENV-W confermare che
    `active` legga correttamente lo stato vero del connettore.
- **Costo della sessione**: `claude-sonnet-5`. Non ri-misurato con
  `get_session` per questa singola entry (richiesta esplicita di velocità
  nel compito — "urgente e piccolo"); cumulativo dall'inizio sessione nella
  prossima entry di chiusura fase.
- **Non funziona / sospeso**: verifica reale su ENV-W con connettore attivo,
  da fare al lancio del soak.
- **Prossimo passo per la sessione successiva**: sulla Z8, `git pull` su
  `feature/soak-harness` (ora a `2b4f4ad`) e ripetere la prova a secco di 10
  minuti prima del soak pieno — v. comando nella quarta entry, invariato.
- **Decisioni richieste all'owner**: nessuna.

---

## 2026-08-27 (sesta entry) — sessione remota (cloud) — Sessione A, exclusivity
e stato pipeline nel manifest del soak (stessa collocazione, anticipo di #44)

- **Contesto**: il fix della quinta entry è stato verificato con successo su
  ENV-W (`active` legge `False` reale quando lo slot è davvero fermato, `True`
  quando è attivo — 5/5 sonde, `warnings` sempre vuoto). Il soak parziale è
  **partito alle 14:06:35Z, gira fino alle 21:30Z sotto la versione già
  pushata**: questa sessione non lo tocca. La supervisione ha trovato durante
  l'avvio che `manifest.json` scriveva `"exclusivity": "unknown"` come
  costante cablata, senza raccogliere stato del connettore/slot: ENV-W li ha
  scritti a mano sotto una chiave `operator_recorded`, dichiarata come
  inserimento manuale — scelta giusta per non far credere che l'harness li
  raccogliesse da solo. Questo lavoro chiude il gap per il **prossimo** run
  (T-SOAK-24h vero), non tocca quello in corso.
- **Fatto** (commit `fe91a74` su `feature/soak-harness`):
  - **`--exclusivity exclusive|shared|unknown`** (default `unknown`) su
    `run.sh`, scritto in `manifest.json` al posto della costante. Dichiarato
    da chi lancia il run, mai inferito.
  - **`sample.py --mode init`**: raccolta one-shot allo start del run —
    stato del connettore CDC (Kafka Connect REST
    `/connectors/<nome>/status`) e stato dello slot di replica — scritta in
    `manifest.json.initial_conditions`. Stessa disciplina del campionatore
    periodico: irraggiungibile → `null` + `error` esplicito, mai un valore
    inventato.
  - **Non aggiunto nulla per il campionamento periodico di GPU/RAM/load**
    durante il run: **esisteva già**. `sample_host()` lo raccoglie a ogni
    intervallo dalla quarta entry, e `verdict.py`'s `host_exclusivity`
    aggrega già min/max VRAM usata sull'intero `samples.jsonl` — la parte
    "run-check" di #44 (distinguere un run esclusivo dall'inizio alla fine
    da uno diventato condiviso a metà) è quindi già coperta dai dati che il
    campionatore scrive da quando esiste, non da codice nuovo di questa
    entry.
- **Decisioni prese** (e perché — alternative scartate):
  - **Fermata al punto 2 del compito** (flag + raccolta iniziale), **senza**
    costruire il pre-check/classificatore di #44 (il gate che rifiuta un run
    su macchina condivisa, la logica `exclusive`/`shared` automatica).
    *Motivo*: #44 ha una definition of done più ampia, propria di Fase 2, e
    il compito stesso autorizzava a fermarsi qui se il resto "cresce troppo"
    — costruirla ora sarebbe invadere lo scope di un'altra issue dalla
    sessione sbagliata. Il punto 3 (campionamento periodico) non ha
    richiesto questa scelta perché **era già soddisfatto** dal lavoro
    precedente, non per aver tagliato scope.
  - **`initial_conditions` come oggetto annidato nel manifest**, non chiavi
    piatte allo stesso livello di `exclusivity`: tiene insieme ciò che è
    "stato iniziale dichiarato dalla pipeline" separato da ciò che è
    "configurazione del run", leggibile senza ambiguità da chi apre il
    manifest fra mesi.
  - **`--mode init` dentro `sample.py` esistente**, non un secondo script:
    riusa `sample_postgres()` per lo stato dello slot invece di duplicare la
    query, e riusa la stessa disciplina di errore. *Alternativa scartata*:
    uno script `bench/soak/lib/init.py` separato — scartata perché avrebbe
    duplicato la query psql e il pattern di errore già scritti.
- **Test eseguiti**:
  - `bash -n run.sh`, `python3 -m py_compile sample.py`, `ruff check
    bench/soak/` → tutti puliti.
  - `python3 bench/soak/lib/sample.py --mode init` isolato (nessun Docker in
    questa sandbox) → JSON valido, `connector.error` e `postgres_error`
    popolati, nessun crash, exit 0.
  - `run.sh --interval 2 --duration 6 --exclusivity shared` end-to-end →
    `manifest.json` contiene `"exclusivity": "shared"` e
    `initial_conditions` popolato coerentemente con la degradazione
    attesa (niente Docker qui).
  - `run.sh --exclusivity bogus` → rifiutato con messaggio esplicito, exit
    2 (validazione dei tre soli valori ammessi).
  - Default invariato: `run.sh` senza `--exclusivity` → `"unknown"` nel
    manifest, come prima.
  - **Non toccato il soak in corso su ENV-W** (né il branch nel punto in cui
    lo sta eseguendo, né alcun file mentre gira): verificato leggendo la
    richiesta della supervisione prima di agire.
- **Costo della sessione**: `claude-sonnet-5`, non ri-misurato per questa
  singola entry (stesso criterio di urgenza della quinta) — cumulativo alla
  prossima chiusura di fase.
- **Non funziona / sospeso**: la classificazione automatica exclusive/shared
  e il pre-check che blocca un run su macchina condivisa restano **aperti,
  di #44, Fase 2** — non iniziati qui, per costruzione.
- **Prossimo passo per la sessione successiva**: al termine del soak in
  corso (21:30Z) o al lancio del prossimo, usare
  `bench/soak/run.sh ... --exclusivity <valore dichiarato>` invece di
  editare `manifest.json` a mano. Chi apre #44 in Fase 2 trova già scritti:
  il flag di dichiarazione, la raccolta di stato iniziale, e il riepilogo
  GPU/RAM/load per-campione — gli resta solo il pre-check che blocca un run
  e la classificazione automatica.
- **Decisioni richieste all'owner**: nessuna.
