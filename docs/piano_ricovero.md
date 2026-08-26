# Piano di ricovero NORTHSTREAM → v0.1.0-beta1

- **Data**: 26 agosto 2026 · **Supervisione**: Claude (questa sessione) · **Owner**: Daniele Salpietro
- **Baseline**: `develop` @ `5eb456a`, da taggare **`v0.0.0-baseline`** prima di qualunque altro commit
- **Input**: [`docs/review_tecnica.md`](review_tecnica.md) (finding P-*, A-*, G-*, D-*) e issue [#2](https://github.com/danielesalpietro/NORTHSTREAM/issues/2)
- **Traguardo**: **v0.1.0-beta1** — ogni claim pubblico vero, ogni fix coperto da un test che prima falliva e ora passa, su almeno due ambienti indipendenti

Il principio metodologico è uno solo: **ogni difetto della review diventa un test che oggi fallisce; ogni release fa passare i test che dichiara di sistemare senza rompere quelli che già passavano.** Niente "fixed" senza un output verificabile che lo dimostri.

---

## 1. Obiettivi e sotto-obiettivi

| ID | Obiettivo | Sotto-obiettivi | Finding chiusi |
|---|---|---|---|
| **O1** | Baseline misurata, non presunta | O1.1 tag `v0.0.0-baseline` · O1.2 harness di test eseguibile contro develop *senza modificarla* · O1.3 report baseline committato con PASS/XFAIL registrati | — |
| **O2** | Verità documentale | O2.1 README allineato al sistema reale · O2.2 demo-script con la sezione "come funziona davvero il retrieval" · O2.3 layout/License/endpoint corretti | D-1, D-2, D-3, parte P-1 |
| **O3** | Raggiungibilità e riproducibilità | O3.1 doppio listener Kafka · O3.2 immagini pinnate a versione+digest · O3.3 binding `127.0.0.1` · O3.4 preflight Linux (`vm.max_map_count`) · O3.5 `.env` → `.env.example` | P-1, P-3, P-4, P-6, P-7, P-8 |
| **O4** | Stack onesto sulle risorse | O4.1 compose profiles `core`/`lakehouse`/`governance` · O4.2 `mem_limit` per servizio e tier veri · O4.3 `trino/postgres.properties` | P-2 (metà Postgres), P-5, §4.2/4.3 review |
| **O5** | Agent robusto e retrieval onesto | O5.1 point-id deterministici `(topic,partition,offset)` · O5.2 timestamp nel payload + filtro recency · O5.3 retrieval con filtro payload al posto del boost keyword · O5.4 `/health` reale · O5.5 `group_id` + logging strutturato | A-1…A-7 |
| **O6** | Governance minima vera | O6.1 ingestion OpenMetadata di Postgres e Trino · O6.2 lineage visibile via API | riga OpenMetadata §2 review |
| **O7** | Qualità AI misurata | O7.1 eval set fisso grounded-vs-baseline con asserzioni deterministiche · O7.2 matrice modelli Granite su RunPod · O7.3 scelta default motivata dai numeri | A-1 (causa), G-3 |

Fuori scope fino a dopo la beta1 (decisione §4.4 della review): Flink job, Iceberg, metastore per MinIO, K8s. La storyline del README viene **accorciata** in O2, non costruita.

---

## 2. Ambienti di esecuzione

| ID | Macchina | Ruolo nel piano | Limiti noti |
|---|---|---|---|
| **ENV-L** | Laptop 32 GB DDR5, RTX 5080 16 GB, Docker/WSL2 | Loop di sviluppo, profilo `core`, prove demo, T0/T-smoke quotidiani | Niente profilo full + soak insieme; WSL2 assorbe RAM (usare i `.wslconfig` di `examples/`) |
| **ENV-W** | HP Z8 G4, 2× Xeon 6244, 256 GB RAM + 256 GB PMEM/DAX, RTX 3090 24 GB, Ubuntu 24, Docker | Profilo **full**, nightly CI (runner self-hosted), soak test 24 h, matrice CPU, inferenza fino a `granite4:32b-a9b-h` (19 GB, entra nei 24 GB della 3090) | Un solo GPU slot: le sweep parallele multi-modello saturano; PMEM/DAX utilizzabile come backend volumi per i soak I/O-intensivi (opzionale, non richiesto dal piano) |
| **ENV-R** | RunPod (costi non vincolanti) | Tutto ciò che L e W non coprono: **matrici di eval parallele**, modelli oltre i 24 GB VRAM effettivi, run lunghi mentre L/W sono occupati | Le istanze sono **effimere**: nessun output sopravvive allo spegnimento se non recuperato (v. §3). I pod GPU standard sono container: **Docker-in-Docker non è garantito** → v. regola sotto |

**Criterio di scelta** (in ordine): ENV-L se basta il profilo `core` e < 2 h; ENV-W se serve profilo full, soak, o la 3090; ENV-R per tutto il resto o quando L/W sono occupati.

**Regola RunPod / packaging.** Lo stack compose completo gira solo dove c'è un demone Docker vero: ENV-L, ENV-W, o un host Docker privato remoto. Su RunPod si porta **il carico GPU impacchettato come immagine singola**, non lo stack:

- `deploy/runpod/Dockerfile.eval` — immagine autosufficiente: Ollama (o vLLM per i modelli grandi) + harness di eval (`bench/eval/`) + fixtures. Entrypoint: pull modelli → esegue la matrice → scrive tutto in `/workspace/results/<RUN_ID>/`.
- `deploy/private-docker/` — override compose per host Docker privato (5080 o 3090): stesso stack, `OLLAMA_BASE_URL` puntato eventualmente al pod RunPod via porta esposta/proxy, per il caso ibrido "stack su W, modello su R".
- **RP-0 (probe, 30 min, prima di contarci)**: verificare sul proprio account se un template con privileged/DinD è disponibile; se sì, anche lo stack compose diventa deployabile su RunPod e `deploy/runpod/` guadagna una variante compose. Fino a esito positivo di RP-0, il piano **non** dipende da DinD.

**Configurazione pod per classe di task** (i costi non sono un vincolo → si sceglie l'ideale, non l'economico):

| Classe | Pod consigliato | Volume | Note |
|---|---|---|---|
| Eval modelli ≤ 8 GB (350m/1b/3b/7b-a1b + embed) | RTX 4090 24 GB, 16 vCPU, 64 GB RAM | 100 GB | Una GPU per modello in parallelo: N pod piccoli battono 1 pod grande per la matrice |
| Eval `granite4:32b-a9b-h` e oltre | A100 80 GB (o H100 80 GB) | 200 GB | Headroom per KV cache e confronti side-by-side senza swap di modelli |
| Soak/CPU (se mai su R) | CPU pod 32 vCPU / 128 GB | 100 GB | Solo se RP-0 positivo |

---

## 3. Output: dove vivono e come si recuperano (obbligatorio prima di ogni spegnimento pod)

Convenzione unica per **tutti** gli ambienti:

- `RUN_ID = <YYYYMMDD-HHMM>-<env>-<git-sha-short>` (es. `20260901-1430-envr-3d147a1`)
- Ogni run scrive **solo** dentro `results/<RUN_ID>/` (su RunPod: `/workspace/results/<RUN_ID>/`) con dentro: `manifest.json` (run_id, ambiente, sha, comando, versioni immagini/modelli, esito), i log grezzi, gli output dei test (JSON), e `SHA256SUMS` generato a fine run.
- **Nel repository** vengono committati solo i riassunti: `docs/runs/<RUN_ID>.md` (esito, tabella PASS/FAIL/XFAIL, link ai numeri chiave) — piccoli, diffabili, permanenti.
- I grezzi vivono in una cartella **fuori repo** sul NAS/disco locale: `~/NORTHSTREAM-archive/<RUN_ID>/` (la "cartella specifica" di conservazione).

**Runbook di chiusura pod RunPod** (nessun pod si spegne senza aver completato tutti i passi):

1. A fine run l'entrypoint genera `SHA256SUMS` dentro `results/<RUN_ID>/`.
2. Dal client: `runpodctl receive` (o `rsync -avz` via SSH del pod) di `results/<RUN_ID>/` → `~/NORTHSTREAM-archive/<RUN_ID>/`.
3. Verifica integrità: `sha256sum -c SHA256SUMS` sulla copia locale. **Se fallisce, si ritrasferisce; il pod resta acceso.**
4. Redazione di `docs/runs/<RUN_ID>.md` dal `manifest.json` + commit.
5. Solo ora: terminate del pod. (I pod vivono il tempo necessario, non di più: il costo non è un problema, l'output perso sì.)

---

## 4. Metodologia di test

Tre semantiche, gestite dal harness (`bench/`):

- **PASS** — comportamento corretto oggi; **non deve mai regredire**.
- **XFAIL** — difetto noto della review, registrato come "expected fail" sulla baseline. Ogni release **dichiara in anticipo** quali XFAIL flippa a PASS: sono i suoi *progression test*. Un XFAIL che passa senza essere stato dichiarato è comunque notizia buona ma va capito; un PASS che diventa FAIL blocca la release, sempre.
- **EVAL** — misure di qualità AI (non binarie): producono numeri confrontati con la baseline; gate a soglia.

**Regola di rilascio (non negoziabile):** una minor esce solo se (a) tutti i PASS della release precedente restano PASS, (b) tutti gli XFAIL dichiarati flippano, (c) nessun nuovo XFAIL viene introdotto senza decisione scritta del supervisore nel CHANGELOG.

### 4.1 Suite T0 — baseline (gira sull'attuale develop, senza modificarla)

Il harness arriva con v0.0.1 ma è progettato per eseguire contro il tag `v0.0.0-baseline` (checkout separato): il **primo run in assoluto è contro la baseline** e il suo report (`docs/runs/<RUN_ID>-baseline.md`) è il metro di tutte le release successive. Ambiente: ENV-L o ENV-W.

| ID | Input | Procedura | Output atteso e verifica | Attesa su baseline |
|---|---|---|---|---|
| **T0.1** | I 3 file compose | `docker compose -f … config -q` su tutte le combinazioni (base; base+addon; base+addon+gpu) | Exit code 0 per tutte | **PASS** |
| **T0.2** | Stack base+addon avviato | Poll su health/porte: Kafka, Postgres, Connect, Qdrant, Ollama, agent, entro 420 s | Tutti healthy/rispondenti; tempo registrato nel manifest | **PASS** |
| **T0.3** | Riga sentinella `INSERT INTO sensor_readings (site,temperature_c,vibration_g,is_anomaly) VALUES ('Plant-A', 77.31, 0.411, false)` con marker unico 77.31 | Insert via `psql` nel container → consume di `northstream.public.sensor_readings` **dall'interno della rete** (`kafka-console-consumer` nel container) per 30 s | Un messaggio JSON con `"temperature_c":77.31` (double, non base64) | **PASS** |
| **T0.4** | La stessa riga sentinella | `GET :8500/events?limit=50` entro 60 s dall'insert | La stringa `77.31` presente in un evento del buffer | **PASS** |
| **T0.5** | Insert anomalia nota `('Plant-B', 91.73, 1.234, true)` → `POST /compare` con la domanda canonica | Parse JSON risposta | Campi `with/without_stream_context` presenti e non vuoti; `context_used` contiene `91.73`; la risposta grounded contiene `91.7` | **PASS** (grounded-contiene-valore marcato *flaky-tollerato* sulla baseline: 1 retry ammesso) |
| **T0.6** | Host esterno alla rete Docker | `kcat -b localhost:9092 -L` (o client Python) dall'host, timeout 15 s | Metadata completi del broker | **XFAIL** (P-1) → flip in **v0.0.2** |
| **T0.7** | Trino up | `docker exec trino trino --execute "SHOW CATALOGS"` e query su `postgresql.public.orders` | Catalogo `postgresql` presente e `SELECT count(*)` > 0 | **XFAIL** (P-2) → flip in **v0.0.3** |
| **T0.8** | Stack con ≥ 20 eventi indicizzati | Leggere `count` punti Qdrant → `docker restart northstream-stream-agent` → attendere 10 nuovi eventi → rileggere | Il count cresce di ~10; nessun punto sovrascritto (id nuovi ∉ id preesistenti) | **XFAIL** (A-3) → flip in **v0.0.4** |
| **T0.9** | Anomalia indicizzata, poi generatore fermo e attesa 15 min (accelerabile: soglia recency parametrica) | `POST /chat` "any anomalies in the last 2 minutes?" | Il contesto non contiene eventi più vecchi della soglia; la risposta non cita l'anomalia stantia | **XFAIL** (A-2) → flip in **v0.0.4** |
| **T0.10** | Domanda su sito **fuori** da `KNOWN_SITES` con anomalia reale iniettata (es. sito `Depot-9` aggiunto via insert manuale) | `POST /chat` "anomalies at Depot-9?" | `context_used` contiene l'evento Depot-9 | **XFAIL** (A-1: il boost keyword non copre siti nuovi e l'embedding 30m non li ranka) → flip in **v0.0.4** |
| **T0.11** | Agent up, Qdrant fermato (`docker stop`) | `GET /health` | Status ≠ ok / campo dependencies con qdrant=down | **XFAIL** (A-5) → flip in **v0.0.4** |
| **T0.12** | Repo pulito | Linter di verità documentale: script che verifica (a) ogni path citato nel "Repository Layout" del README esiste, (b) nessun endpoint in tabella servizi è morto rispetto al compose, (c) sezione License coerente col file LICENSE | Zero violazioni | **XFAIL** (D-1, D-2, P-1 doc) → flip in **v0.0.1** |

Tutti i test sono script in `bench/t0/` con exit code, output JSON per-test, e nessuna dipendenza dall'ordine (ogni test prepara e pulisce il suo dato sentinella; i valori sentinella sono costanti fisse nel repo → input e output **verificati e verificabili** da chiunque).

### 4.2 Suite EVAL — qualità del retrieval (da v0.0.4, matrice completa su ENV-R)

- **Fixture deterministica**: `bench/eval/fixtures/events_eval.sql` — 40 eventi noti con valori unici e riconoscibili (temperature tipo 91.73, 88.21…, ordini con totali unici), iniettati a generatore spento.
- **Question set fisso**: `bench/eval/questions.json`, 20 domande in 4 classi: (Q1) sito in `KNOWN_SITES`, (Q2) sito fuori lista, (Q3) aggregazioni ordini, (Q4) domande-trappola su dati assenti.
- **Verifica deterministica, non LLM-judge**: per Q1–Q3 la risposta grounded deve contenere il valore numerico iniettato (regex); per Q4 deve contenere un rifiuto esplicito ("does not show") e **nessun** numero inventato. Metriche: `grounding_accuracy` per classe, `hallucination_rate` su Q4, latenza p50/p95.
- **Baseline EVAL** (v0.0.4, pre-modifica retrieval) vs **post** (stessa release, dopo O5.3): gate = Q2 migliora senza che Q1 peggiori; `hallucination_rate` non cresce.
- **Matrice modelli (ENV-R, v0.1.0-beta1)**: {granite4:350m, 1b, 3b, 7b-a1b-h, 32b-a9b-h} × {granite-embedding:30m, 278m} — 10 combinazioni, pod paralleli (un 4090 ciascuno, A100 per il 32b). Output: tabella accuracy/latenza per combinazione → i default dei tier (`examples/*/.env`) vengono **derivati dai numeri**, non più dichiarati a sensazione. Chiude anche il criterio GO/NO-GO dell'issue #1 (il MoE 7b-a1b-h e il 32b sono nella matrice: se non battono i densi sul question set, Norimberga perde il suo caso d'uso qui).

