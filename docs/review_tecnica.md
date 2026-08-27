# Review tecnica critica — NORTHSTREAM

- **Data**: 26 agosto 2026
- **Baseline**: branch `develop`, commit `5eb456a` ("update index")
- **Tipo**: review di sola lettura (analisi statica; lo stack non è stato eseguito durante questa review — le affermazioni comportamentali sono deduzioni dal codice/config, segnalate come tali dove rilevante)
- **Vincolo rispettato**: nessuna modifica a codice o configurazione; unico file prodotto: questo documento
- **Mandato**: onestà, non conferma. Le decisioni prese — incluse quelle del documento di piano precedente ("handoff") — sono messe in discussione con argomenti tecnici; dove ha senso vengono proposte alternative con pro/contro espliciti.

---

## 1. Ordine di lettura consigliato

Per chi affronta il repository per la prima volta, quest'ordine minimizza i falsi presupposti:

1. **`README.md`** — la narrativa. Da leggere per primo, ma con sospetto: è il documento più curato del repository e più avanti si mostra che in almeno quattro punti descrive un sistema che non esiste.
2. **`docker-compose-northstream-ai.yml`** — il sistema reale. Il confronto con la "Data Flow Storyline" del README è l'esercizio più istruttivo dell'intero progetto.
3. **`init/postgres/001-init-sales-db.sql`** + **`connectors/postgres-source-connector.json`** — la parte CDC, che è la spina dorsale funzionante.
4. **`data-generator/generate_events.py`** — sorgente dei dati sintetici; notare la distribuzione delle anomalie tra i siti.
5. **`stream-agent/app.py`** — il cuore del progetto (300 righe). Leggere in quest'ordine interno: `consume_loop` → `search_context` → `keyword_matches` → `/compare`. La funzione `keyword_matches` è il punto singolo più importante da capire di tutto il repository.
6. **`docker-compose.addon.yml`**, **`docker-compose.gpu.yml`**, script `start-addon.*` / `register-connector.*` / `demo-compare.*` — orchestrazione, lineare.
7. **`docs/demo-script.md`** — solo alla fine: descrive la demo come esperienza, e a quel punto si è in grado di valutare quanto dell'esperienza sia meccanismo e quanto sia messa in scena.

---

## 2. Che cosa è davvero questo progetto

Spogliato della narrativa, NORTHSTREAM oggi è:

> **Una pipeline CDC funzionante (Postgres → Debezium → Kafka) con un consumer Python che indicizza gli eventi in Qdrant e li usa come contesto per un piccolo LLM locale — circondata da cinque servizi di scenografia (Flink, Apicurio, MinIO, Trino, OpenMetadata) che partecipano al diagramma ma non al flusso dati.**

Questo non è un giudizio sprezzante: la parte funzionante è ben fatta per lo scopo (demo presales), il codice è leggibile, gli script cross-platform sono una cortesia rara, e il messaggio di fondo ("un modello piccolo ben alimentato batte un modello grande a secco") è tecnicamente sano e dimostrato dal meccanismo. Ma la distanza tra i sette layer dichiarati e i due layer funzionanti è il problema strutturale numero uno del progetto, e nessun documento nel repository la dichiara con questa franchezza. La sezione "What NORTHSTREAM Does Not Yet Provide" del README ammette l'assenza di *applicazioni* (SQL Assistant, Governance Agent), ma non ammette che *l'infrastruttura stessa* sotto quei layer è oggi non collegata.

Bilancio layer per layer:

| Layer dichiarato | Stato reale |
|---|---|
| CDC (Postgres + Debezium) | **Funzionante.** Config corretta: `wal_level=logical`, `REPLICA IDENTITY FULL`, `pgoutput`, publication filtrata, `decimal.handling.mode=double` per evitare i NUMERIC in base64. |
| Streaming (Kafka + Kafka UI) | **Funzionante dai container; rotto dall'host** (v. finding P-1). |
| Schema governance (Apicurio) | **Scenografia.** Debezium usa `JsonConverter` con `schemas.enable=false`: nessuno schema viene mai registrato, letto o validato. Apicurio gira, consuma risorse, e non partecipa al flusso. |
| Stream processing (Flink) | **Scenografia.** Due container JVM, zero job, zero jar di connettori, zero esempi. Nessun percorso nel repository crea mai un job Flink. |
| Lakehouse (MinIO + Trino) | **Scenografia.** I tre bucket vengono creati e restano vuoti per sempre: nessun servizio scrive in MinIO. Trino monta una directory di cataloghi che non esiste nel repository (v. finding P-2). |
| Governance (OpenMetadata) | **Gira, vuoto.** Nessuna ingestion configurata; manca il container di ingestion che il compose ufficiale OpenMetadata include. Catalogo popolabile solo a mano. |
| AI / chat (Ollama + Open WebUI + addon) | **Funzionante.** Con le riserve importanti sul meccanismo di retrieval (v. finding A-1). |

Dei 10 passi della "Data Flow Storyline" del README, i passi 5–8 (Flink, MinIO, Trino, OpenMetadata) non hanno alcuna implementazione dietro. Il diagramma descrive un'aspirazione presentata come descrizione.

---

## 3. Findings

Severità: **[BLOCKER]** rompe la demo o rende falso un claim pubblico · **[MAJOR]** difetto sostanziale di progetto o affidabilità · **[MINOR]** attrito, debito, incoerenza documentale.

### 3.1 Piattaforma / compose

