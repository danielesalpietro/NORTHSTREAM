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
| **O8** | **Casi d'uso dimostrabili** | O8.1 generatore che produce **sequenze controllate** — baseline, sviluppo, impatto, periodo tranquillo — non solo eventi realistici (stabilimenti che producono linee, anomalie che si raggruppano, clienti con storico) · O8.2 question set EVAL riscritto come scenari di business, non sonde tecniche · O8.3 demo-script **derivato** dai test invece che scritto a parte | **G-3 (ripromosso)** |
| **O9** | **Explain Change** | O9.1 **beta1 — local change detection**: confronto deterministico fra finestra corrente e di riferimento, calcolato **fuori dal modello**, che emette `ChangeFact` strutturati sotto una policy di salienza esplicita · O9.2 **post-beta1 — streaming change detection**: gli stessi `ChangeFact` prodotti da Flink con stato per entità, sostituendo il produttore senza toccare agent, EVAL e demo-script | — (capacità nuova; è l'obiettivo che dà a Flink una responsabilità architetturale) |

Fuori scope fino a dopo la beta1 (decisione §4.4 della review): Flink job, Iceberg, metastore per MinIO, K8s. La storyline del README viene **accorciata** in O2, non costruita.

**Eccezione dichiarata su O9.** "Cos'è cambiato e perché dovrei preoccuparmene" non è una domanda di retrieval: il RAG restituisce i *k* eventi più simili, non può dire che il tasso di anomalie è triplicato in dieci minuti, perché quello è un aggregato sulla finestra. Il calcolo di aggregati su finestra è precisamente il mestiere di **Flink** — il layer oggi scenografico. O9 si spezza quindi in due, alle condizioni vincolanti della §1.1.

- **O9.1, in beta1**: il confronto fra finestre è calcolato in Python, **fuori dal modello e fuori dal prompt flow**, e ammesso solo come *reference implementation* dell'operatore Flink futuro. Nessun servizio nuovo: il congelamento della scenografia regge.
- **O9.2, primo obiettivo post-beta1**: lo stesso confronto diventa uno **stream derivato calcolato da Flink**, con stato per entità e finestre mantenute in continuo. È l'obiettivo che dà a Flink una responsabilità architetturale reale, invece di tenerlo perché sta nel diagramma.

### 1.1 O9 — specifica vincolante (contratto `ChangeFact`)

*Fissata dall'owner il 27/08/2026, dopo la prima stesura di O9. Vincola l'implementazione
minimale: senza queste condizioni la versione Python è una scorciatoia non trasferibile a
Flink, cioè una seconda architettura che andrà poi eliminata.*

**La pipeline concettuale.** Rilevare il cambiamento, valutarne la salienza e spiegarne la
rilevanza sono tre passaggi distinti, e il retrieval entra **dopo** i primi due:

```
Raw events → Window comparison → Change facts → Salience filtering
           → Context enrichment / retrieval → Explanation
```

Da cui il ruolo di ciascun componente: **Python (poi Flink) determina che cosa è cambiato**;
**il retrieval recupera che cosa quel cambiamento può influenzare**; **il modello formula una
spiegazione vincolata alle evidenze**. Il retrieval non deve mai essere incaricato di
*scoprire* il cambiamento.

**Il rischio da evitare.** Se la beta1 permettesse all'agent di (a) leggere direttamente tutti
gli eventi, (b) scegliere autonomamente che cosa confrontare, (c) calcolare numeri nel prompt,
(d) stabilire liberamente che cosa sia importante — allora non staremmo prototipando Flink:
staremmo costruendo un'architettura parallela da buttare. **Il modello deve ricevere i
risultati del confronto, non essere il motore del confronto.**

**Il contratto.** Le due responsabilità restano separate da una firma esplicita, la stessa che
Flink onorerà dopo:

```python
detect_changes(events, current_window, reference_window, policy) -> list[ChangeFact]
```

| | Topologia |
|---|---|
| **beta1** | `Event store → Python change detector → ChangeFact → Agent` |
| **post-beta1** | `Event stream → Flink → ChangeFact stream → Agent` |

**Il consumatore non cambia: cambia solo il produttore dei fatti derivati.** Il porting a Flink
è quindi la sostituzione di un produttore, non una riscrittura di agent, EVAL o demo-script —
ed è questo il criterio con cui si giudicherà se O9.1 è stato scritto bene.

**Lo schema `ChangeFact`** (forma canonica: l'output Python e l'output Flink devono essere
confrontabili campo per campo):

```json
{
  "entity": "Plant-B",
  "metric": "vibration_anomaly_rate",
  "current_window":   { "from": "…", "to": "…", "value": 0.18 },
  "reference_window": { "from": "…", "to": "…", "value": 0.06 },
  "change":   { "absolute": 0.12, "ratio": 3.0, "direction": "increase" },
  "salience": "high",
  "evidence": { "event_count": 9 }
}
```

L'agent **non ricalcola e non reinterpreta** questi numeri: li riceve come evidenze
strutturate, li combina col contesto governato e li spiega.

**La salienza è una policy governata, non un'impressione del modello.** "Triplicato" sembra
importante e può non esserlo: da 1 a 3 anomalie è +200% e può essere rumore; da 100 a 150 è
+50% e può essere grave. Per la beta1 **non** si costruisce un anomaly detector statistico
general-purpose: si dichiara una policy deterministica e ispezionabile, per metrica —

```yaml
metric: vibration_anomaly_rate
minimum_event_count: 5
minimum_absolute_delta: 0.05
minimum_ratio: 2.0
severity: high
```

— dove un cambiamento è saliente **solo se soddisfa tutti i criteri contemporaneamente**.
Quattro vantaggi, tutti verificabili: il test è deterministico; la demo è spiegabile; il
periodo tranquillo è controllabile; il comportamento Python è riproducibile in Flink.

**Tre livelli di spiegazione, visibili e non fusi.** "Perché dovrei preoccuparmene" contiene
tre cose di natura diversa, e la risposta deve tenerle separate:

| Livello | Natura | Esempio |
|---|---|---|
| **Explain Change** | fatto derivato dagli eventi | "il tasso di anomalie di vibrazione a Plant-B è passato dal 6% al 18% rispetto alla finestra precedente" |
| **Explain Relevance** | collegamento col contesto governato | "Plant-B è associato alla linea che produce l'ordine Acme" |
| **Explain Risk** | inferenza, dichiarata come tale | "il cambiamento può aumentare il rischio sulla consegna, ma i dati disponibili non consentono di prevedere un ritardo" |

Fondere i tre livelli in un'unica frase apparentemente fattuale è il modo in cui un sistema di
*situational explanation* finge di essere forecasting. La separazione è un requisito, non uno
stile di scrittura.

**Tre casi negativi distinti, che non devono collassare nello stesso "non lo so".** Sono tre
proprietà di fiducia diverse:

| Caso | Situazione | Risposta attesa | Proprietà |
|---|---|---|---|
| **Assenza di cambiamenti** | dati presenti e freschi, nessuna variazione oltre soglia | "non risultano cambiamenti rilevanti rispetto alla finestra precedente" — o, meglio, "il volume è aumentato leggermente, ma resta entro la variabilità prevista" | **quietness** |
| **Assenza di dati** | eventi insufficienti nella finestra corrente o in quella di riferimento | "confronto non effettuabile" | **observability** |
| **Cambiamento senza impatto noto** | cambiamento misurabile, nessun collegamento governato con un rischio o un processo | "cambiamento rilevato; impatto non determinabile con i dati disponibili" | **explainability** |

La seconda forma della prima riga è **preferibile** alla prima: dimostra che il sistema ha
osservato una differenza e non l'ha trasformata artificialmente in un allarme. L'asserzione del
periodo tranquillo non verifica quindi che compaia la frase "non è successo nulla", ma che
**l'intera catena non fabbrichi rilevanza**.

---

## 2. Ambienti di esecuzione

| ID | Macchina | Ruolo nel piano | Limiti noti |
|---|---|---|---|
| **ENV-L** | Laptop 32 GB DDR5, RTX 5080 16 GB, Docker/WSL2 | Loop di sviluppo, profilo `core`, prove demo, T0/T-smoke quotidiani | Niente profilo full + soak insieme; WSL2 assorbe RAM (usare i `.wslconfig` di `examples/`) |
| **ENV-W** | HP Z8 G4, 2× Xeon 6244, 256 GB RAM + 256 GB PMEM/DAX, RTX 3090 24 GB, Ubuntu 24, Docker | Profilo **full**, nightly CI (runner self-hosted), soak test 24 h, matrice CPU, inferenza fino a `granite4:32b-a9b-h` (19 GB, entra nei 24 GB della 3090) | Un solo GPU slot: le sweep parallele multi-modello saturano; PMEM/DAX utilizzabile come backend volumi per i soak I/O-intensivi (opzionale, non richiesto dal piano). **Le misure di RAM qui non sono trasferibili ai tier**: con 256 GB fisici le JVM dello stack (Kafka, Debezium Connect, Flink, Trino) auto-dimensionano l'heap a una frazione della RAM di sistema, quindi il footprint osservato è un limite superiore. P-5 e T-PROF si validano solo su ENV-L o con `mem_limit` espliciti (unica eccezione già vincolata: Elasticsearch, `-Xmx1g` fisso nel compose). **Aggiornamento del 27/08, dopo #21**: i `mem_limit` ora ci sono su 20 servizi su 21, quindi la premessa è caduta — un container con tetto cgroup dimensiona l'heap su quel tetto e non sui 256 GB dell'host, e **la misura di T-PROF diventa portabile e può essere presa su ENV-W**. Resta a ENV-L ciò che nessun tetto rende trasferibile: (a) che lo stack **funzioni** su un host stretto — pressione di memoria, swap, OOM killer, overhead della VM di WSL2, che su una macchina da 256 GB non si manifestano mai; (b) le righe **VRAM** della tabella tier, dove 16 GB (5080) è una domanda a cui una 3090 non può rispondere; (c) il collaudo di `preflight.ps1`, mai eseguito su Windows. **La 3090 non è dedicata al progetto** (chiarito dall'owner il 27/08): fuori dalle finestre di manutenzione la macchina è **noleggiata su vast.ai**, e un tenant può occupare da 11,6 a 22,3 GiB dei 24,5 — misurato durante la nightly di verifica di #42. Conseguenza operativa: ENV-W ha **due stati**, *manutenzione* (GPU nostra) e *noleggio* (GPU di terzi), e le misure GPU-dipendenti valgono solo nel primo. Il controllo automatico di [#44](https://github.com/danielesalpietro/NORTHSTREAM/issues/44) (pre-check, run-check, post-run) è in piedi da v0.0.3: `preflight.sh --gpu [--require-vram-mib N] [--allow-contention]` rifiuta un run GPU su macchina condivisa con la causa esplicita, `bench/t0/run.sh` campiona fra un test e l'altro e scrive `manifest.json.exclusivity.detected` accanto al valore dichiarato con `--exclusivity`. Chi pianifica un run GPU su ENV-W continua comunque a chiedere prima all'owner in quale stato sia: il controllo automatico misura, non prenota la finestra (§2.1) |
| **ENV-R** | RunPod (costi non vincolanti) | Tutto ciò che L e W non coprono: **matrici di eval parallele**, modelli oltre i 24 GB VRAM effettivi, run lunghi mentre L/W sono occupati | Le istanze sono **effimere**: nessun output sopravvive allo spegnimento se non recuperato (v. §3). I pod GPU standard sono container: **Docker-in-Docker non è garantito** → v. regola sotto |