### 4.3 Soak (ENV-W, nightly da v0.0.4)

**T-SOAK-24h**: stack full 24 h con generatore attivo. Verifiche a fine run: (a) crescita punti Qdrant coerente con la retention configurata (non illimitata), (b) dimensione replication slot Postgres sotto soglia (`pg_replication_slots`), (c) zero eventi persi durante 50 `/compare` sparsi (contatore eventi DB vs buffer), (d) RSS totale per profilo dentro il tier dichiarato. Prima esecuzione sulla baseline **a scopo di misura** (i fallimenti attesi diventano i numeri "prima").

---

## 5. CI / Workflow

Tre livelli, introdotti in v0.0.1 e arricchiti a ogni release:

| Workflow | Trigger | Dove gira | Contenuto |
|---|---|---|---|
| **ci-static** | ogni push su `develop` e sui branch di release | GitHub-hosted | `yamllint`, `ruff` (agent + generator), `hadolint` sui Dockerfile, `docker compose config -q` su tutte le combinazioni, linter di verità documentale (T0.12) |
| **ci-smoke** | ogni push su `develop` | GitHub-hosted (runner standard 4 vCPU/16 GB) | Profilo `core-ci`: stack CDC completo ma **Ollama sostituito da un mock HTTP** (container ~50 righe che risponde a `/api/embeddings` con vettori deterministici e a `/api/generate` con echo del contesto) → T0.1–T0.4, T0.8, T0.11 girano deterministici e senza GPU in ~10 min. Il mock testa la *pipeline*, non il modello: è dichiarato tale. |
| **ci-nightly** | schedule + `workflow_dispatch` | **Runner self-hosted su ENV-W** | Suite T0 completa con LLM veri + T-SOAK (schedulato) + pubblicazione `docs/runs/` |