**P-1 [BLOCKER] — Kafka è irraggiungibile dall'host, ma il README lo pubblicizza come `localhost:9092`.**
`KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092`: un client sull'host si connette al bootstrap su `localhost:9092` (porta pubblicata), riceve metadata che puntano a `kafka:9092` — hostname non risolvibile fuori dalla rete Docker — e fallisce. La tabella servizi del README elenca `localhost:9092` come endpoint utilizzabile. Chiunque provi `kcat`/`kafka-console-consumer` dall'host, come il README invita implicitamente a fare, si blocca al primo passo. Serve il classico doppio listener (`INTERNAL://kafka:9092` + `EXTERNAL://localhost:29092` advertised di conseguenza) oppure la rimozione dell'endpoint dalla tabella. Nota: la porta 9092 è anche pubblicata su `0.0.0.0`, quindi il broker in plaintext è esposto alla LAN pur essendo inutilizzabile dall'host — il peggio di entrambi i mondi.

**P-2 [BLOCKER] — `./trino/catalog` non esiste nel repository.**
Il servizio Trino monta `./trino/catalog:/etc/trino/catalog:ro`. Docker crea una directory vuota sull'host al primo `up`; Trino parte con i soli cataloghi di sistema e non ha nulla da interrogare. Lo step 7 della storyline ("Query data with Trino") è oggi un vicolo cieco. Nota che il layout "suggerito" nel README elenca esplicitamente `trino/catalog/minio.properties` e `postgres.properties` come esistenti. Vedi §4.2 per la correzione alla stima di sforzo fatta nell'handoff su questo punto.

**P-3 [MAJOR] — `bitnamilegacy/kafka:3.7.1` è un'immagine da archivio congelato.**
Dopo la ristrutturazione del catalogo Bitnami (Broadcom, agosto 2025), il namespace `bitnamilegacy` è un archivio esplicitamente non mantenuto: niente rebuild, niente patch CVE. Per un progetto *nato* a luglio 2026 è una scelta già legacy alla nascita, non un residuo storico. Alternativa naturale: `apache/kafka` ufficiale (KRaft nativo, mantenuta) — richiede la traduzione delle env `KAFKA_CFG_*` nel formato dell'immagine Apache, mezz'ora di lavoro. Alternativa coerente con la narrativa "Confluent-like": `confluentinc/cp-kafka` (attenzione alla licenza Confluent Community per i componenti non-broker). Restare su `bitnamilegacy` ha come unico pro lo sforzo zero, e come contro un'immagine che accumulerà CVE per sempre in un progetto che si presenta come materiale di enablement.

**P-4 [MAJOR] — Sette immagini su `:latest` o tag mobili in un lab che vende riproducibilità.**
`kafka-ui:latest`, `adminer:latest`, `minio:latest`, `mc:latest`, `qdrant:latest`, `ollama:latest`, `open-webui:main`. Per un laboratorio demo la riproducibilità *è* il prodotto: la stessa demo deve funzionare identica sul laptop del collega tra sei mesi. MinIO è il caso più concreto: le release 2025 hanno progressivamente svuotato la console web community delle funzioni di gestione — un `docker compose pull` fatto oggi può produrre una console diversa da quella che la demo si aspetta. Pinnare tutto a digest o almeno a versione è un intervento da 20 minuti che elimina un'intera classe di "funzionava ieri".

**P-5 [MAJOR] — Il tier "Minimal 16 GB" è con ogni probabilità sotto-dimensionato, e nulla nel compose lo fa rispettare.**
Lo stack completo con addon è ~18 container di cui almeno 6 JVM (Kafka, Debezium Connect, Flink ×2, Trino, OpenMetadata) più Elasticsearch (`-Xmx1g`, RSS reale ~2 GB) più Ollama con un modello caricato. Trino da solo, senza configurazione di memoria (assente, visto che `trino/` non esiste), ha default JVM pensati per macchine ben più grandi. La stima onesta per lo stack completo è 20–24 GB — coerente, ironicamente, con il `.wslconfig` del tier *Recommended* che assegna 20 GB. Inoltre nessun servizio ha `mem_limit`/`deploy.resources.limits` (unica eccezione: heap ES), quindi su Linux nativo i "tier" non esistono a runtime: sono documentazione. O si abbassa il claim del tier Minimal, o si crea un profilo ridotto che lo renda vero (v. §4.3, che è la strada migliore).

**P-5, misurato — la crescita che la baseline non poteva vedere. [Aggiunto il 27/08/2026 dai campioni del soak parziale su ENV-W.]**
Sei ore di campionamento a intervallo di 60 s trasformano la stima in una curva, e il risultato è più netto della stima. Stack pieno **senza** `mem_limit`: **14,26 GiB di mediana**, con **Trino a 5,97 GiB, il 41% del totale**. Ma il numero che conta non è il livello, è **la derivata**: Trino è cresciuto da **4,1 a 6,8 GiB in cinque ore, senza fermarsi**, mentre Elasticsearch e Kafka — che hanno l'heap fissato — restano piatti per tutta la serie. È la dimostrazione diretta del meccanismo che P-5 ipotizzava: **una JVM senza tetto si dimensiona sulla RAM dell'host** (235 GiB su ENV-W), e non converge.

