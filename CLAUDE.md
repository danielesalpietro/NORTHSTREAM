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
4. **`docs/logbook/LOGBOOK_<fase-corrente>.md`** — che cosa hanno fatto, deciso e
   lasciato in sospeso le sessioni precedenti di questa fase. **Ultima entry = punto
   di ripartenza.**
5. **`CHANGELOG.md`** — sezione `[Unreleased]`: cosa è già cambiato ma non rilasciato.
6. **`docs/runs/`** — l'ultimo report di test: è lo stato *misurato* del sistema
   (PASS/XFAIL/FAIL). Se contraddice un documento, comanda il report.

Vietato: iniziare a modificare codice, aprire issue, o proporre piani alternativi
prima di aver completato i punti 1–6. Se un documento qui citato non esiste ancora,
la prima azione della sessione è segnalarlo nel logbook, non ricostruirlo a memoria.

## 2. Stato corrente (da aggiornare a fine di OGNI sessione — vedi §6)

| Campo | Valore |
|---|---|
| **Fase attiva** | Fase 0 — Baseline, release `v0.0.1` in preparazione |
| **Baseline** | `develop` @ `5eb456a` — tag `v0.0.0-baseline` **creato e pubblicato** dalla sessione ENV-W |
| **Branch di lavoro** | `release/v0.0.1` (merge di `claude/project-plan-review-473nje` + harness `bench/` + CI + fix documentali O2) |
| **Ultimo run T0** | [`docs/runs/ci-smoke-33008193653.md`](docs/runs/ci-smoke-33008193653.md) — suite `ci` verde su runner GitHub con mock-ollama: 4 PASS + 2 XFAIL (A-3, A-5 ora **misurati**). **Mai eseguita** la suite completa con modelli reali: serve ENV-L/ENV-W (issue #13) |
| **Prossima azione** | [#10](https://github.com/danielesalpietro/NORTHSTREAM/issues/10) collaudo in macchina e [#13](https://github.com/danielesalpietro/NORTHSTREAM/issues/13) run T0 contro il tag baseline (ENV-W) → poi [#15](https://github.com/danielesalpietro/NORTHSTREAM/issues/15) tag `v0.0.1` |
| **Sessioni operative attive** | Fase 0 cloud (`session_01GaPWBapF7LMthmjyPoC9Cd`, opus-5): #11/#12/#14 — **completate** · ENV-W Z8 (`session_012WiW8ep5PVnGmm7exagMDu`, bridge): #10 + tag baseline. Entrambe pushano su `release/v0.0.1` |
| **Blocchi aperti** | RP-0 (probe DinD su RunPod, issue #34) non ancora eseguito · runner self-hosted ENV-W + variabile `RUN_NIGHTLY` da configurare per attivare `ci-nightly` (issue #12) · limite settimanale claude-fable-5 esaurito fino al ~28/08 (usare opus-5 o sonnet-5) |
| **Tracking fasi** | Fase 0 [#3](https://github.com/danielesalpietro/NORTHSTREAM/issues/3) · Fase 1 [#4](https://github.com/danielesalpietro/NORTHSTREAM/issues/4) · Fase 2 [#5](https://github.com/danielesalpietro/NORTHSTREAM/issues/5) · Fase 3 [#6](https://github.com/danielesalpietro/NORTHSTREAM/issues/6) · Fase 4 [#7](https://github.com/danielesalpietro/NORTHSTREAM/issues/7) · Fase 5 [#8](https://github.com/danielesalpietro/NORTHSTREAM/issues/8) — ogni fase ha sub-issue collegate; una fase si apre solo col tag della precedente |
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
`LOGBOOK_v0.0.2.md`, … Ogni sessione di lavoro **apre** leggendo l'ultima entry e
**chiude** appendendone una nuova con questo template:

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
2. Entry nel logbook di fase (template §4).
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

## 8. Riferimenti rapidi

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
