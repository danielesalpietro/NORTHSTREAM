# CLAUDE.md — Direttive per ogni sessione di lavoro su NORTHSTREAM

Queste direttive sono vincolanti per ogni sessione (Claude Code o umana). Lo scopo è
uno: **la memoria del progetto vive nei file elencati qui, non nella testa di chi ha
lavorato ieri.** Una sessione nuova che salta l'onboarding produce lavoro duplicato,
contraddittorio o che regredisce fix già fatti.

---

## 0. Che cos'è questo progetto (verità in tre righe)

NORTHSTREAM è un lab Docker Compose: una pipeline CDC **funzionante**
(Postgres → Debezium → Kafka) + un agent RAG (`stream-agent/`) che indicizza eventi
live in Qdrant e li usa come contesto per un LLM locale (Ollama/Granite), circondata
da servizi oggi **non collegati al flusso dati** (Flink, Apicurio, MinIO, Trino,
OpenMetadata). La distanza tra narrativa e realtà è documentata e in corso di
chiusura secondo un piano a release. Non fidarti del README finché il test di verità
documentale (T0.12) non è verde: fidati dei documenti al punto 1.

## 1. Onboarding obbligatorio — PRIMA di qualsiasi ragionamento o modifica

Leggere **in quest'ordine**, sempre:

1. **Questo file**, per intero — in particolare §2 "Stato corrente".
2. **`docs/piano_ricovero.md`** — il piano vincolante: obiettivi O1–O7, ambienti,
   suite di test T0/EVAL/soak, release train fino a v0.1.0-beta1. La sezione della
   release corrente (v. §2) definisce lo scope ammesso della sessione.
3. **`docs/review_tecnica.md`** — i finding (P-*, A-*, G-*, D-*) che il piano
   chiude. Ogni intervento cita il finding che sta chiudendo.
4. **`docs/logbook/LOGBOOK_<fase-corrente>.md`** — leggere la **SINTESI DI FASE**
   in testa al file e **l'ultima entry**, non tutte le entry: la testa è la forma
   compressa della fase, l'ultima entry è il punto di ripartenza. Le entry
   intermedie si aprono solo per ricostruire un dettaglio che la testa non copre.
   Se esiste `docs/logbook/SINTESI_fasi_chiuse.md`, leggerlo prima: è la memoria
   distillata delle fasi già chiuse (§8). I logbook integrali in
   `docs/logbook/archive/` **non** si leggono in onboarding.
5. **`CHANGELOG.md`** — sezione `[Unreleased]`: cosa è già cambiato ma non rilasciato.
6. **`docs/runs/`** — l'ultimo report di test: è lo stato *misurato* del sistema
   (PASS/XFAIL/FAIL). Se contraddice un documento, comanda il report.

Vietato: iniziare a modificare codice, aprire issue, o proporre piani alternativi
prima di aver completato i punti 1–6. Se un documento qui citato non esiste ancora,
la prima azione della sessione è segnalarlo nel logbook, non ricostruirlo a memoria.

## 2. Stato corrente (da aggiornare a fine di OGNI sessione — vedi §6)