**Conseguenza retroattiva, che vale più della misura stessa**: il run di riferimento del 26/08 misurava **9,52 GiB per 19 container**, ed è il numero che abbiamo usato per due giorni come footprint dello stack. Quella lettura è stata presa **poco dopo l'avvio**, non a regime: non è sbagliata, è **una misura a freddo di una grandezza che cresce**. Chi la citasse come "quanto pesa NORTHSTREAM" sbaglierebbe del 50%. Il report resta valido per ciò che misurava — gli esiti dei test — e va **annotato**, non riscritto.

È anche il caso da manuale per cui il piano §4.3 prescrive un soak: nessuna suite di test che parte, misura e chiude in quindici minuti può vedere una grandezza che impiega ore a manifestarsi.

**P-6 [MAJOR] — Elasticsearch su Linux nativo: manca il prerequisito `vm.max_map_count`.**
ES 8.x in container richiede `vm.max_map_count ≥ 262144`; Docker Desktop/WSL2 lo preimposta, Linux nativo tipicamente no → il container muore in bootstrap loop e con lui OpenMetadata (che dipende da ES healthy). Il README ha una sezione prerequisiti dettagliata sui tier hardware e non menziona questo, che è la prima causa concreta di "non parte" per l'utente Linux.

**P-7 [MINOR] — Espansione superficie di rete**: tutte le porte sono pubblicate su `0.0.0.0` (Postgres con demo/demo, MinIO con password nota, ES senza security, Kafka plaintext). Per un lab "local only" dichiarato, il binding `127.0.0.1:porta:porta` è una riga per servizio e rende vero il claim. Le Security Notes del README elencano le aree di rischio ma non collegano nessuna a un'azione tracciata.

**P-8 [MINOR] — Varie compose**: `create-minio-bucket` usa `sleep 5` invece di un retry/healthcheck (race benigna ma inelegante); `trino` dichiara `depends_on: minio` che è oggi ironico (nessun catalogo lo collega a MinIO); il progetto si chiama `name: wap-northstream-lab` — il prefisso `wap-` non è spiegato da nessuna parte ed entra nei nomi di rete/volumi; Flink, Trino, Ollama, MinIO non hanno healthcheck; il file `.env` (copia del tier Recommended) è tracciato in git, quindi cambiare modello localmente sporca il working tree — meglio `.env.example` + `.env` in `.gitignore`.

**P-9 [MAJOR] — I tre script del Quick Start non sono eseguibili su un clone pulito. [Aggiunto il 26/08/2026, confermato per prova su ENV-W.]**
`start-addon.sh`, `register-connector.sh` e `demo-compare.sh` sono committati con modo `100644` invece di `100755` (`bench/t0/run.sh`, aggiunto dopo, è correttamente `100755`). Su un clone pulito il bit di esecuzione manca e il Quick Start si ferma **al primo comando**:

```
$ ls -l start-addon.sh
-rw-rw-r-- 1 admin admin 437 Aug 26 21:52 start-addon.sh
$ ./start-addon.sh --help
/bin/bash: line 1: ./start-addon.sh: Permission denied
exit=126
```

L'exit code 126 anziché 127 è la firma esatta della diagnosi: il file esiste, manca il permesso. Il difetto non si vede mai sulla macchina dell'autore, dove i file sono stati creati con il bit già impostato — è visibile solo a chi clona, cioè a *chiunque altro*. Per un progetto che si presenta come materiale di enablement, il primo comando del README che fallisce è il peggior biglietto da visita possibile. Fix: `git update-index --chmod=+x` sui tre file. Assegnato a v0.0.2 insieme agli altri interventi di riproducibilità.

**P-10 [MAJOR] — Il teardown di `ci-nightly` cancella i modelli a ogni esecuzione. [Aggiunto il 26/08/2026 su segnalazione della sessione ENV-W.]**
L'ultimo step del workflow `ci-nightly` esegue `docker compose ... down -v`. Il flag `-v` rimuove i volumi del progetto, `ollama_data` compreso: ogni nightly cancellerebbe i modelli Granite e il run successivo li riscaricherebbe da capo — diversi GB e diversi minuti a ogni notte, su un runner self-hosted dove lo spazio non è il vincolo. Il difetto è oggi **latente**, perché `ci-nightly` è dormiente dietro il gate `if: vars.RUN_NIGHTLY == 'true'`, ma si manifesterebbe alla prima notte utile dopo l'accensione della variabile. **Va corretto prima che `RUN_NIGHTLY` venga impostata**: `down` senza `-v`, con eventuale pulizia selettiva dei soli volumi di stato (Qdrant, Postgres) se si vuole un ambiente pulito a ogni run.

**P-11 [MAJOR] — v0.0.2 rompe i lab già esistenti: il cambio d'immagine Kafka non è compatibile col volume vecchio. [Aggiunto il 27/08/2026, verificato per misura su ENV-W.]**
`bitnamilegacy/kafka:3.7.1` gira come `uid=1001 gid=0(root)`; `apache/kafka:4.3.1`, introdotta da #17, gira come `uid=1000(appuser) gid=1000`. Le directory dentro `kafka_data` restano `0:0` modo `775`, cioè scrivibili dal **gruppo root** — di cui il vecchio broker faceva parte e il nuovo no. Chi aggiorna un lab esistente trova quindi il broker in crash-loop (`java.nio.file.AccessDeniedException: /var/lib/kafka/data/bootstrap.checkpoint.tmp`, 46 restart osservati) con un errore che **non nomina né i permessi né il cambio d'immagine**; con volume fresco lo stesso commit è healthy in 23 s.