Le run EVAL su ENV-R restano lanciate da script (`deploy/runpod/launch_eval.sh`) e rientrano in CI solo come `workflow_dispatch` che verifica la presenza e coerenza del report committato. Scheletro `ci-smoke`:

```yaml
name: ci-smoke
on: { push: { branches: [develop, "release/**"] } }
jobs:
  smoke:
    runs-on: ubuntu-latest
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@v4
      - run: docker compose -f docker-compose-northstream-ai.yml -f docker-compose.addon.yml -f bench/ci/mock-ollama.yml --profile core up -d --build
      - run: bench/t0/run.sh --suite ci --report results/${RUN_ID}
      - uses: actions/upload-artifact@v4
        with: { name: t0-report, path: results/ }
```

Coerentemente con §4.5 della review: **niente PR flow obbligatorio** fino al secondo contributor; la protezione è la CI su push. I branch `release/vX.Y.Z` esistono solo per preparare il tag e muoiono dopo il merge.

---

## 6. Release train

Ogni release: branch `release/vX.Y.Z` da `develop` → fix → CI verde → run T0 su ENV-L **e** nightly su ENV-W verdi → `docs/runs/` aggiornato → CHANGELOG → tag → merge. Scope chiuso: ciò che non è pronto slitta, la release non aspetta.

