# LOGBOOK — Fase 2: Stack onesto sulle risorse (v0.0.3)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata al 2026-08-27, dopo #22 e #21 (sessione C)

**Dove siamo**: #22 e #21 implementati e validati **staticamente** (nessun
demone Docker in questa sessione); **nessuno dei due è ancora verificato a
runtime**. Base: tag `v0.0.2` → `966422d` (annotato), `develop` allineato col
merge `cfc98f3`. La Fase 1 ha chiuso P-1 nel comportamento (T0.6 PASS con
modelli veri) e la famiglia P-11/P-12/P-13; il suo esito distillato è in
`docs/logbook/SINTESI_fasi_chiuse.md`.

**Scope della fase** (`docs/piano_ricovero.md` §6, riga v0.0.3 — obiettivo O4):
smettere di mentire sulle risorse. Issue di fase
[#5](https://github.com/danielesalpietro/NORTHSTREAM/issues/5).

| Sub-issue | Contenuto | Finding | Stato |
|---|---|---|---|
| [#22](https://github.com/danielesalpietro/NORTHSTREAM/issues/22) | `trino/catalog/postgresql.properties` + configurazione memoria Trino | **P-2** | Implementato, verificato solo staticamente |
| [#21](https://github.com/danielesalpietro/NORTHSTREAM/issues/21) | Compose profiles `core`/`lakehouse`/`governance` + `mem_limit` per servizio | **P-5** | Implementato, verificato solo staticamente |
| [#23](https://github.com/danielesalpietro/NORTHSTREAM/issues/23) | Tier hardware riscritti sui numeri misurati + **T-PROF** | §4.2/4.3 review | Non iniziato (ENV-L, altra sessione) |
| [#44](https://github.com/danielesalpietro/NORTHSTREAM/issues/44) | Esclusività dell'host: pre-check, run-check, post-run nel `manifest.json` | — (nato dalla Fase 1) | In corso, sessione D in parallelo |
| [#24](https://github.com/danielesalpietro/NORTHSTREAM/issues/24) | Release v0.0.3: gate, CHANGELOG, tag | — | Non iniziato |

**Decisioni prese, con il perché**
- **Catalogo chiamato `postgresql.properties`, non `postgres.properties`**:
  il test T0.7 (scritto prima di questa sessione) e la tabella del piano
  §4.1 puntano entrambi su `postgresql.public.orders` — il nome del file
  Trino fissa il nome del catalogo. La review §4.2 lo chiama "postgres.properties"
  di sfuggita, ma non è il contratto vincolante; il test lo è. Rinominare
  avrebbe fatto fallire T0.7 in silenzio.
- **Heap Trino fisso (`-Xms1G -Xmx2G`) al posto del default `MaxRAMPercentage=80`**:
  senza un `mem_limit` di container quel default dimensiona l'heap sull'80%
  della RAM **dell'host**, non del laptop — è esattamente il comportamento
  che P-5 denuncia. Fissarlo nello stile già usato per Elasticsearch
  (`-Xmx1g`) risolve il problema anche prima che #21 introduca `mem_limit`,
  e resta corretto dopo. **Dichiarato come stima**, non misura: nessun run
  reale lo ha ancora esercitato.
- **`schema-registry` (Apicurio) in `lakehouse`, non in `core`, con la
  dipendenza forte di `kafka-ui` rimossa**: la review lo classifica
  scenografia (Debezium gira con `schemas.enable=false`, nessuno schema è
  mai registrato). Tenerlo comunque in `core` solo per non rompere
  `kafka-ui` avrebbe vanificato lo scopo di P-5. La `KAFKA_CLUSTERS_0_SCHEMAREGISTRY`
  resta configurata: kafka-ui mostra quel pannello vuoto se Apicurio non
  gira, non si rifiuta di avviarsi. *Alternativa scartata*: spostare
  `kafka-ui` fuori da `core` — ma la review (§4.3b) lo elenca esplicitamente
  nel profilo sempre-attivo.
- **`start-addon.sh`/`.ps1` di default avviano tutti e tre i profili**, non
  solo `core`: senza questo cambio, l'introduzione dei profili avrebbe
  silenziosamente ridotto lo stack che `ci-nightly` avvia (via `--gpu`, non
  `--profile`) da 19-21 container a 11, facendo sparire Trino dalla suite
  `full` proprio mentre T0.7 dovrebbe iniziare a passarci. Regola CLAUDE.md
  §5/piano rispettata: comportamento di default dichiarato esplicitamente,
  non lasciato a un effetto collaterale. Nuovo flag opt-in `--profile
  <nome>[,<nome>]` per chi vuole lo stack snello.
- **`mem_limit` dichiarati come stime, non misure**, tranne due: Trino
  (2560m, margine sopra l'heap fisso di 2G appena scritto) ed Elasticsearch
  (1536m, margine sopra `-Xmx1g` preesistente) sono ancorati a un valore
  reale già nel compose, non a una sensazione. Gli altri 18 derivano dal
  profilo tipico della tecnologia per un carico da laboratorio. `debezium-connect`
  ha margine maggiore (1536m) degli altri singoli servizi JVM (1024m)
  perché è l'unico esercitato sotto carico CDC reale a ogni push di
  `ci-smoke`: una stima troppo stretta lì si manifesta come OOM-kill
  silenzioso, non come errore leggibile — rischio che gli altri servizi non
  hanno nello stesso grado. **Ollama deliberatamente senza `mem_limit`**:
  il fabbisogno dipende dal modello/tier scelto (350m→32b), un tetto fisso
  romperebbe un tier o sarebbe inutile per un altro — decisione per-tier
  rimandata a #23 su numeri misurati.
- **T0.7 non promosso nella suite `ci`** (a differenza di T0.6 in v0.0.2):
  `ci-smoke` avvia un sottoinsieme di servizi nominati esplicitamente che
  **esclude Trino di proposito** (commento nel workflow: tenere Elasticsearch/
  OpenMetadata/Flink/Trino fuori da un runner da 16 GB). Promuovere T0.7 in
  `SUITE_CI` senza avviare anche Trino in `ci-smoke` lo farebbe SKIPpare per
  sempre — suite membership decorativa, non un segnale reale, la lezione
  opposta a quella di T0.6. Aggiungere Trino a `ci-smoke` è ora più
  sostenibile in RAM grazie all'heap fisso da 2G, ma resta una decisione
  aperta perché richiede anche coprire la dipendenza `minio` e Trino non ha
  ancora un healthcheck (P-8) — **rimandata**, non fatta di nascosto dentro
  #21/#22. T0.7 gira comunque nelle suite `core` e `full`.
- **`expected/current.json` non toccato**: T0.7 resta `XFAIL` finché non è
  misurato su Docker reale (ENV-L o nightly ENV-W), stessa disciplina già
  seguita per T0.6 in v0.0.2 — il file non si piega al codice scritto, solo
  al comportamento osservato.

**Verificato in questa sessione (nessun demone Docker disponibile)**
- `docker compose config -q` verde su tutte e tre le combinazioni (base,
  base+addon, base+addon+gpu) e su tutte le combinazioni di profilo
  (nessuno, `core`, `core+lakehouse+governance`).
- `docker compose --profile core config --services` → esattamente gli 11
  servizi attesi (landing-page, kafka, kafka-ui, postgres, adminer,
  debezium-connect, ollama, open-webui, qdrant, stream-agent, data-generator);
  senza `--profile` (default) → **gli stessi 11**, non i 19-21 di prima —
  è il cambiamento di comportamento voluto da P-5, isolato dal comportamento
  di `start-addon.sh` (che invece resta invariato di default, v. sopra).
  Con tutti e tre i profili → i 21 servizi di sempre (invariato).
- `bench/t0/run.sh --suite static` → 3 PASS, nessuna regressione, prima e
  dopo ogni modifica.
- `yamllint -c .yamllint.yml` sui due file compose modificati: un solo
  warning, **preesistente** (riga lunga sul digest immagine MinIO, già
  presente prima di questa sessione — confermato con `git stash`), nessun
  warning nuovo introdotto.
- **Non verificato, e non verificabile da questa sessione**: che lo stack
  parta davvero sotto i nuovi `mem_limit` senza OOM-kill, che T0.7 flippi a
  PASS, che il profilo `core` resti sotto i 14 GB di T-PROF. Serve un run
  reale — `bench/t0/run.sh --suite core` (o `full`) su ENV-L, oppure la
  prossima `ci-smoke`/nightly.

**Gate di chiusura**: tutti i PASS di v0.0.2 restano PASS — in particolare T0.6,
T0.2 e T0.3, misurati con modelli veri — CI verde, e nessun nuovo XFAIL non
dichiarato.

**Ereditato dalla Fase 1, da non riscoprire**
- **#44 è già iniziato**: il flag `--exclusivity` e le condizioni iniziali nel
  manifest (connettore, slot di replica) sono su `feature/soak-harness`
  (`fe91a74`, `cdde3a7`). Chi lavora #44 parte da lì invece di riscriverli.
- **ENV-W ha due stati** (manutenzione / noleggio vast.ai) e le finestre GPU si
  prenotano con anticipo: piano §2.1. Prima di una finestra prenotata, prova a
  secco dello stesso comando.
- **`RUN_NIGHTLY` resta spenta**, e #44 è uno dei due prerequisiti per accenderla
  (l'altro è #47, Fase 3).

**Numeri misurati**: nessuno nuovo in questa fase — il metro resta
`docs/runs/20260826-2053-envw-5eb456a-baseline.md`, più i run di v0.0.2 elencati
nell'ESITO FASE 1. I `mem_limit` di questa entry sono stime dichiarate, non
misure (v. sopra).

**Prossimo passo**: eseguire `bench/t0/run.sh --suite core` (o `full`) su un
ambiente con Docker reale (ENV-L, o la prossima nightly ENV-W) per (a) far
flippare T0.7 e aggiornare `expected/current.json` di conseguenza, (b)
osservare se qualche `mem_limit` stimato è troppo stretto (OOM-kill) e
correggerlo sul numero osservato — non a sensazione. Poi #23 (tier misurati +
T-PROF, ENV-L) e #44 (sessione D, in corso).

---

## 2026-08-27 — remota, nessun demone Docker — sessione operativa C (Fase 2)

- **Obiettivo della sessione**: #22 (catalogo Trino + memoria, P-2, T0.7) e
  #21 (compose profiles + `mem_limit`, P-5), in quest'ordine, su
  `release/v0.0.3`.
- **Fatto** (commit `c471707`, dopo rebase su `199fd8d`/sessione D — SHA annotato a push avvenuto, come da regola su branch condiviso):
  - `trino/catalog/postgresql.properties`: catalogo JDBC verso
    `postgres:5432/sales`. Nome file `postgresql.properties`, non
    `postgres.properties`: T0.7 e il piano §4.1 fissano il nome del
    catalogo su `postgresql.public.orders`.
  - `trino/etc/jvm.config`: heap fisso `-Xms1G -Xmx2G` al posto del
    `MaxRAMPercentage=80` di default dell'immagine, montato su
    `/etc/trino/jvm.config` (nuovo volume nel servizio `trino`).
  - `docker-compose-northstream-ai.yml`, `docker-compose.addon.yml`:
    `mem_limit` su 20/21 servizi (Ollama escluso di proposito, v. sotto);
    profili `lakehouse` (flink-jobmanager, flink-taskmanager, minio,
    create-minio-bucket, trino, schema-registry) e `governance`
    (openmetadata-db, elasticsearch, execute-migrate-all, openmetadata);
    `core` = nessun tag (landing-page, kafka, kafka-ui, postgres, adminer,
    debezium-connect, ollama, open-webui + l'addon).
  - Rimossa la dipendenza forte `kafka-ui → schema-registry` (bloccava
    `--profile core` da solo: "depends on undefined service"), scoperta
    durante la validazione statica, non nella specifica originale.
  - `start-addon.sh` / `start-addon.ps1`: default a tutti e tre i profili
    (comportamento invariato), nuovo flag opt-in `--profile`/`-Profile`.
  - `CHANGELOG.md`: voce `[Unreleased]` per #22 e #21.
- **Decisioni prese**: v. SINTESI DI FASE sopra, aggiornata da questa stessa
  sessione — non duplicate qui per evitare la stessa lezione della Fase 0
  (compressione quasi gratuita se la sintesi resta viva a ogni sessione).
- **Test eseguiti**:
  - `docker compose config -q` → PASS su base, base+addon, base+addon+gpu,
    e su tutte le combinazioni di profilo (nessuno / `core` / tutti e tre).
  - `docker compose --profile core config --services` e la variante senza
    flag → entrambe i soli 11 servizi attesi; con tutti e tre i profili →
    i 21 di sempre.
  - `bench/t0/run.sh --suite static` → 3 PASS (T0.1, T0.12, T-REPRO),
    eseguito prima e dopo le modifiche, nessuna regressione.
  - `yamllint -c .yamllint.yml` sui due compose modificati → un solo
    warning, verificato preesistente con `git stash` (riga lunga sul
    digest MinIO, non introdotta da questa sessione).
  - **Non eseguiti, dichiarato esplicitamente** (nessun demone Docker in
    questa sessione): `docker compose up` reale, T0.7 end-to-end, T-PROF,
    qualunque verifica che i nuovi `mem_limit` non causino OOM-kill.
- **Costo della sessione**: `claude-sonnet-5`, sessione remota cloud
  (`session_01Np7X8P4C4cUQAikUz4FDHP`). `get_session` non espone un campo
  `usage`/token per questa sessione in questo momento — costo non
  misurabile da qui, non stimato (CLAUDE.md §5: un campo assente si nota,
  non si finge una misura).
- **Non funziona / sospeso**: T0.7 non promosso nella suite `ci` — motivato
  sopra (Trino escluso di proposito da `ci-smoke` per RAM del runner;
  promuoverlo senza avviare Trino lì lo farebbe SKIPpare per sempre, non è
  un segnale reale). Resta nelle suite `core`/`full`.
- **Prossimo passo per la sessione successiva**: eseguire
  `bench/t0/run.sh --suite core` (o `full`) su Docker reale — ENV-L, o la
  prossima nightly `ci-nightly` su ENV-W — per far flippare T0.7 in
  `expected/current.json` e per scoprire se un `mem_limit` stimato è troppo
  stretto.
- **Decisioni richieste all'owner**: nessuna bloccante. Segnalazione per
  quando qualcuno guarda #23: se le misure ENV-L mostrano che aggiungere
  Trino a `ci-smoke` è ora sostenibile in RAM (grazie all'heap fisso a 2G),
  vale la pena riconsiderare la promozione di T0.7 in `SUITE_CI` — oggi
  bloccata solo dall'assenza di un healthcheck Trino (P-8) e dalla
  dipendenza `minio` non ancora avviata lì.