Il difetto è particolarmente insidioso perché **la CI non può rilevarlo per costruzione**: ogni run parte da un volume inesistente, cioè dal solo caso che funziona. È l'esatto opposto di ciò che v0.0.2 dichiara di essere — la release della riproducibilità — e va chiuso *dentro* questa release, non rimandato. Due vie: una nota di migrazione in CHANGELOG/README, oppure un controllo esplicito all'avvio. **La seconda è preferibile**, e l'argomento è dell'esecutore della misura: la nota la legge chi sospetta già un problema di aggiornamento, mentre chi non lo sospetta vede solo un broker che non parte.

**P-12 [MAJOR] — `ci-nightly` non è ripetibile sul runner self-hosted: la prima notte funziona, tutte le successive falliscono. [Aggiunto il 27/08/2026, verificato per misura su ENV-W.]**
Il compose fa bind-mount di `./trino/catalog`, directory che **non esiste nel repository** (finding P-2): Docker la crea al primo avvio come `root:root` dentro il workspace del runner. Alla nightly successiva `actions/checkout` prova a ripulire il workspace e muore in 10 secondi con `EACCES: permission denied, rmdir '.../trino/catalog'`, prima ancora di eseguire un solo step utile.

Il difetto era invisibile finché la nightly girava una volta sola, ed è emerso al secondo tentativo. Va notato che **la sessione che lo subisce non può ripararlo**: rimuovere una directory `root:root` richiede `sudo`, che sul runner non è disponibile all'agente. La correzione strutturale è banale — committare `trino/catalog/.gitkeep`, così la directory esiste in git e Docker non la crea come root — ma lo sblocco della macchina resta un'azione dell'owner.

**P-13 [MAJOR] — `.gitkeep` salva il checkout pulito, non il clone esistente. [Aggiunto il 27/08/2026, verificato per misura su ENV-W mentre si verificava il fix di P-12.]**
Su un clone dove Docker ha già creato `trino/catalog` come `root:root`, `git pull` fallisce con `Permission denied` e **lascia l'albero a metà**: né alla versione vecchia né alla nuova. Il fix di P-12 copre il caso del workspace ripulito a ogni run, non quello di chi aggiorna un checkout che ha già fatto girare lo stack.

**Vale però la pena leggere P-11, P-12 e P-13 insieme, perché sono un difetto solo visto da tre lati.** Il meccanismo è sempre lo stesso: *Docker gira come root e lascia in giro stato che l'utente non può toccare* — un volume nel primo caso, una directory nel secondo e nel terzo. E la ragione per cui nessuno dei tre è stato intercettato dalla CI è anch'essa una sola: **ogni run parte da zero**, quindi la nostra catena di verifica esercita sistematicamente l'unico caso che funziona. Non è una lacuna di copertura risolvibile aggiungendo test alla suite attuale: è una **classe di stato che la CI non visita mai**, e che solo una macchina con una storia — ENV-W, o il portatile di chi usa il lab da settimane — può esercitare. È l'argomento più forte emerso finora a favore delle finestre di verifica su hardware reale, e va tenuto presente quando si valuterà se la CI da sola basti come gate di release.

### 3.2 stream-agent (`app.py`)

**A-1 [MAJOR] — Il retrieval della demo di punta non è semantico: è keyword matching con contorno RAG.**
`keyword_matches()` intercetta i nomi di sito hardcoded (`KNOWN_SITES`) nella domanda e antepone al contesto i match letterali presi dal buffer in RAM; i risultati Qdrant riempiono solo i posti rimanenti. Per la domanda canonica della demo ("anomalie a Plant-B?") il percorso semantico è di fatto bypassato. La cronologia git lo dichiara senza imbarazzo: commit `11615f9` *"context include sempre un evento di Plant-B in prima posizione"*. In più, il seed SQL inserisce staticamente una riga `('Plant-B', 88.9, 0.95, true)` — esattamente l'anomalia che la domanda canonica cerca.

Il commento nel codice è onesto sul perché (l'embedding da 30M parametri non ranka in modo affidabile un evento site-specific sopra eventi "orders" non correlati) e il fallback è una scelta ingegneristica legittima per una demo dal vivo. Il problema è il **claim**: README e demo-script presentano il flusso come "retrieval semantico da Qdrant". Un prospect tecnico che chieda di un sito *non* in lista (o formuli la domanda senza nominare un sito) esercita il percorso semantico vero, con qualità visibilmente diversa — il momento peggiore possibile per scoprirlo è durante la demo. La causa a monte, peraltro, è nel generatore: le anomalie sono uniformi sui 5 siti (~8% × ⅕ ≈ un'anomalia Plant-B ogni ~3 minuti), quindi la domanda site-specific è strutturalmente sfavorita. Alternative in §4.1.

**A-2 [MAJOR] — Il contesto "fresco" può essere arbitrariamente stantio.**
Il payload dei punti Qdrant è `{"text", "topic"}`: nessun timestamp filtrabile. Con volume persistente e crescita illimitata (v. A-3), `qdrant.search` può restituire un'anomalia di una settimana fa per la domanda "ci sono anomalie *recenti*?", e il prompt la etichetta comunque come "recent live stream events". In una demo il cui *intero messaggio* è la freschezza del dato, è il difetto concettualmente più grave del servizio: il sistema può mentire esattamente sull'asse su cui si vende. Fix naturale: timestamp nel payload + `Filter` su range temporale in query (Qdrant lo supporta nativamente), o in alternativa ricreare la collection all'avvio, coerentemente con `auto_offset_reset="latest"`.