| Release | Nome | Contenuto | Progression test (XFAIL→PASS) | Gate aggiuntivo |
|---|---|---|---|---|
| **v0.0.0-baseline** | Baseline | Solo tag su `5eb456a` + primo run T0 completo | — | Report baseline committato: è il contratto di partenza |
| **v0.0.1** | Harness & verità | `bench/` + 3 workflow CI + mock-ollama + fix documentali O2 (README, demo-script, layout, License, rimozione endpoint 9092 dalla tabella) + `.env`→`.env.example` + merge di `docs/review_tecnica.md` e di questo piano in develop | **T0.12** | T0.1–T0.5 identici alla baseline (prova che il harness non altera il comportamento); ci-smoke verde al primo colpo |
| **v0.0.2** | Raggiungibilità & riproducibilità | Doppio listener Kafka (interno 9092 / esterno 29092), pin versione+digest di tutte le immagini, binding `127.0.0.1`, script preflight (`vm.max_map_count`, RAM disponibile, GPU) | **T0.6** | Nuovo T-REPRO: due `docker compose pull` a distanza di giorni risolvono gli stessi digest; preflight fallisce con messaggio chiaro su host non conforme |
| **v0.0.3** | Profili & tier onesti | Compose profiles `core`/`lakehouse`/`governance`, `mem_limit` per servizio, `trino/catalog/postgres.properties` + config memoria Trino, tabella tier del README riscritta sui numeri misurati | **T0.7** | Nuovo T-PROF: profilo `core` completo con RSS totale ≤ 14 GB su ENV-L (misurato via `docker stats`, registrato nel manifest) |
| **v0.0.4** | Agent robusto | Point-id da `(topic,partition,offset)`, timestamp nel payload + filtro recency in query, retrieval con `Filter` payload (site) al posto del boost keyword (che viene rimosso), `/health` con check dipendenze, `group_id` Kafka, logging strutturato, `query_points` al posto della API deprecata | **T0.8, T0.9, T0.10, T0.11** | EVAL pre/post su ENV-W: Q2 ↑ senza Q1 ↓, hallucination_rate ≤ baseline; primo T-SOAK-24h verde su (a),(b),(c) |
| **v0.0.5** | Governance minima | Ingestion OpenMetadata per Postgres e Trino (container ingestion o job one-shot), asset e lineage visibili | Nuovo **T-GOV**: API OpenMetadata restituisce > 0 tabelle per entrambi i servizi e almeno 1 edge di lineage | Profilo `governance` documentato con costo RAM misurato |
| **v0.1.0-beta1** | Beta | Consolidamento: matrice EVAL completa su ENV-R (10 combinazioni), default dei tier derivati dai numeri, chiusura formale issue #1 col criterio §4.2, CHANGELOG cumulativo, release notes, demo-script finale provato su ENV-L in condizioni demo reali | Tutti i T0 **PASS** (zero XFAIL residui) | T-SOAK-24h verde su tutti i punti incluso (d); il report della matrice EVAL è pubblicato in `docs/runs/`; una persona diversa dall'autore (o l'autore su macchina pulita) riesegue il Quick Start da zero seguendo solo il README |