**Criterio di scelta** (in ordine): ENV-L se basta il profilo `core` e < 2 h; ENV-W se serve profilo full, soak, o la 3090; ENV-R per tutto il resto o quando L/W sono occupati.

### 2.1 Finestre GPU su ENV-W — si prenotano, non si occupano

Vincolo dell'owner (27/08/2026): **la Z8 è disponibile per tutto il tempo necessario, ma la
finestra di manutenzione va dichiarata con anticipo.** Chiudere la GPU in faccia a un
noleggio in corso viola la policy di vast.ai, quindi non è una possibilità: si aspetta la
fine del noleggio corrente e si blocca la successiva disponibilità.

Ne discendono tre regole di pianificazione, che valgono più della disponibilità in sé.

**1. Chi pianifica un run GPU dichiara durata *prima*, non dopo.** Una finestra si prenota
in ore, e una stima sbagliata per difetto costa un secondo giro di prenotazione. Le durate
note e stimate:

| Run | Release | Esclusività | Durata | Anticipo |
|---|---|---|---|---|
| Suite `full` con modelli veri | ogni release | **Preferibile**: i modelli piccoli (1b+30m, 6,5 GiB) entrano anche in contesa, ma T0.5 e T0.9 sono sensibili ai tempi e in contesa mentono | **~15 min** (misurato: la nightly del 27/08 ha girato in 11 min) | poche ore |
| **T-PROF** (profilo `core`, RSS ≤ 14 GB) | v0.0.3 | **Necessaria** su CPU e RAM, non sulla GPU — ma ENV-W resta un limite superiore per la RAM (v. riga ENV-W): il test vive su ENV-L | ~1 h | poche ore |
| **T-SOAK-24h** | v0.0.4 | **Necessaria e continuativa** | **> 24 h** | **il più lungo del piano**: è l'unico run che non entra in una finestra breve |
| **Matrice EVAL** (10 combinazioni) | v0.1.0-beta1 | **Necessaria e vincolante**: `granite4:32b-a9b-h` pesa 19 GB e con un tenant sui 22 GiB **non parte** | da stimare sulla prima combinazione misurata, poi moltiplicare | mezza giornata |