**A-3 [MAJOR] — ID dei punti: contatore in RAM contro storage persistente = collisioni garantite.**
`_point_id` riparte da 0 a ogni riavvio del container, mentre `qdrant_data` è un volume persistente: al secondo avvio l'upsert **sovrascrive** i punti 1..N della sessione precedente mescolando vecchio e nuovo. Insieme ad A-2 produce uno stato del vector store non ricostruibile. Fix elegante e idempotente: id deterministico da `(topic, partition, offset)` — replay sicuri gratis; alternativa banale: `uuid4` (ma perde l'idempotenza). Contestualmente: crescita senza TTL né cleanup (~29k punti/giorno a un evento/3s), e `qdrant.search()` è deprecato in qdrant-client 1.11 a favore di `query_points`.

**A-4 [MAJOR] — Embedding sincrono nel hot path del consumer, in contesa con la generazione.**
Ogni evento = una chiamata HTTP bloccante a Ollama (timeout 30 s) dentro il loop del consumer. Ollama serve *anche* le generazioni di `/compare` (fino a 120 s) sulla stessa istanza: durante una risposta il thread consumer si accoda o va in timeout, e l'evento viene **perso per sempre** con un `print` ("embedding/upsert failed") — niente retry, niente coda, e con `auto_offset_reset="latest"` senza `group_id` niente possibilità di recupero. Al ritmo attuale (un evento ogni ~3 s) il difetto è latente; alzare `INTERVAL_SECONDS` o fare più domande in parallelo durante un workshop lo rende visibile. Un buffer interno con embedding batch fuori dal loop di consumo sarebbe coerente con la taglia del progetto.

**A-5 [MINOR] — `/health` non può fallire.** Risponde `"ok"` incondizionatamente: non verifica Kafka, né Qdrant, né Ollama, nemmeno che il thread consumer sia vivo. Un healthcheck che non può fallire è UI, non observability. `buffered_events: 0` dopo minuti è l'unico segnale indiretto, e va saputo interpretare.

**A-6 [MINOR] — Superficie OpenAI-compatible fragile.** `stream: true` viene accettato e silenziosamente ignorato (Open WebUI di default chiede streaming; oggi funziona per tolleranza del client, non per correttezza del server); si legge solo `messages[-1]` scartando storia e system prompt; `usage` è fissa a zero. Per lo scopo (far comparire il modello nel picker) va bene, ma è il tipo di endpoint che si rompe a ogni upgrade di Open WebUI.

**A-7 [MINOR] — Igiene**: logging via `print` (niente livelli, niente timestamp — su uvicorn si perdono pure i flush a volte); zero test (nemmeno su `event_to_text`/`keyword_matches`, pure functions banali da testare); il contenuto degli eventi (es. `customer_name`) entra nel prompt senza sanitizzazione — per un lab è teorico, ma in un progetto che parla di governance una riga di consapevolezza nel README non guasterebbe.

**A-8 [MAJOR] — L'agent non vede i topic CDC per i primi ~5 minuti, seguendo l'ordine documentato. [Aggiunto il 26/08/2026 su misura, non presente nella review originale.]**
`stream-agent` si iscrive ai topic **per pattern** (`^northstream\..*`) all'avvio, e `kafka-python` rinfresca i metadata del cluster ogni 5 minuti (`metadata_max_age_ms` di default). I topic creati *dopo* l'iscrizione non gli sono visibili fino allo scadere di quella finestra — e sono creati sempre dopo, perché README e `docs/demo-script.md` prescrivono di registrare il connettore Debezium a stack già avviato. **Il ritardo non è costante: è una variabile uniforme in [0, 5 minuti]**, perché dipende da dove cade la registrazione del connettore nel ciclo di refresh. Misurato a **4 min 46 s** in CI (run `ci-smoke-33008193653`, caso quasi-peggiore) e a **8 secondi** su ENV-W (run `20260826-2053-envw-5eb456a`). La non determinatezza peggiora il problema invece di attenuarlo: chi prova la demo due volte ottiene due esperienze diverse e non sa quale sia quella vera.