**Definition of Done per v0.1.0-beta1**: zero XFAIL; zero claim documentali falsi (T0.12 verde per costruzione); riproducibile da README su macchina pulita; numeri di qualità pubblicati; tutti i run archiviati secondo §3.

---

## 7. Rischi del piano

| Rischio | Mitigazione |
|---|---|
| RP-0 negativo (niente DinD su RunPod) | Già assorbito: il piano non vi dipende; ENV-R usato solo per carichi GPU single-image |
| Runner GitHub 16 GB insufficiente anche per `core-ci` | Il mock-ollama toglie il carico maggiore; se non basta, ci-smoke migra su ENV-W e GitHub tiene solo ci-static |
| Flakiness LLM nei test (T0.5, EVAL) | Asserzioni sul *contesto* (deterministico) separate da quelle sulla *risposta* (1 retry, temperature bassa/seed dove supportato); i test EVAL riportano percentuali, non pass/fail secchi |
| ENV-W non sempre disponibile come runner nightly | La nightly è ri-lanciabile a mano (`workflow_dispatch`); il gate di release richiede il run, non la puntualità dello schedule |
| Scope creep verso i layer di scenografia | Congelato per iscritto in §1: Flink/Iceberg/metastore riaprono solo dopo beta1, ciascuno col proprio progression test |

---

## 8. Prossima azione immediata

1. Tag `v0.0.0-baseline` su `5eb456a` e push del tag.
2. Apertura branch `release/v0.0.1`: harness `bench/t0/` + mock-ollama + workflow CI + fix documentali O2.
3. **Primo run T0 contro la baseline** su ENV-L (o ENV-W), archiviazione secondo §3, commit di `docs/runs/<RUN_ID>-baseline.md`: da quel momento esiste il metro, e ogni commit successivo si misura contro di esso.