| Campo | Valore |
|---|---|
| **Fase attiva** | **Fase 1 — Raggiungibilità e riproducibilità**, release `v0.0.2`. Fase 0 chiusa il 26/08 col tag `v0.0.1` |
| **Baseline** | `v0.0.0-baseline` → `5eb456a` (lightweight) · `v0.0.1` → `d3053be` (annotato) · `develop` allineato col merge `60269f7` |
| **Branch di lavoro** | `release/v0.0.2`, aperto il 27/08 da `develop` @ `7ae7181` (merge della chiusura Fase 0 + O8/O9) |
| **Ultimo run T0** | [`docs/runs/20260827-0859-envw-9082a02.md`](docs/runs/20260827-0859-envw-9082a02.md) — prima nightly reale su ENV-W (`workflow_dispatch`, run 33056266125) contro `9082a02`, cioè **prima** dei commit di B: `{"PASS": 5, "FAIL": 1, "XFAIL": 4, "XPASS": 2}`. **#42 verificato per misura** (`ollama_data` sopravvive al teardown, modelli elencati, blob identici); **Superato da [`docs/runs/20260827-1148-envw-6b377a3.md`](docs/runs/20260827-1148-envw-6b377a3.md)**: due nightly consecutive contro `6b377a3` in stato **esclusivo**, entrambe con `actions/checkout` verde ([#46](https://github.com/danielesalpietro/NORTHSTREAM/issues/46)/P-12 **dimostrato**) e **T0.6 PASS con modelli veri** in entrambe — il progression test della release è **misurato**, P-1 chiuso nel comportamento; T0.2/T0.3 PASS in entrambe (nessuna regressione da #17). Entrambe concludono `failure` per T0.4/T0.5, che **non sono regressioni**: a freddo falliscono a caso (tre run, tre insiemi diversi), a stack caldo passano 2 giri su 2 — è A-8/#39. **P-11/#45 verificato** sui tre stati del volume `kafka_data`. Nel run archiviato qui, il FAIL di T0.5 **non è una regressione** ma un artefatto di run a freddo (stesso commit: PASS 3/3 a stack caldo). Metro invariato: [`docs/runs/20260826-2053-envw-5eb456a-baseline.md`](docs/runs/20260826-2053-envw-5eb456a-baseline.md) — **run di riferimento**: suite `full` contro il tag baseline su ENV-W con modelli reali, 5 PASS + 6 XFAIL + 1 XPASS, `RESULT: OK`. È il metro: ogni release si misura contro questa tabella. L'XPASS di T0.10 **non** è un difetto risolto (issue #40) |
| **Prossima azione** | **T0.6/T0.2/T0.3/P-11/P-12 tutti chiusi e verificati su ENV-W** (due nightly reali consecutive contro `6b377a3`, modelli veri): P-1/P-3/P-4/P-7 chiusi nel comportamento. La stessa verifica ha trovato un terzo lato dello stesso meccanismo, **P-13/[#48](https://github.com/danielesalpietro/NORTHSTREAM/issues/48)**: `.gitkeep` (P-12) salva il checkout pulito ma non l'aggiornamento di un clone esistente — `trino/catalog` già root-owned blocca `git pull` con `Permission denied` e lascia l'albero a metà. **Sessione B ha implementato**: nota di migrazione unica in CHANGELOG (Breaking, sezione riscritta per coprire P-11+P-13 insieme, ordine esplicito "rimuovi prima di `git pull`") e preflight esteso a directory non scrivibili nell'intero albero del repo, non solo il volume Docker. **Non verificabile in CI per costruzione** (stesso motivo di P-11/P-12): la verifica reale spetta a ENV-W, stesso protocollo a tre stati. **Prossimo passo**: ENV-W verifica P-13 (clone con `trino/catalog` root-owned creato deliberatamente); se conferma, l'unico passo restante della fase è #20 (gate di release, CHANGELOG → versione, README a fine release, tag) |
| **Finestra ENV-W** | **Manutenzione attiva dal 27/08 ~10:00Z per 12 h (fino alle ~22:00Z) — la Z8 è in esclusiva, estendibile su richiesta all'owner**. È lo stato in cui le misure GPU valgono (§2.1 del piano). **Esito già acquisito: `granite4:32b-a9b-h` entra davvero nella 3090** — 19 788 MiB su 24 576, **100% GPU**, margine 4,7 GiB, contesto 32k, 101 s a freddo e 1-3 s a caldo (`docs/runs/20260827-1115-envw-c424928-vram32b.md`). L'assunzione su cui poggia la matrice EVAL di beta1 non è più un'assunzione. **Nota di metodo dalla stessa misura**: la prima lettura dava `100% CPU` e 9 MiB — cioè *confermava* l'ipotesi attesa ("19 GB non entrano") ed era un artefatto (container Ollama ricreato senza passthrough GPU). È stata archiviata come falsa invece che cancellata: **un artefatto che conferma l'ipotesi attesa è quello che ha meno probabilità di essere controllato**. In corso: analisi di T0.4/T0.5 nelle due nightly contro `6b377a3` e prova a secco dell'harness `bench/soak/`; a seguire, se verde, **soak lungo** con estensione della finestra |
| **Sessioni operative attive** | **Sessione A** `session_01G56RvSh4eQyZuJ7UjZFJ9i` (`claude-sonnet-5`): **#41 e #42 corretti e pushati** su `release/v0.0.2` (commit `83b416c`, `5534ef7`) — turno chiuso lato sessione (CLAUDE.md §7), resta da innescare una nightly reale su ENV-W per il criterio di verifica di #42 · **Sessione B** `session_01AJY9RuEEEzZ8ZzBazDNmbF` (`claude-sonnet-5`): **#17 → #16 → #18 → #19 committati**, turno in chiusura — v. logbook per lo stato di dettaglio · **ENV-W Z8** `session_011JstTbN3FioNR334Y9ZWnf` (bridge, host di verifica: esegue e riferisce, **non committa codice**). A e B hanno lavorato in parallelo sullo stesso branch, coordinandosi con `git pull --rebase` (§3.8) su CHANGELOG, logbook e §2. Le prime A e B (`…01Gu8Zq`, `…01GQuK9`) sono state archiviate senza aver prodotto nulla: v. la lezione in §7 |
| **Blocchi aperti** | **[#42](https://github.com/danielesalpietro/NORTHSTREAM/issues/42) chiuso e verificato per misura il 27/08** (nightly reale su ENV-W, run 33056266125): il teardown fa `down` + rimozione esplicita dei soli `kafka_data`/`postgres_data`/`qdrant_data`, e dopo il run `ollama_data` esiste ancora con i modelli elencati e i blob bit-identici. **Il blocco su `RUN_NIGHTLY` è quindi caduto, ma la variabile resta spenta**: accenderla è una decisione dell'owner, non una conseguenza automatica. **Nuovo, dalla verifica**: la nightly avvia lo stack e misura subito, dentro la finestra cieca di A-8/[#39](https://github.com/danielesalpietro/NORTHSTREAM/issues/39) e col primo caricamento dei modelli in corso — T0.5 e T0.9 hanno dato verdetti diversi dal reale. Serve un *warm-up gate* (issue sorella di #39/#40, **da aprire**) prima che un FAIL della nightly significhi qualcosa. La 3090 di ENV-W è inoltre **condivisa**: fuori dalle finestre di manutenzione la macchina è **noleggiata su vast.ai** (chiarito dall'owner il 27/08 — non è un container fuori posto, è il modello d'uso della macchina). Durante la verifica un tenant occupava 11,6–22,3 GiB dei 24,5. **ENV-W ha quindi due stati**: *manutenzione* (GPU nostra, misure GPU valide) e *noleggio* (GPU di terzi, misure GPU inutilizzabili e `granite4:32b-a9b-h` che non entra). **La macchina è disponibile per tutto il tempo necessario, ma la finestra va dichiarata con anticipo**: chiudere la GPU a un noleggio in corso viola la policy di vast.ai. Chi pianifica un run GPU dichiara durata e anticipo secondo la tabella di `docs/piano_ricovero.md` §2.1, e prima di una finestra prenotata esegue una **prova a secco** dello stesso comando: una finestra si spende misurando, non debuggando. Prima di pianificare un run GPU su ENV-W — nightly schedulata, matrice EVAL, soak — **si chiede all'owner in quale stato sia**, finché [#44](https://github.com/danielesalpietro/NORTHSTREAM/issues/44) (Fase 2) non rende il controllo automatico: pre-check che rifiuta il run, campionamento durante, esclusività registrata nel `manifest.json`. È anche il primo argomento contro l'accensione di `RUN_NIGHTLY` su schedule: alle 02:30 nessuno sa in che stato sia la macchina · [#40](https://github.com/danielesalpietro/NORTHSTREAM/issues/40) T0.10 non robusto (Fase 3) · P-5 verificabile solo su ENV-L o con `mem_limit` (Fase 2, T-PROF) · RP-0 non eseguito ma **opzionale**: la matrice EVAL entra nella 3090 · limite settimanale `claude-fable-5` esaurito fino al ~28/08 |
| **Tracking fasi** | ~~Fase 0 [#3](https://github.com/danielesalpietro/NORTHSTREAM/issues/3)~~ **chiusa** · **Fase 1 [#4](https://github.com/danielesalpietro/NORTHSTREAM/issues/4) ← corrente** · Fase 2 [#5](https://github.com/danielesalpietro/NORTHSTREAM/issues/5) · Fase 3 [#6](https://github.com/danielesalpietro/NORTHSTREAM/issues/6) · Fase 4 [#7](https://github.com/danielesalpietro/NORTHSTREAM/issues/7) · **Fase 6 [#43](https://github.com/danielesalpietro/NORTHSTREAM/issues/43) — casi d'uso ed Explain Change (v0.0.6), inserita fra la 4 e la 5** · Fase 5 [#8](https://github.com/danielesalpietro/NORTHSTREAM/issues/8) beta1 — una fase si apre solo col tag della precedente |
| **Issue di riferimento** | [#2](https://github.com/danielesalpietro/NORTHSTREAM/issues/2) (review) · [#1](https://github.com/danielesalpietro/NORTHSTREAM/issues/1) (Norimberga: decisione in Fase 5, issue #36) |

## 3. Regole non negoziabili

1. **Nessun "fatto" senza test.** Un fix è tale solo quando il test XFAIL designato
   flippa a PASS e nessun PASS regredisce (semantica in `docs/piano_ricovero.md` §4).
   Finché `bench/` non esiste, ogni verifica manuale va trascritta nel logbook con
   comando eseguito e output osservato.
2. **Scope della fase.** Si lavora solo sullo scope della release corrente (§6 del
   piano). I layer di scenografia (Flink, Iceberg, metastore MinIO, K8s) sono
   congelati fino a dopo v0.1.0-beta1: qualunque tentazione va annotata nel logbook
   come proposta, non implementata.
   **Precisazione (27/08): il vincolo riguarda le modifiche al comportamento del
   sistema, non gli strumenti di misura.** La regola "la fase N si apre col tag
   della N−1" esiste per la non-regressione: due release che cambiano lo stesso
   comportamento in parallelo rendono impossibile attribuire una regressione. Non
   si applica quindi a: (a) **infrastruttura di test** — costruire fixture, suite
   EVAL, o irrobustire un test può essere anticipato di fasi, perché il codice di
   test non è il sistema misurato; (b) **esecuzione di run** — soak, matrici,
   nightly: misurano, non modificano, e girano nelle ore morte della Z8 a costo
   cloud zero. Anticipare questi due è incoraggiato e va annotato nel logbook della
   fase che li ospita, citando la fase che li consumerà. Restano invece sequenziali
   tutte le modifiche a `stream-agent/`, ai compose e agli script.
3. **Verità documentale.** Mai aggiungere al README un claim non coperto dal
   comportamento reale. Ogni path citato deve esistere; ogni endpoint in tabella
   deve rispondere.
4. **Git.** Niente commit diretti su `develop` (eccezione: la fase 0 usa il branch di
   sessione già aperto). Release branch `release/vX.Y.Z`, tag a fine release. Niente
   PR senza richiesta esplicita dell'owner. Niente force-push su branch altrui.
5. **Output dei run.** Ogni esecuzione di test/eval segue la convenzione `RUN_ID` e
   l'archiviazione di `docs/piano_ricovero.md` §3. Su RunPod: **nessun pod si spegne
   prima del recupero verificato (checksum) degli output.**
6. **Credenziali e sicurezza.** Le credenziali demo (demo/demo, admin/Password123!)
   sono note e accettate per il lab locale: non introdurne di nuove hardcoded, non
   esporre nuovi servizi su `0.0.0.0` (target: `127.0.0.1`, da v0.0.2).
7. **Lingua.** Documentazione di progetto (`docs/`, logbook, CHANGELOG) in italiano;
   codice, commenti nel codice e README in inglese (pubblico del repo).
8. **Una sola sessione per scope.** Ogni fase (e ogni issue) ha una sola sessione
   che la lavora, registrata nella riga "Sessioni operative attive" di §2. Prima
   di creare una sessione per un lavoro già assegnato, **verificarne lo stato
   reale**: una sessione ferma per limite di crediti non è morta — riprende da
   sola quando l'owner le cambia modello, e nel frattempo una sostitutiva
   creerebbe due sessioni che pushano sullo stesso branch. In caso di doppione:
   sopravvive quella più avanti, l'altra si interrompe e archivia, e chi resta
   viene allineata sullo stato che si è persa. Sessioni con scope diversi sullo
   stesso branch (es. Fase 0 cloud + ENV-W) sono invece legittime: si coordinano
   con `git pull --rebase` e con entry di logbook distinte.

## 4. Direttive di aggiornamento documentale — per ogni fase

Tre documenti hanno cadenze di aggiornamento **obbligatorie**:

### `LOGBOOK_<fase>.md` (in `docs/logbook/`) — ogni sessione, sempre
Un file per fase del release train: `LOGBOOK_baseline.md`, `LOGBOOK_v0.0.1.md`,
`LOGBOOK_v0.0.2.md`, … Ogni file ha **due livelli**:

- una **SINTESI DI FASE** in testa — l'unica parte che si riscrive, aggiornata da
  ogni sessione alla chiusura. Contiene: dove siamo, le decisioni prese col loro
  perché, i numeri misurati, cosa è aperto, il prossimo passo. È ciò che legge
  una sessione nuova, e alla chiusura della fase **diventa** l'ESITO FASE (§8):
  mantenerla viva rende la compressione finale quasi gratuita, invece di un
  lavoro da fare sotto pressione a fine fase;
- le **entry**, append-only, che non si riscrivono mai.

Ogni sessione **apre** leggendo testa + ultima entry, e **chiude** appendendo una
nuova entry con questo template *e* aggiornando la testa:

```markdown
## AAAA-MM-GG — <ambiente: ENV-L/W/R o remoto> — <autore/sessione>
- **Obiettivo della sessione**:
- **Fatto**: (con SHA dei commit)
- **Decisioni prese**: (e perché — le alternative scartate valgono quanto le scelte)
- **Test eseguiti**: comando → esito (PASS/FAIL/XFAIL), o "nessuno" — esplicito
- **Costo della sessione**: modello, durata, token (cache read / output), costo
  nozionale — da `get_session`. Per le sessioni **bridge** (Claude CLI locale)
  il campo `usage` non è esposto: scrivere "non misurabile", mai stimare.
- **Non funziona / sospeso**:
- **Prossimo passo per la sessione successiva**: (una riga azionabile, non un tema)
```

Il campo **Costo della sessione** serve a misurare lo sforzo del processo, non
solo il prodotto: con l'abbonamento MAX il denaro è nozionale, ma i token
consumati sono il proxy diretto del budget di rate limit, ed è l'unico modo per
capire a posteriori quali tipi di lavoro sono cari e perché (v. §7). Prima
misurazione e lezioni ricavate: entry del 26/08/2026 in `LOGBOOK_baseline.md`.

Il logbook non si riscrive mai: solo append. È la memoria lunga del progetto.
Quando una fase si chiude (tag), il logbook della fase si chiude con una entry
finale "ESITO FASE" e se ne apre uno nuovo.

### `CHANGELOG.md` — a ogni commit che cambia comportamento
Formato Keep a Changelog. Ogni commit che tocca codice, compose o comportamento
documentato aggiunge una riga sotto `[Unreleased]` (Added/Changed/Fixed/Removed),
**citando il finding o l'obiettivo** (es. "Fixed: dual Kafka listener (P-1, O3.1)").
Al rilascio, `[Unreleased]` diventa la sezione della versione con data, e il gate
di release verifica che ogni riga abbia il suo test di riscontro. I commit
solo-documentazione (logbook, runs) non richiedono riga di CHANGELOG.

### `README.md` — solo a fine release, mai a metà
Il README descrive **lo stato rilasciato**, non il lavoro in corso: si aggiorna nel
release branch, come ultimo commit prima del tag, e solo per le parti il cui
comportamento è cambiato ed è coperto da test verde. Il linter di verità (T0.12)
deve passare dopo ogni modifica al README. Vietato aggiornare il README da
`develop` tra una release e l'altra (eccezione: correzione di un claim falso, che è
sempre urgente).

### Inoltre, a ogni run di test
`docs/runs/<RUN_ID>.md` committato (riassunto: tabella esiti + link ai numeri),
grezzi in `~/NORTHSTREAM-archive/<RUN_ID>/` — mai nel repo.

## 5. Controllo avanzamento e test funzionali

- **Prima di dichiarare avanzamento**: eseguire il sottoinsieme T0 pertinente allo
  scope toccato (dopo v0.0.1: `bench/t0/run.sh --suite <core|full>`; in fase 0:
  verifiche manuali trascritte). "Compila" o "il container parte" non è avanzamento;
  avanzamento = esito test diverso da prima, nel verso giusto.
- **Cruscotto di fase** = tabella §2 + ultimo `docs/runs/`. Se i due divergono,
  aggiornare §2, non discutere a memoria.
- **Ogni fase ha come definition of done** i suoi progression test dichiarati nella
  tabella release del piano (§6) — non una sensazione di completezza.
- **Non-regressione**: prima di ogni push su un release branch, rieseguire almeno i
  T0 marcati PASS nell'ultimo run archiviato. Un PASS che diventa FAIL blocca il
  push, sempre.
- **Una misura che conferma l'ipotesi attesa va controllata due volte** (regola nata
  da due casi nello stesso giorno, 27/08). Prima: `granite4:32b-a9b-h` misurato a
  `100% CPU` e 9 MiB di VRAM — cioè "i 19 GB non entrano nei 24", che è ciò che ci
  aspettavamo; era un artefatto, il container Ollama era stato ricreato senza
  passthrough GPU, e a misura corretta il modello entra al 100% in GPU. Seconda: il
  campionatore del soak riportava lo slot di replica `"active": false` a ogni
  campione — non perché lo slot fosse inattivo, ma perché il confronto era fatto
  contro `'t'` mentre Postgres scriveva `true`. **Un artefatto che conferma l'ipotesi
  attesa è quello che ha meno probabilità di essere controllato**, ed entrambi hanno
  depistato chi li leggeva. Corollario per chi scrive strumenti di misura: **un campo
  derivato deve poter distinguere "falso" da "non l'ho potuto sapere"** — `null` con
  un errore popolato, mai un booleano che collassa in silenzio. Una costante
  travestita da misura è peggio di un campo assente: il campo assente si nota.
- **Le anomalie si scrivono quando si incontrano, non alla chiusura.** Una sessione
  bridge (ENV-W) che tiene un errore solo nel proprio terminale lo rende invisibile
  alla supervisione: il canale è a senso unico, e ciò che non finisce in un commit
  non esiste. Il 27/08 due difetti reali (P-11 volume Kafka, P-12 `trino/catalog`)
  sono arrivati alla supervisione **solo perché la sessione si è bloccata** e ha
  dovuto chiedere. Chi lavora su un ambiente reale annota l'anomalia nel logbook
  *mentre* la incontra — bastano tre righe — perché è lì che si decide se è un
  incidente locale o un finding del prodotto, e la §6 (entry a fine sessione) arriva
  troppo tardi per quella decisione.
- **Ambienti**: scelta secondo `docs/piano_ricovero.md` §2 (ENV-L → ENV-W → ENV-R).
  Una sessione che non ha accesso ad alcun ambiente di esecuzione (es. sessione
  remota senza Docker) lo dichiara nel logbook e si limita a lavoro statico:
  niente claim di esito test non eseguiti.
- **Accesso a ENV-W (Z8)**: raggiungibile via SSH **solo dalle sessioni locali
  dell'owner** (chiave privata sul laptop dell'owner; IP pubblico dinamico, cambia
  a discrezione dell'ISP). Le coordinate di connessione NON vanno mai committate
  in questo repository (è pubblico): restano in un file locale dell'owner, fuori
  repo. Le sessioni remote e la CI raggiungono ENV-W esclusivamente tramite il
  **runner GitHub Actions self-hosted** registrato sulla Z8 (connessione outbound:
  immune ai cambi di IP e non richiede distribuzione di chiavi) — workflow
  `ci-nightly` con label `[self-hosted, env-w]`, esecuzione via schedule o
  `workflow_dispatch`. Se il runner è offline, l'unica via è chiedere all'owner
  di intervenire dalla sessione locale.
- **Sessione Claude CLI su ENV-W**: sulla Z8 è installata la Claude CLI. Per i
  compiti che richiedono esecuzione reale (collaudo #10, run baseline #13, soak,
  registrazione runner), l'owner attiva **su richiesta** una sessione locale
  sulla Z8. Quella sessione si auto-assegna così: clone/aggiornamento del repo,
  checkout del branch indicato dalla richiesta, onboarding da questo file (§1),
  poi esecuzione della issue assegnata. Le sessioni remote non devono aspettarsi
  di raggiungere la Z8 in altro modo: se serve ENV-W, si chiede all'owner di
  attivare la sessione, indicando issue e branch.
  **Avviarla sempre dentro `tmux` (o `screen`)**: se la CLI gira direttamente in
  una sessione SSH, un timeout della connessione uccide la sessione a metà
  lavoro — è già successo durante un deploy, costando il riavvio da capo.
  Con `tmux new -s northstream` la sessione sopravvive alla caduta e si
  riprende con `tmux attach -t northstream`. Una sessione ENV-W che riprende
  dopo una caduta **non riparte da zero**: verifica prima lo stato reale
  (`docker compose ps`, `docker images`, `ollama list`, `git log`) e riprende
  dal primo passo mancante.

## 6. Checklist di chiusura sessione (obbligatoria, in ordine)

1. Lavoro committato con messaggi che citano finding/obiettivo (niente lavoro solo
   nel working tree a fine sessione).
2. Entry nel logbook di fase **e aggiornamento della SINTESI DI FASE** in testa
   al file (template e regole §4): la testa è ciò che leggerà la sessione nuova.
3. `CHANGELOG.md` aggiornato se è cambiato comportamento.
4. Tabella "Stato corrente" (§2 di questo file) aggiornata: fase, ultimo run,
   prossima azione, blocchi.
5. Eventuali run archiviati secondo la convenzione (`docs/runs/` + archivio locale);
   pod RunPod spenti **solo dopo** recupero verificato.
6. Push sul branch di lavoro.
7. Se la sessione ha aperto questioni che solo l'owner può decidere: elencarle in
   fondo alla entry del logbook sotto "Decisioni richieste all'owner".

Una sessione che si interrompe bruscamente e non completa la checklist lascia la
sessione successiva cieca: se riprendi un lavoro senza entry di chiusura, la prima
azione è ricostruire lo stato dai commit e scrivere tu l'entry mancante, marcata
"(ricostruita a posteriori)".

## 7. Scelta del modello ed economia dei token

L'owner ha delegato alla supervisione la scelta del modello per ogni sessione
operativa (26/08/2026). L'owner ha un abbonamento **MAX**: i token non si pagano
a consumo, quindi **la valuta scarsa non è il denaro, sono i rate limit** —
finestra a 5 ore e limite settimanale per modello. Quando si esauriscono, il
lavoro si ferma e si aspetta: il limite settimanale su `claude-fable-5` è già
stato bruciato una volta, bloccando una sessione operativa per circa due giorni.

Criterio, quindi: **il modello più leggero che non thrasha**. Non per risparmiare
denaro, ma per non restare senza capacità nel momento sbagliato — e perché una
sessione che gira a vuoto consuma più budget di un modello capace che risolve al
primo colpo.

| Tipo di lavoro | Modello | Dove |
|---|---|---|
| Configurazione meccanica, già specificata dal piano, verificabile in CI | `claude-sonnet-5` | Fase 1 (listener Kafka, pin immagini, binding, preflight), Fase 2 (profiles, `mem_limit`, catalogo Trino) |
| Progettazione su codice delicato, con gate di qualità da interpretare | `claude-opus-5` | Fase 3 (retrieval, point-id, recency, `/health`), Fase 5 (lettura della matrice EVAL, decisioni di release) |
| Integrazione fiddly con prodotto poco conosciuto | `claude-sonnet-5`, escalation a `claude-opus-5` se si blocca due volte sullo stesso punto | Fase 4 (ingestion OpenMetadata) |
| Qualunque cosa | mai `claude-fable-5` senza richiesta esplicita dell'owner | consuma budget al doppio della velocità di opus-5, ed è il pool già esaurito |

**Promozione fino al 31/08/2026**: i limiti settimanali sono potenziati del 50%.
Dopo quella data tornano allo standard, cioè un terzo in meno. Le fasi costose
(Fase 3 su tutte: ridisegno retrieval + suite EVAL + soak) vanno anticipate
dentro la finestra potenziata, non rimandate dopo.

### Triage di un sotto-task, in quest'ordine

Prima di assegnare un modello a un pezzo di lavoro, due domande più economiche:

1. **Serve un modello?** Verificare che un tag esista, estrarre un numero da un
   JSON, controllare l'esito di un workflow, contare i punti di una collection:
   sono `grep`, `jq`, `git`, `curl`. Costo zero, esito deterministico, nessuna
   allucinazione possibile. La maggior parte delle verifiche di questo progetto
   sta qui.
2. **Può girare in locale?** La Z8 ha una 3090 e i modelli Granite già scaricati.
   Digestione di log voluminosi, riassunto di output di container, estrazione
   strutturata: girano lì a costo cloud **zero**, non "ridotto". Vincolo: l'output
   va verificato meccanicamente (un grep che controlli che errori, exit code e
   nomi dei test falliti siano sopravvissuti alla compressione).
3. **Solo allora, quale tier** — secondo la tabella sopra.

**Quando frammentare, e quando no.** Ogni sessione separata ripaga da zero
l'onboarding (§8: ~29.000 token, che restano in contesto per tutti i suoi turni).
Un sotto-task merita una sessione propria solo se è **autosufficiente** (briefing
completo scrivibile in poche righe) e **abbastanza grosso** da ripagare quel costo.
Sotto quella soglia la delega è una perdita netta, anche su un modello più
economico.

**Non si delega mai verso il basso**: diagnosi, decisioni di gate, giudizio su
cosa significhi un esito di test, e qualunque cosa richieda di collegare fatti
distanti. I tre ritrovamenti migliori della Fase 0 — il `bash -lc` che perde il
PATH, l'istruzione contraddittoria su `RUN_NIGHTLY`, l'XPASS di T0.10 come
artefatto della dimensione del corpus — non vengono dal macinare dati, vengono da
una sessione che teneva insieme il quadro. Frammentarle produce cinque sessioni
che fanno bene il proprio pezzo mentre nessuno vede il pattern.

**Il driver dominante non è il modello: è la lunghezza della sessione.**
La sessione Fase 0 ha totalizzato 63 milioni di token di lettura da cache perché
è rimasta viva attraverso sette cicli di CI, rileggendo l'intera conversazione a
ogni turno. Da qui quattro regole che pesano più della scelta del modello:

1. **Scope stretto**: una sessione per issue o per piccolo gruppo di issue
   affini, non per fase intera.
2. **Briefing completo all'avvio**: ogni cosa che la sessione deve scoprire da
   sola diventa contesto che poi rilegge a ogni turno successivo.
3. **Non restare vivi ad aspettare**: dopo un push che innesca la CI, chiudere
   il turno. Un check successivo rilegge solo ciò che serve, invece di tenere in
   vita una conversazione che cresce.
4. **Prima di creare una sessione, verificare se una esistente può riprendere**
   (§3.8): una sessione ferma per limite di crediti riparte con un cambio
   modello, e ricrearla raddoppia il costo del contesto già pagato.
5. **Agganciare sempre sorgente e branch alla creazione.** Una sessione creata
   senza `source_url` e `source_revision` parte in un container **senza il
   repository**: fa l'onboarding a vuoto, non trova `CLAUDE.md`, e si blocca
   chiedendo conferma che il compito sia legittimo. Costo dell'errore, misurato
   il 27/08 su due sessioni di Fase 1 ricreate da capo: ~0,49 $ ciascuna e zero
   lavoro prodotto. Un briefing perfetto non compensa un container vuoto.

## 8. Compressione della memoria

Il percorso di onboarding (§1) viene letto al primo turno e **resta in contesto
per tutti i turni successivi**: il suo peso si moltiplica per la lunghezza della
sessione. Misura del 26/08/2026, a Fase 0: **101 KB, ~28.800 token**. Con sei
logbook di fase diventerebbe tre o quattro volte tanto, a parità di utilità.

Comprimere qui significa **distillare, mai cancellare**: l'originale si sposta in
`docs/logbook/archive/`, git conserva tutto, e il percorso di onboarding resta di
dimensione costante mentre il progetto cresce.

**Non si comprime mai** (se una di queste sparisce, la compressione è una
regressione, non un'ottimizzazione):
1. Le decisioni, il loro perché, e **le alternative scartate**.
2. I numeri misurati: esiti dei test, misure, costi.
3. Gli item aperti: blocchi, sospesi, decisioni richieste all'owner.
4. Le lezioni operative che hanno generato una regola di questo file.

**È rumore, e si comprime**: la narrazione del *come* (sette giri di CI → una
riga con i due difetti trovati); lo stato ormai superato (un blocco poi risolto,
un "prossimo passo" già eseguito); la duplicazione dello stesso fatto tra §2,
logbook e CHANGELOG; le minuzie di coordinamento fra sessioni, una volta che la
fase è chiusa.

**Quando**: obbligatoriamente alla chiusura di ogni fase (tag). Il lavoro è quasi
già fatto, perché la **SINTESI DI FASE** in testa al logbook (§4) è mantenuta
viva da ogni sessione: alla chiusura si congela come ESITO FASE, si copia in
`docs/logbook/SINTESI_fasi_chiuse.md` (una pagina per fase, non di più) e
l'originale integrale va in `archive/`. Fuori dalle
chiusure, quando il percorso di onboarding supera **40.000 token**.

**Verifica** (vale la regola §3.1: nessun "fatto" senza riscontro): la sintesi è
valida solo se, leggendo *solo* lei, una sessione nuova sa dire quali decisioni
sono state prese e perché, quali numeri sono stati misurati, e che cosa è
rimasto aperto. Se non ci riesce, la compressione ha perso informazione: si
rifà, non si accetta.

**Nota sul livello sessione**: la entry di logbook **è** la forma compressa del
contesto di una sessione. Il criterio di qualità di una entry è esattamente
questo — la sessione successiva deve poter proseguire leggendo lei sola, senza
la conversazione che l'ha prodotta.

**Metrica**: il peso del percorso di onboarding va riportato nel campo "Costo
della sessione" (§4) a ogni chiusura di fase, per vedere se resta piatto.

## 9. Riferimenti rapidi

- Stack base: `docker compose -f docker-compose-northstream-ai.yml up -d` ·
  addon: `./start-addon.sh` (`--gpu` per passthrough) · connettore CDC:
  `./register-connector.sh` · demo: `./demo-compare.sh`
- Agent: `stream-agent/app.py` (porta 8500) · generatore: `data-generator/` ·
  schema: `init/postgres/001-init-sales-db.sql` · connettore:
  `connectors/postgres-source-connector.json`
- Modelli/tier: `examples/{minimal,recommended,optimal}/.env`
- Nota nota-bene per chi tocca l'agent: il retrieval attuale contiene il boost
  keyword su `KNOWN_SITES` (finding A-1) — viene rimosso in v0.0.4, non
  "sistemato" prima per altre vie.