Gravità pratica alta, benché il difetto sia banale: chi segue le istruzioni alla lettera apre `/events`, lo trova vuoto per minuti e conclude che la pipeline è rotta — nel momento peggiore, cioè al primo contatto col progetto o davanti a un cliente. Il difetto era invisibile alla lettura statica del codice (l'ho mancato in questa review) e invisibile anche al primo run CI, dove un test lento mascherava l'attesa: è emerso solo quando la suite è diventata veloce. Rimedio immediato a costo zero, documentale: riavviare `stream-agent` dopo `register-connector.sh`, oppure registrare il connettore prima di avviare l'addon. Rimedio strutturale in v0.0.4: `metadata_max_age_ms` basso nel `KafkaConsumer`, o iscrizione esplicita ai topic attesi con retry.

> **Stato di verifica dei finding — aggiornato al 26/08/2026 dopo il run di riferimento** [`20260826-2053-envw-5eb456a`](runs/20260826-2053-envw-5eb456a-baseline.md) (ENV-W, modelli reali, suite `full` contro il tag `v0.0.0-baseline`).
>
> **Confermati per misura**, non più dedotti: **P-1** (il bootstrap `localhost:9092` risponde, ma annuncia `broker 1 at kafka:9092` e il consumo reale muore su `Failed to resolve` — la formulazione originale «il client non ottiene i metadata» era imprecisa nel meccanismo, non nell'esito), **P-2**, **A-2**, **A-3** (crescita punti pari a 0 dopo il restart), **A-5**.
>
> **P-6 non riproducibile su ENV-W**, e questo non lo smentisce: quell'host ha già `vm.max_map_count=1048576` impostato via `/etc/sysctl.d/`. Il finding resta valido per un host Linux generico non preconfigurato; serve una macchina pulita per chiuderlo.
>
> **A-1 ridimensionato dai fatti.** Il test T0.10 (sito `Depot-9`, fuori da `KNOWN_SITES`) ha dato **XPASS stabile** (3/3). Il meccanismo denunciato resta vero — il boost keyword è hardcoded e non copre i siti nuovi — ma l'affermazione «l'embedding 30m non ranka un sito fuori lista» **non è confermata**: su una collection di 61 punti con `top_k=5`, un match letterale entra nei primi cinque senza bisogno di un embedding forte. Ironia utile: la collection era così piccola *a causa di A-3*, cioè un difetto ne mascherava un altro. Il test come scritto misura una proprietà della dimensione del corpus, non del retrieval — issue [#40](https://github.com/danielesalpietro/NORTHSTREAM/issues/40).
>
> **P-5 (tier RAM) resta aperto e la mia stima appare troppo pessimista.** Misurato su ENV-W: 9,52 GiB di RSS per 19 container, contro i 20-24 GB che questa review stimava. Il numero non verifica il finding (le JVM non sono compresse su 235 GiB, e i pesi dei modelli stanno in VRAM anziché in RAM), ma il divario è ampio: la verifica su ENV-L potrebbe ridimensionare il finding o ritirarlo.

### 3.3 data-generator, schema, connettore

**G-1 [MINOR] — Semantica dei timestamp incoerente.** Le colonne sono `TIMESTAMP` (senza timezone); il seed usa `now()` del server DB, il generatore `datetime.utcnow()` naive di Python. Due sorgenti, due semantiche, nessuna marcatura di zona: chi confronta `created_at` in Adminer con i `ts_ms` epoch di Debezium ottiene scarti da fuso orario non spiegabili. `TIMESTAMPTZ` + tempi aware ovunque è la correzione da manuale (`datetime.utcnow()` è peraltro deprecato da Python 3.12; il pin a 3.11 lo silenzia, non lo risolve).

**G-2 [MINOR] — `decimal.handling.mode: double` trasforma denaro in float.** Scelta giusta per la leggibilità della demo (il default produce base64), ma `NUMERIC(12,2)` → double IEEE è precisamente l'errore che un data platform "governed" dovrebbe insegnare a non fare. L'alternativa `string` preserva l'esattezza restando leggibile. Almeno, andrebbe nominata come trade-off consapevole nel demo-script.

**G-3 [MAJOR — ripromosso il 27/08/2026 da MINOR] — I dati sintetici non raccontano nulla, e questo blocca la dimostrazione di valore.** Ritmo costante (un evento ogni 3 s esatti), distribuzioni uniformi, nessun burst, nessuna stagionalità, 50/50 fisso orders/sensors. Per la demo attuale è sufficiente; per il claim "realistic orders and sensor events" del README, no.

**Perché la classificazione originale era sbagliata.** L'avevo dato per un dettaglio di realismo, rimandabile. Ma con l'introduzione di **O8** (casi d'uso dimostrabili) diventa un **prerequisito della dimostrazione di valore**, non un abbellimento. Il caso d'uso *"Acme ha ordinato 12 pompe, possiamo impegnarci sulla consegna?"* richiede che i dati abbiano una struttura narrativa: che Plant-B **produca davvero** quella linea di prodotto, che le anomalie **si raggruppino** invece di essere rumore uniforme, che Acme abbia **uno storico** con cui confrontare l'ordine di oggi. Con distribuzioni uniformi e nessuna correlazione, quella domanda non ha una risposta interessante — e la demo non racconta niente.

Lo stesso vale per **O9**: "cos'è cambiato" presuppone che qualcosa possa cambiare in modo riconoscibile. Un flusso a ritmo costante con anomalie casuali all'8% non ha un "prima" e un "dopo" distinguibili; l'assistente non può che inventare significato, che è esattamente il modo in cui un assistente explain-change fallisce.

**Assegnato a v0.0.6** insieme a O8/O9. Il generatore va riscritto con: stabilimenti associati a linee di prodotto, anomalie che si presentano in cluster temporali con una causa implicita, ritmo variabile, e clienti con profili d'ordine distinguibili.

**Precisazione dell'owner (27/08/2026), che alza ancora l'asticella**: non basta produrre eventi *realistici*. Il generatore deve produrre **sequenze controllate** con quattro fasi riconoscibili — **baseline, sviluppo, impatto, periodo tranquillo** — perché sono esattamente ciò che i sei criteri EVAL di O9 asseriscono (`docs/piano_ricovero.md` §4.2): senza una baseline dichiarata non esiste finestra di riferimento, senza un periodo tranquillo non esiste il controllo negativo di *quietness*, e senza una fase di sviluppo distinta dall'impatto non c'è modo di verificare che la policy di salienza scatti quando deve e non prima. **O8 dimostra il valore, O9 costruisce il meccanismo che rende quel valore credibile: G-3 li alimenta entrambi**, ed è per questo che è un prerequisito di fase, non un abbellimento.

**G-4 [MINOR] — kafka-python 2.0.2** è del 2020 e il progetto originale è rimasto dormiente per anni (il pin a Python 3.11 evita l'incompatibilità nota con 3.12). Funziona, ma `confluent-kafka` (librdkafka) sarebbe più solido e coerente con la narrativa; da valutare solo insieme ad A-4.

### 3.4 Documentazione vs realtà

**D-1 [MAJOR] — Il README promette artefatti inesistenti**: `docs/architecture.md`, `docs/roadmap.md`, `examples/sample-events.json`, `examples/sample-queries.sql`, `trino/catalog/*.properties` — tutti elencati nel "Suggested Repository Layout", nessuno esiste. Contemporaneamente il layout *omette* file che esistono (`dashboard.html`, `docker-compose.gpu.yml`, le cartelle tier di `examples/`, gli script `.ps1`/`.sh`). Un layout "suggerito" che non corrisponde né al presente né a un piano dichiarato è solo rumore: va allineato al reale o eliminato.

**D-2 [MINOR] — Difetti puntuali del README**: la tabella Granite ha una doppia riga di header (righe 391–394, refuso visibile nel rendering); la sezione License dice ancora "choose the license" mentre nel repository c'è un `LICENSE` MIT concreto; il Quick Start conserva il placeholder `git clone <your-repository-url>`; `dashboard.html` è servito dalla landing ma mai menzionato.

**D-3 [MINOR] — `docs/demo-script.md` è il documento migliore del progetto** — passo-passo onesto, con perle di esperienza reale (disattivare i Builtin Tools di Open WebUI, chat fresca per lato del confronto). Gli manca una sola cosa, la più importante: un riquadro "come funziona *davvero* il retrieval" che dichiari il boost keyword e i suoi limiti (A-1), così che il presentatore non venga colto in fallo dalla domanda sbagliata.

---

## 4. Decisioni messe in discussione (handoff incluso)

### 4.1 Il retrieval "aiutato" — tenerlo, ma smettere di chiamarlo semantico

La decisione (commit `11615f9` + `keyword_matches`) ha una logica difendibile: demo deterministica > demo onesta ma aleatoria, davanti a un cliente. La contestazione non è sulla scelta, è sul **silenzio documentale** e sull'aver curato il sintomo invece della causa (distribuzione uniforme delle anomalie nel generatore). Alternative:

| Opzione | Pro | Contro |
|---|---|---|
| **(a) Status quo dichiarato**: si tiene il boost, si documenta nel demo-script | Zero codice; elimina il rischio "domanda sbagliata in demo"; onesto | Il claim "semantic RAG" va ridimensionato pubblicamente |
| **(b) Filtro payload Qdrant**: `site` come campo payload + `Filter` in query (con timestamp, risolve anche A-2) | Usa il vector store per ciò che sa fare; deterministico *e* architetturalmente onesto; ~30 righe | Serve re-indicizzare; parser minimo dei nomi sito nella domanda (resta un'estrazione keyword, ma a monte del retrieval, dov'è legittima) |
| **(c) Hybrid search** (sparse BM25 + dense, nativo in Qdrant) | La risposta "da manuale"; robusta anche su entità mai viste | La più costosa; per 500 eventi da un generatore è overengineering |
| **(d) Embedding più grande** (`granite-embedding:278m`) come default | Attacca la causa dichiarata nel commento del codice | Non garantisce il ranking site-specific; alza i requisiti del tier Minimal |

**Raccomandazione: (b), con (a) come minimo sindacale immediato.** La (b) è l'unica che rende la demo *sia* affidabile *sia* raccontabile senza asterischi.

### 4.2 L'handoff ha sottostimato il fix Trino — "due file .properties" è vero a metà

Il piano precedente classificava P0 i cataloghi Trino come "basso sforzo (due file `.properties`)". Correzione tecnica: vale per **`postgres.properties`** (connettore JDBC, cinque righe, e Trino interroga subito `orders`/`sensor_readings` — questo sì è il quick win). **Non** vale per MinIO: Trino non interroga object storage grezzo — il connettore Hive/Iceberg richiede un *metastore* (Hive Metastore standalone o un Iceberg REST catalog), cioè un **servizio in più nel compose**, con la sua configurazione e la sua RAM. E anche col metastore, i bucket restano vuoti finché qualcosa non ci scrive (v. 4.4). Riformulazione onesta del P0: *"aggiungere `postgres.properties` (banale) e decidere consapevolmente se il lakehouse merita un metastore o se va tolto dalla storyline"* — che è una decisione di scope, non un task da mezz'ora.

### 4.3 Lo stack monolitico da 18 container — la decisione che nessuno ha ancora messo in discussione

Né il README né l'handoff si chiedono se i cinque servizi di scenografia (§2) debbano stare nel percorso di default. Costano metà del budget RAM, sono la causa prima del sotto-dimensionamento del tier Minimal (P-5), e allungano lo startup — per zero contributo alla demo che funziona. Alternative:

| Opzione | Pro | Contro |
|---|---|---|
| **(a) Status quo**: tutto sempre acceso | Il diagramma "si vede" tutto in Kafka UI/landing | 16 GB non bastano davvero; la scenografia consuma più della sostanza |
| **(b) Compose profiles**: `core` (Postgres, Debezium, Kafka, Kafka UI, Ollama, Open WebUI + addon) sempre; `lakehouse` e `governance` opt-in | La demo AI gira *davvero* in 16 GB; startup rapido; il compose smette di mentire sui tier; zero file nuovi (solo attributi `profiles:`) | Chi vuole "tutto acceso" deve passare `--profile`; README da aggiornare |
| **(c) Tagliare i servizi non collegati** finché non hanno una pipeline | Onestà massima, footprint minimo | Perde il valore "discussione architetturale a vista", che per il presales conta |

**Raccomandazione: (b).** È l'intervento con il miglior rapporto valore/sforzo dell'intero backlog: rende veri in un colpo solo il tier Minimal, il claim di riproducibilità e la separazione sostanza/scenografia — senza rinunciare alla scenografia per chi la vuole.

### 4.4 Storyline: costruire i passi mancanti o accorciare la storia?

I passi 5–8 non implementati lasciano due strade. **Costruire** (job Flink → Iceberg su MinIO → catalogo Trino → ingestion OpenMetadata): settimane di lavoro, nuovo servizio metastore, manutenzione permanente — per una pipeline che il pubblico della demo vede tre minuti. **Accorciare** (README e storyline riscritti attorno a CDC→Kafka→RAG, con i layer restanti presentati come "estensioni disponibili, non collegate"): un pomeriggio, e ogni claim diventa vero. La roadmap può poi ricostruire i passi *uno alla volta, con demo funzionante come definition of done* (l'ordine sensato: catalogo Postgres in Trino → ingestion OpenMetadata di Postgres+Trino, che dà lineage visibile senza Flink → solo alla fine Flink+Iceberg, che è il pezzo più costoso e meno raccontabile). **Raccomandazione: accorciare subito, ricostruire con calma.** Un simulatore presales il cui diagramma contiene frecce inventate è un rischio reputazionale, non un asset.

### 4.5 Processo: il PR flow proposto dall'handoff è la medicina giusta alla dose sbagliata

L'handoff propone branch `main` protetto + PR flow anche in modalità singolo maintainer. Contestazione: per un progetto a bus factor 1 e cadenza sporadica, il PR flow verso sé stessi è cerimonia che attrita esattamente la persona che deve restare motivata — e non è ciò che avrebbe evitato i difetti reali trovati qui (P-1 e P-2 non si vedono in un diff auto-approvato; si vedono *eseguendo*). La rete di sicurezza proporzionata è: **CI su ogni push a `develop`** con `docker compose config` su tutte le combinazioni di file, lint YAML/Python, build delle due immagini, e — il vero guadagno — uno **smoke test end-to-end** (up del profilo core, attesa health, register connector, insert riga, assert che `/events` la veda: ~15 min di runner, e avrebbe intercettato *da sola* metà dei finding di questa review a ogni commit). Il PR flow ha senso ripristinarlo alla comparsa del secondo contributor. Sul triage dell'issue #1 e sulla trasformazione delle Security Notes in issue tracciate, l'handoff resta condivisibile.

### 4.6 Issue #1 (Norimberga/MoE): la premessa è contraddetta dal README stesso

L'issue afferma "Oggi però [NORTHSTREAM] non usa modelli MoE". Ma il tier Optimal del README raccomanda `granite4:7b-a1b-h`, che il README stesso etichetta **MoE** (7B totali / ~1B attivi). La premessa andrebbe corretta in: *"i default (350m/1b, densi) non sono MoE; il tier Optimal già lo è"* — il che indebolisce il caso d'uso: se un MoE gira già oggi via Ollama senza alcun supporto speciale, il valore aggiunto di Norimberga per *questo* progetto si riduce al memory tiering per modelli oltre-VRAM (`granite4:32b-a9b-h`), scenario fuori scala per un lab demo su laptop. La valutazione resta legittima, ma il criterio GO/NO-GO va scritto su quel confine preciso, non sul generico "MoE sì/no".

---

## 5. Azioni prioritarie (ricalibrate rispetto all'handoff)

1. **Verità immediata, zero codice** — README: rimuovere/correggere `localhost:9092` (P-1), dichiarare lo stato reale dei layer (§2), allineare layout e License (D-1, D-2); demo-script: riquadro sul retrieval reale (D-3, opzione 4.1a). *Un pomeriggio, elimina ogni claim falso.*
2. **`trino/postgres.properties`** — il vero quick win dell'handoff, depurato dalla metà sbagliata (4.2).
3. **Compose profiles core/full** (4.3b) + doppio listener Kafka (P-1) + pin delle immagini (P-3, P-4) + nota `vm.max_map_count` (P-6).
4. **Robustezza agent** — id deterministici (A-3), timestamp nel payload + filtro recency (A-2), retrieval con filtro payload (4.1b), `/health` reale (A-5).
5. **CI con smoke test** al posto del PR flow (4.5).
6. **Poi, e solo poi**, la ricostruzione incrementale dei layer di scenografia nell'ordine di 4.4 — ciascuno con una demo funzionante come criterio di completamento.

## 6. Limiti di questa review

Analisi esclusivamente statica: lo stack non è stato avviato, quindi i comportamenti descritti (P-1, P-5, P-6, A-2/3/4) sono deduzioni da codice e configurazione, non osservazioni a runtime — solide, ma da confermare con lo smoke test del punto 5.5. Non sono stati auditati i contenuti di `index.html`/`dashboard.html` (485+289 righe di HTML statico, fuori dal percorso critico) né le versioni pin-nate delle dipendenze Python contro i rispettivi advisory CVE.