**2. Una finestra prenotata si spende misurando, non debuggando.** È il rischio vero di
questo modello: prenotare 24 ore per il soak e scoprire al quinto minuto che l'harness ha
un difetto. Prima di ogni finestra prenotata si esegue quindi una **prova a secco** dello
stesso comando — durata ridotta, stato condiviso accettato — con l'unico scopo di validare
la catena (avvio, connettore, harness, archiviazione). La finestra vera parte solo se la
prova a secco è verde.

**3. La prenotazione entra nella pianificazione della release, non nella conversazione.**
Quando una release dichiara un run GPU, la richiesta di finestra all'owner è parte della
sua definition of done: va chiesta all'apertura della fase, non quando il codice è pronto.
Altrimenti il codice aspetta la macchina, che è esattamente il tempo morto che il §6-bis
cerca di eliminare.

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
- Ogni run scrive **solo** dentro `results/<RUN_ID>/` (su RunPod: `/workspace/results/<RUN_ID>/`) con dentro: `manifest.json` (run_id, ambiente, sha, comando, versioni immagini/modelli, esito — e da v0.0.3 l'**esclusività dell'host**, `exclusive`/`shared`/`unknown`, [#44](https://github.com/danielesalpietro/NORTHSTREAM/issues/44)), i log grezzi, gli output dei test (JSON), e `SHA256SUMS` generato a fine run.
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
- **Question set fisso**: `bench/eval/questions.json` — **scenari di business, non sonde tecniche** (O8.2). Il criterio di ammissione di una domanda è: *una dashboard non saprebbe rispondere*, e la risposta porta a una decisione con un costo attaccato. Sei classi:

  | Classe | Domanda tipo | Cosa dimostra |
  |---|---|---|
  | **U1 — decisione cross-dominio** | *"Acme ha ordinato 12 pompe industriali. Possiamo impegnarci sulla data di consegna?"* | Unire vendite e operations in tempo reale: nessuna dashboard ha questa risposta perché sta a cavallo di due domini |
  | **U2 — freschezza** | *"Qualcosa non torna nei numeri EMEA — cos'è cambiato di recente?"* | Dati in movimento contro dati fermi: un assistente su warehouse risponde con i dati di stanotte ed è confidentemente sbagliato |
  | **U3 — explain change** (O9) | *"Cos'è cambiato nell'ultima mezz'ora e perché dovrei preoccuparmene?"* | La domanda che né dashboard, né warehouse, né LLM generico risolvono bene insieme |
  | **U4 — controllo negativo su dato assente** | domanda su un'entità che non esiste nello stream | L'assistente **dice di non sapere** invece di inventare: è una dimostrazione di fiducia, spesso più persuasiva di una risposta giusta |
  | **U5 — controllo negativo su periodo tranquillo** (O9.1) | *"Cos'è cambiato?"* durante una finestra in cui non è successo nulla di rilevante | **Il modo in cui un assistente "explain change" fallisce non è tacendo, è inventando significato.** Questa classe è il negativo che rende credibile il positivo |
  | **U6 — aggregazione verificabile** | *"Qual è il valore totale degli ordini Acme di oggi?"* | Ancoraggio numerico: la risposta è confrontabile con una `SELECT`, quindi l'errore è misurabile |

  Le classi U4 e U5 sono le più importanti per un pubblico aziendale, dove la paura numero uno degli LLM è l'invenzione sicura di sé.
- **Criteri EVAL minimi di O9** (specifica §1.1 — sono il gate della v0.0.6, non una lista di desideri):

  | # | Criterio | Che cosa asserisce | Classe |
  |---|---|---|---|
  | 1 | **Positive change** | rileva e **quantifica** un cambiamento saliente (i numeri della risposta coincidono con quelli del `ChangeFact`) | U3 |
  | 2 | **Quiet period** | non inventa significato in assenza di cambiamenti rilevanti | U5 |
  | 3 | **Insufficient baseline** | dichiara che il confronto **non è possibile** — distinto dal caso 2 | U5, variante *baseline insufficiente* (fixture separata) |
  | 4 | **Change without known impact** | riporta il cambiamento **senza inventarne le conseguenze** | U3 |
  | 5 | **Relevant change** | collega il cambiamento a un'entità di business **solo** quando il collegamento esiste nei dati governati | U1 + U3 |
  | 6 | **Competing changes** | con più cambiamenti simultanei, li ordina secondo la **policy di salienza**, non secondo la scelta libera del modello | U3 |

  I criteri 2, 3 e 4 sono i tre negativi della §1.1 (quietness, observability, explainability) e vanno asseriti **separatamente**: un'unica asserzione "risponde di non sapere" li farebbe collassare e perderebbe esattamente ciò che dimostrano. Il criterio 6 è quello che smaschera un'implementazione in cui la salienza è tornata a essere un'impressione del modello: con due `ChangeFact` costruiti perché la policy li ordini in un modo preciso, l'ordine della risposta è verificabile meccanicamente.
- **Verifica deterministica, non LLM-judge**: per Q1–Q3 la risposta grounded deve contenere il valore numerico iniettato (regex); per Q4 deve contenere un rifiuto esplicito ("does not show") e **nessun** numero inventato. Metriche: `grounding_accuracy` per classe, `hallucination_rate` su Q4, latenza p50/p95.
- **Baseline EVAL** (v0.0.4, pre-modifica retrieval) vs **post** (stessa release, dopo O5.3): gate = Q2 migliora senza che Q1 peggiori; `hallucination_rate` non cresce.
- **Matrice modelli (v0.1.0-beta1) — ENV-W per default, ENV-R solo se serve**: {granite4:350m, 1b, 3b, 7b-a1b-h, 32b-a9b-h} × {granite-embedding:30m, 278m} — 10 combinazioni. **Tutte entrano nei 24 GB della 3090**: il più grande, `granite4:32b-a9b-h`, pesa 19 GB, e il run di riferimento ha misurato 6,5 GB di VRAM per la coppia 1b+30m. **Ma "entrano" vale solo a GPU libera**: con un tenant vast.ai sui 22 GiB (v. §2, riga ENV-W) il 32b non entra affatto, e i modelli medi misurerebbero latenze inquinate dalla contesa. La matrice va quindi **schedulata dentro una finestra di manutenzione concordata con l'owner**, non lanciata al primo momento libero della notte — ed è la ragione per cui **RP-0 e il packaging RunPod restano nel piano come capacità viva** anziché essere archiviati: sono l'alternativa quando la finestra non c'è. La matrice va quindi eseguita **sulla Z8 via `ci-nightly`**, in serie e di notte: costo zero, nessun pod da gestire, nessun output da recuperare prima di uno spegnimento. Stima: ~10 combinazioni in poche ore di wall-clock, irrilevante se gira mentre nessuno guarda. **ENV-R (RunPod) resta la via solo per due casi**: un modello che ecceda i 24 GB di VRAM (oggi nessuno in matrice), o la necessità di comprimere il wall-clock eseguendo le combinazioni in parallelo — un pod per modello (4090 ciascuno, A100 per il 32b). Di conseguenza **RP-0 e il packaging RunPod diventano opzionali ma non archiviabili** per la beta1: sono la via di riserva quando ENV-W è in noleggio. Output: tabella accuracy/latenza per combinazione → i default dei tier (`examples/*/.env`) vengono **derivati dai numeri**, non più dichiarati a sensazione. Chiude anche il criterio GO/NO-GO dell'issue #1 (il MoE 7b-a1b-h e il 32b sono nella matrice: se non battono i densi sul question set, Norimberga perde il suo caso d'uso qui).

### 4.3 Soak (ENV-W, nightly da v0.0.4)

**T-SOAK-24h**: stack full 24 h con generatore attivo. Verifiche a fine run: (a) crescita punti Qdrant coerente con la retention configurata (non illimitata), (b) dimensione replication slot Postgres sotto soglia (`pg_replication_slots`), (c) zero eventi persi durante 50 `/compare` sparsi (contatore eventi DB vs buffer), (d) RSS totale per profilo dentro il tier dichiarato. Prima esecuzione sulla baseline **a scopo di misura** (i fallimenti attesi diventano i numeri "prima").

#### 4.3.1 Le soglie di (b) e (d) — scritte dopo il primo soak, non prima

Il soak parziale `20260827-1406-envw-c6b56d3` (427 campioni, 7,39 h) ha concluso
**UNKNOWN** su (b) e (d), e la sessione che l'ha eseguito ha fatto la cosa giusta a
non inventarsi una soglia da riga di comando: il piano ne dichiarava una solo per
(a) e (c). Un verde senza referente sarebbe stato peggio di un UNKNOWN — vale la
regola di CLAUDE.md §5 sul campo derivato che deve saper distinguere "falso" da
"non l'ho potuto sapere". Le soglie si scrivono qui, **una volta sole**, e sono
ancorate ai numeri già misurati.

**(b) Replication slot.** Il modo di guasto vero non è una dimensione, è uno slot
che smette di avanzare: il WAL si accumula finché il disco finisce. Serve quindi
un criterio di *tendenza* più un tetto di sicurezza, non un tetto da solo.

| Condizione | Verdetto |
|---|---|
| `active` vero in ≥ 99% dei campioni, **e** nessuna sequenza di ≥ 3 campioni consecutivi non-attivi, **e** WAL trattenuto max ≤ 256 MiB, **e** pendenza sulla seconda metà del run ≤ 1 MiB/h | OK |
| Tetto o pendenza superati, o sequenza non-attiva ≥ 3 campioni | FAIL |
| Anche un solo campione con `active` **null** (non misurabile) | UNKNOWN — e il run non può concludere OK su (b) |

I 256 MiB non sono un numero di comodo: il run di riferimento ha misurato **0,060
MiB di massimo** su 7,4 ore, quindi la soglia sta più di tre ordini di grandezza
sopra il comportamento sano e intercetta uno slot bloccato molto prima che il disco
ne risenta. Il primo soak, riletto con questo criterio, sarebbe **OK**: 427 campioni
su 427 con `active` vero, tendenza piatta.

**(d) RSS totale.** Il tetto non è una costante: è **la somma dei `mem_limit`
dichiarati nel compose** per i servizi del profilo in esame. Scritto così si
aggiorna da solo quando il compose cambia, non richiede di ricordarsi di
riallineare un numero in un documento, e misura la cosa che davvero interessa —
se lo stack sta dentro ciò che dichiara di volere.

| Condizione | Verdetto |
|---|---|
| RSS totale ≤ somma dei `mem_limit` del profilo, **e** nessun servizio oltre il 90% del proprio `mem_limit` per ≥ 10 campioni consecutivi | OK |
| Tetto complessivo superato, o un servizio incollato al proprio tetto | FAIL |
| Uno o più servizi del profilo **senza** `mem_limit` | UNKNOWN — il tetto del profilo non è definito |

La seconda condizione conta quanto la prima: un servizio che vive al 95% del proprio
tetto non ha ancora fallito, ma è a un picco di distanza dall'OOM killer, e un soak
che riporta solo il totale non lo vedrebbe mai.

Conseguenza sul run già archiviato: il primo soak resta **UNKNOWN su (d) per
costruzione**, perché è stato eseguito su uno stack **precedente** ai `mem_limit` di
[#21](https://github.com/danielesalpietro/NORTHSTREAM/issues/21) — non esisteva un
tetto contro cui misurarlo. Non è un difetto del run: è ciò che lo rende il "prima"
di P-5. I suoi numeri — mediana 14 174 MiB, picco 15 985 MiB, di cui Trino da 4 109
a 7 119 MiB (+73%) — sono il termine di paragone, non un fallimento.

#### 4.3.2 Regola metodologica: un confronto prima/dopo varia una cosa sola

Il soak "dopo" va eseguito con **la stessa composizione di stack** del "prima" — 19
container, cioè `core` + `lakehouse` + `governance` — e stessa cadenza di
campionamento. Dall'introduzione dei profili (O4.1) un `docker compose up` nudo
avvia il solo `core`: un "dopo" lanciato così misurerebbe un sistema diverso, e la
differenza osservata sarebbe dominata dai sette container che mancano invece che dai
tetti che sono stati aggiunti. L'unica variabile che deve cambiare fra i due run è
la configurazione sotto esame (`jvm.config` e `mem_limit`).

Vale anche al contrario: la misura di T-PROF sul profilo `core` **non** è il "dopo"
di questo soak, è un'altra misura con un altro scopo (la riga della tabella tier).
Le due non si confrontano fra loro.

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
| **v0.0.3** | Profili & tier onesti | Compose profiles `core`/`lakehouse`/`governance`, `mem_limit` per servizio, `trino/catalog/postgres.properties` + config memoria Trino, tabella tier del README riscritta sui numeri misurati, **esclusività dell'host** ([#44](https://github.com/danielesalpietro/NORTHSTREAM/issues/44)): pre-check che rifiuta un run GPU su macchina condivisa, campionamento durante il run, campo `exclusive`/`shared`/`unknown` nel `manifest.json` | **T0.7** | **T-PROF in due parti** (v. riga ENV-W): **(1) misura dei tetti su ENV-W** — profilo `core` completo, somma degli RSS ≤ 14 GB con i `mem_limit` dichiarati, via `docker stats --no-stream`, registrata nel manifest; **(2) conferma comportamentale su ENV-L** — che lo stesso profilo *giri* davvero su 32 GB con WSL2, più le righe VRAM del tier 16 GB e il collaudo di `preflight.ps1`. La (1) chiude l'aritmetica, la (2) chiude il claim rivolto a chi ha una macchina come quella |
| **v0.0.4** | Agent robusto | Point-id da `(topic,partition,offset)`, timestamp nel payload + filtro recency in query, retrieval con `Filter` payload (site) al posto del boost keyword (che viene rimosso), `/health` con check dipendenze, `group_id` Kafka, logging strutturato, `query_points` al posto della API deprecata | **T0.8, T0.9, T0.10, T0.11** | EVAL pre/post su ENV-W: Q2 ↑ senza Q1 ↓, hallucination_rate ≤ baseline; primo T-SOAK-24h verde su (a),(b),(c) |
| **v0.0.5** | Governance minima | Ingestion OpenMetadata per Postgres e Trino (container ingestion o job one-shot), asset e lineage visibili | Nuovo **T-GOV**: API OpenMetadata restituisce > 0 tabelle per entrambi i servizi e almeno 1 edge di lineage | Profilo `governance` documentato con costo RAM misurato |
| **v0.0.6** | **Casi d'uso e Explain Change** | Generatore che produce **sequenze controllate** — baseline, sviluppo, impatto, periodo tranquillo (**G-3**: stabilimenti che producono linee, anomalie che si raggruppano, clienti con storico); question set EVAL riscritto sulle sei classi U1–U6; **O9.1** — `detect_changes(...)` fuori dall'agent, `ChangeFact` strutturati, policy di salienza dichiarata in file, tre livelli di spiegazione separati (§1.1); demo-script **generato** dai casi d'uso | Nuovi **U-test**: U1–U3 rispondono con i fatti attesi; **U4 e U5 sono i gate veri** — nessuna invenzione su dato assente, nessun allarme inventato nel periodo tranquillo; i **sei criteri EVAL di O9** (§4.2) tutti verdi, con i tre negativi asseriti separatamente | Il demo-script non è più scritto a mano: se un caso d'uso non passa, la demo non si fa. Criterio di accettazione di O9.1: **sostituire il produttore di `ChangeFact` non deve toccare agent, EVAL e demo-script** — se li tocca, la Python non è una reference implementation ma un'architettura parallela. **Debito documentale del README** (Roadmap, riga Flink della Layer status, contratto `ChangeFact`, demo-script generato) elencato in [#43](https://github.com/danielesalpietro/NORTHSTREAM/issues/43) e nel logbook di fase: si paga nel release branch, con T0.12 verde dopo la modifica |
| **v0.1.0-beta1** | Beta | Consolidamento: matrice EVAL completa su ENV-R (10 combinazioni), default dei tier derivati dai numeri, chiusura formale issue #1 col criterio §4.2, CHANGELOG cumulativo, release notes, demo-script finale provato su ENV-L in condizioni demo reali | Tutti i T0 **PASS** (zero XFAIL residui) | T-SOAK-24h verde su tutti i punti incluso (d); il report della matrice EVAL è pubblicato in `docs/runs/`; una persona diversa dall'autore (o l'autore su macchina pulita) riesegue il Quick Start da zero seguendo solo il README |

**Definition of Done per v0.1.0-beta1**: zero XFAIL; zero claim documentali falsi (T0.12 verde per costruzione); riproducibile da README su macchina pulita; numeri di qualità pubblicati; tutti i run archiviati secondo §3.

---

## 6-bis. Anticipazione e parallelismo (aggiunto 27/08/2026)

Il treno resta sequenziale per le **modifiche di comportamento**, ma tre classi di
lavoro possono uscire dalla loro fase e comprimere l'elapsed time. La regola che le
autorizza è in `CLAUDE.md` §3.2.

**A. Strumenti di misura, in anticipo sul codice che misureranno.** Sono codice di
test: non possono regredire il sistema, e devono comunque esistere prima della fase
che li usa come gate.

| Lavoro | Fase di origine | Anticipabile a | Perché conviene |
|---|---|---|---|
| Suite EVAL: `bench/eval/`, fixture `events_eval.sql`, le 20 domande, asserzioni deterministiche | Fase 3 (#29) | **Fase 1** | È il gate della Fase 3: costruirlo prima significa entrare in Fase 3 con lo strumento pronto invece di fabbricarlo mentre lo si usa |
| Robustezza di T0.10 (precondizione sulla dimensione della collection o distrattori) | Fase 3 (#40) | **Fase 1** | Finché non è sistemato, T0.10 dà un esito privo di significato **a ogni release**, non solo in Fase 3 |
| Package RunPod / RP-0 | Fase 5 (#34) | qualunque | Ormai opzionale (la matrice entra nella 3090): si fa se avanza tempo, non blocca |

**B. Ore macchina nelle fasi morte.** Soak e matrici sono tempo di calendario, non
di sforzo: con il runner `env-w` registrato, `ci-nightly` li porta senza che nessuna
sessione sia viva, a costo cloud **zero**.

- **Soak "prima" su baseline o v0.0.2** — non previsto originariamente: dà la curva
  di crescita di Qdrant e del replication slot *prima* dei fix della Fase 3, e rende
  il confronto post-fix molto più forte di un solo run "dopo".
- **Matrice EVAL baseline** — stessa logica: i numeri del "prima" si possono
  raccogliere di notte molto prima della Fase 5.
- Prerequisito per entrambi: **#42** chiuso (il `down -v` della nightly cancella
  `ollama_data`), poi `RUN_NIGHTLY` accesa deliberatamente.

**C. Biforcazione del treno dopo la Fase 2 — possibile, non raccomandata oggi.**
La Fase 4 (ingestion OpenMetadata) non condivide codice con la Fase 3 (agent) e
dipende solo dai profili compose della Fase 2: in linea di principio i due rami
possono correre in parallelo e riunirsi prima della Fase 5. **Costo**: due release
branch in volo significano due set di gate, due logbook, e il rischio di attribuire
al ramo sbagliato una regressione. Con bus factor 1 e i limiti settimanali attuali
eccede la capacità: resta un'opzione dichiarata, da riconsiderare solo se compare un
secondo contributor o se la Fase 3 si allunga oltre le previsioni.

**Sequenza rivista consigliata**: Fase 1 (meccanica) + suite EVAL + #40 in anticipo
→ Fase 2 → soak e matrice "prima" di notte → Fase 3 con gli strumenti già pronti →
Fase 4 → Fase 5. L'anticipo di A e B toglie dalla Fase 3 — la più cara — tutto ciò
che non è il ridisegno vero e proprio.

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
