# LOGBOOK — Fase 1: Raggiungibilità e riproducibilità (v0.0.2)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata al 2026-08-27 (sessioni A e B, verifica ENV-W)

> **Correzione di riferimenti (supervisione, 27/08)**: la terza entry cita i commit
> `5f98800` e `531ed58`, che **non esistono nel repository** — sono gli SHA che la
> Sessione A aveva in locale prima del rebase imposto dal push su branch condiviso.
> Gli SHA reali sono **`83b416c`** (#41, bit di esecuzione) e **`5534ef7`** (#42,
> teardown). È l'effetto collaterale prevedibile di due sessioni sullo stesso branch:
> annotare l'SHA *dopo* il push, non prima.

**Dove siamo**: **Sessione A** ha chiuso lato codice #41 (P-9) e #42 (P-10) — v.
terza entry del 27/08. #41 verificato su clone pulito (exit 126 sparito). **#42 è ora
verificato per misura**: la sessione ENV-W ha innescato la prima nightly reale del
progetto (run 33056266125, `workflow_dispatch` su `9082a02`) e dopo il teardown
`ollama_data` esiste ancora, `ollama list` elenca entrambi i Granite, e i sette blob
sono bit-identici a prima del run; i tre volumi di stato sono invece spariti, quindi il
teardown ripulisce ancora. Run report
`docs/runs/20260827-0859-envw-9082a02.md`.
**Sessione B** ha implementato e committato, nello stesso branch, **#17, #16,
#18, #19** (4 commit, uno per issue) — verifica anch'essa solo statica (nessun
demone Docker in quella sessione): `docker compose config`, `bench/t0/run.sh
--suite static` (T0.1/T0.12/T-REPRO PASS), `yamllint`/`ruff` puliti. **La verifica
comportamentale reale di entrambe le sessioni spetta a CI/ENV-W**: `ci-smoke` sul
push di B è il primo collaudo reale del cambio d'immagine Kafka (T0.6); la nightly
su ENV-W è il collaudo mancante di #42. Le due sessioni non si sono sovrapposte:
A ha toccato solo il bit di esecuzione dei tre script del Quick Start e il
teardown di `ci-nightly.yml`; B ha toccato compose, harness e i due nuovi
`preflight.*`.
La sessione di supervisione ha lavorato **fuori dallo scope di questa release**
(solo piano e review, nessuna modifica al sistema): ha introdotto **O8** e **O9**
e la **Fase 6 / v0.0.6** fra governance e beta1, con la specifica vincolante di O9
(contratto `ChangeFact`, piano §1.1) — v. le prime due entry del 27/08.
Base: tag `v0.0.1` → `d3053be`, `develop` allineato. Lo stack sulla Z8 è spento
con i volumi conservati; il runner self-hosted `z8-env-w` è registrato e attivo,
`ci-nightly` ha girato una volta a mano ed è tornata dormiente:
`RUN_NIGHTLY` resta **non impostata**, ma il blocco che lo imponeva (#42) è caduto —
accenderla è ora una decisione dell'owner, non un rischio per i modelli.

**Scope della fase** (`docs/piano_ricovero.md` §6, riga v0.0.2 — obiettivo O3):
rendere lo stack raggiungibile dall'host come documentato e riproducibile nel
tempo. Issue di fase [#4](https://github.com/danielesalpietro/NORTHSTREAM/issues/4).

| Sub-issue | Contenuto | Finding | Stato |
|---|---|---|---|
| [#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16) | Doppio listener Kafka (interno `kafka:9092`, esterno `localhost:29092`) | P-1 | **T0.6 PASS, verificato su ci-smoke** (run 33057147479) |
| [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17) | Pin immagini a versione+digest; sostituzione di `bitnamilegacy/kafka` | P-3, P-4 | **implementato**; il cambio d'immagine ha regredito T0.2/T0.3 nell'harness (PATH), corretto — da riconfermare su ci-smoke |
| [#18](https://github.com/danielesalpietro/NORTHSTREAM/issues/18) | Binding porte su `127.0.0.1` | P-7 | **implementato**, verificato staticamente |
| [#19](https://github.com/danielesalpietro/NORTHSTREAM/issues/19) | Script preflight (`vm.max_map_count`, RAM, GPU) | P-6 | **implementato**, eseguito in sandbox; `.ps1` da collaudare su Windows/ENV-L |
| [#41](https://github.com/danielesalpietro/NORTHSTREAM/issues/41) | Bit di esecuzione sui tre script del Quick Start | **P-9** | **chiuso e verificato su ENV-W**: lo step `./start-addon.sh --gpu` della nightly è verde |
| [#42](https://github.com/danielesalpietro/NORTHSTREAM/issues/42) | Teardown di `ci-nightly` che cancella `ollama_data` | **P-10** | **chiuso e verificato su ENV-W**: progression test superato (v. sopra) |
| [#45](https://github.com/danielesalpietro/NORTHSTREAM/issues/45) | Volume `kafka_data` incompatibile col nuovo UID di `apache/kafka` (#17) | **P-11** | **implementato**: preflight rileva e fallisce con rimedio; verifica reale con volume a proprietà vecchia spetta a ENV-W |
| [#46](https://github.com/danielesalpietro/NORTHSTREAM/issues/46) | `trino/catalog` root-owned blocca `actions/checkout` alla nightly successiva | **P-12** | **implementato**: `.gitkeep` committato; verifica reale (due nightly consecutive) spetta a ENV-W, dopo che l'owner ha sbloccato il workspace col `sudo` che la sessione non ha |
| [#20](https://github.com/danielesalpietro/NORTHSTREAM/issues/20) | Release v0.0.2: gate, CHANGELOG, tag | — | non iniziata |

**Progression test dichiarati**: **T0.6** XFAIL → **PASS** dichiarato in
`bench/t0/expected/current.json`, promosso anche nella suite `ci` (requisito
esplicito del briefing, non solo `core`/`full`) — **da confermare su un
broker reale**, non ancora osservato; **T-REPRO** nuovo, static, **verificato
PASS in questa sessione** (8/8 immagini di P-3/P-4 pinnate a digest); il
preflight fallisce con messaggio chiaro — **verificato in sandbox** (v. sotto).

**Gate di chiusura**: tutti i PASS di v0.0.1 restano PASS — in particolare i
cinque del run di riferimento — CI verde, e nessun nuovo XFAIL non
dichiarato. **Non ancora verificato**: questa sessione non ha potuto
rieseguire T0.2–T0.5/T0.8/T0.11 (serve un demone Docker); resta a `ci-smoke`
(T0.1,T0.2,T0.3,T0.4,T0.6,T0.8,T0.11) e a una sessione ENV-W/ENV-L per T0.5
e la suite `full`.

**Decisioni prese** (le precedenti fasi sono in `SINTESI_fasi_chiuse.md`):

*Sessione A (#41, #42)*:
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

*Sessione B (#17, #16, #18, #19)*:
- **#17 prima di #16, come da briefing**: i listener sono stati scritti una
  sola volta, sull'immagine Apache — mai sul formato Bitnami. Il commit #17
  non cambia il comportamento (listener singolo, ancora XFAIL su T0.6); solo
  #16 introduce il doppio listener.
- **`apache/kafka:4.3.1`** (non `confluentinc/cp-kafka`, per la licenza
  Confluent Community sui componenti non-broker già scartata dalla review
  P-3) — env `KAFKA_*`, confermato dal README ufficiale dell'immagine
  (`docker/examples/README.md` nel repo `apache/kafka`, letto via
  `raw.githubusercontent.com`, unico host GitHub raggiungibile: `github.com`
  e le API GitHub per repository esterni al proprio scope sono bloccate dal
  proxy). Digest e versioni delle altre 7 immagini risolti via API anonima
  Docker Hub/GHCR (`registry-1.docker.io`, `ghcr.io` raggiungibili;
  `quay.io`, `registry.k8s.io` bloccati dalla policy — non serviti).
- **`CLUSTER_ID` fissato** (`dnioVix1ST-1IPm_HTjhVw`, generato una volta,
  non rigenerato ad ogni build) invece di lasciarlo assente: l'esempio
  ufficiale Apache per KRaft single-node lo imposta esplicitamente e lo
  script di avvio dell'immagine lo logga come "provided" — nessuna conferma
  diretta che sia opzionale, quindi si è scelta la via documentata.
  **Alternativa scartata**: lasciarlo non impostato sperando in un
  auto-provisioning non documentato — rischio non giustificato per un
  cluster single-node dove il valore non ha altro significato che
  l'identità dei dati sul volume.
- **T-REPRO è un test statico**, non un vero "due pull a distanza di
  giorni": pinnare a `@sha256:` rende quella proprietà vera per
  costruzione (un digest è per definizione lo stesso contenuto), quindi ciò
  che è verificabile meccanicamente è che il pin ci sia — non serve
  aspettare giorni per dimostrarlo. **Alternativa scartata**: un test che
  esegue davvero due `docker compose pull` distanziati nel tempo — richiede
  stato persistente fra esecuzioni e un demone Docker, e non aggiungerebbe
  garanzie oltre a ciò che il pin garantisce già da solo.
- **T-REPRO scope-limitato agli 8 image esplicitamente citati da P-3/P-4**
  (non "ogni `image:` nel compose"): la prima versione del test falliva su
  11 immagini perché includeva anche postgres/debezium/flink/trino/
  openmetadata/elasticsearch/nginx, mai citate come "tag mobile" dalla
  review e fuori scope di questa issue. Il test conta anche che siano
  esattamente 8, per accorgersi se un pattern smette di matchare (falso
  negativo silenzioso) o se ne compare uno nuovo non pinnato.
- **Preflight: passo esplicito, non invocato da `start-addon.sh`/`.ps1`**
  in questa release. *Motivazione*: un fallimento hard diventerebbe un
  nuovo punto di rottura sul path critico del Quick Start — esattamente
  dove P-9 (stessa release, sessione A) ha appena tolto un blocco — prima
  che il preflight sia stato collaudato sulla matrice reale di ambienti
  (WSL2, Linux nativo, Z8). *Alternativa scartata*: invocazione automatica
  con `|| true` per non bloccare — scartata perché un preflight che non può
  fallire non è un preflight, è un banner ignorabile. Bilancio esplicito
  richiesto dal briefing: l'automatico protegge di più ma aggiunge un punto
  di fallimento in avvio; qui ha vinto la seconda considerazione perché lo
  script è nuovo e non ancora provato fuori da questa sandbox.
- **Soglie RAM/disco del preflight allineate alla tabella hardware già nel
  README** (Minimal 16 GB/30 GB, Recommended 32 GB/50 GB, Optimal 32 GB+/
  80 GB+), non a numeri nuovi inventati per l'occasione — coerente con lo
  spirito di verità documentale anche se il README stesso non viene toccato
  in questa sessione.
- **`bench/t0/lib/doc_truth.py` corretto in corsa**: `kafka_advertises_host()`
  leggeva solo la chiave Bitnami `KAFKA_CFG_ADVERTISED_LISTENERS`. Dopo la
  migrazione (#17) quella chiave non esiste più: il linter T0.12 sarebbe
  rimasto **silenziosamente cieco** — falso negativo su P-1 — nel momento in
  cui il README guadagnerà l'endpoint `localhost:29092` a fine release.
  Corretto per leggere anche la chiave Apache; verificato con una chiamata
  diretta alla funzione (True su 29092, False su 9092).
- **README non toccato**, per direttiva esplicita di questa sessione
  (CLAUDE.md §4: si aggiorna solo a fine release). **Debito documentale
  registrato qui** perché la sessione di chiusura release non dipenda dal
  ricordo di questa conversazione:
  1. Tabella servizi (riga Kafka, oggi "in-network only: `kafka:9092`") e la
     nota righe 166–173 vanno riscritte per riflettere `localhost:29092`
     come endpoint host valido, con lo stesso caveat su ciò che resta
     interno.
  2. Sezione prerequisiti: menzionare `preflight.sh`/`.ps1` come passo
     opzionale consigliato, con la scelta di non-invocazione-automatica
     motivata.
  3. Nessuna sezione oggi cita `9092` come endpoint host raggiungibile (era
     già stato tolto in v0.0.1), quindi **nessun claim è diventato falso**
     da queste modifiche: l'eccezione di correzione immediata non si
     applica, è un'omissione da colmare a fine release, non un'urgenza.

**Numeri misurati in questa sessione** (verifica statica, non un run T0
formale — nessun `RUN_ID`/`docs/runs/` generato, coerente con CLAUDE.md §5
per una sessione senza demone Docker):
- `bash bench/t0/run.sh --suite static` → `T0.1 PASS, T0.12 PASS, T-REPRO
  PASS`, `RESULT: OK (no regression)` — eseguito 4 volte durante la sessione,
  una per commit, sempre verde.
- `docker compose ... config -q` su tutte e 4 le combinazioni (base;
  base+addon; base+addon+gpu; base+addon+mock-ollama/ci-smoke) → tutte
  valide dopo ogni commit.
- Verifica programmatica: tutte le porte pubblicate hanno `host_ip:
  127.0.0.1` (17 porte, incluse le due nuove di Kafka).
- `preflight.sh` eseguito realmente in questa sandbox (bash vero, nessun
  demone Docker): rileva correttamente `vm.max_map_count=65530` (sotto
  soglia), 15 GiB RAM e 29 GiB disco liberi (entrambi sotto soglia
  `minimal`) → `FAIL` con tre rimedi azionabili, exit 1. `--gpu` senza
  `nvidia-smi` → `FAIL`, exit 1. Tier sconosciuto → exit 2. `preflight.ps1`
  non eseguibile qui (nessun PowerShell).
- `yamllint`/`ruff` puliti (un solo warning preesistente non bloccante:
  riga 185 di `docker-compose-northstream-ai.yml` a 123 caratteri, dovuto
  alla lunghezza intrinseca di `image@sha256:...`).

**Numeri misurati**: il metro di partenza resta
`docs/runs/20260826-2053-envw-5eb456a-baseline.md`. Verifiche statiche di
sessione B elencate sopra (T0.1/T0.12/T-REPRO PASS, porte 127.0.0.1, preflight
in sandbox). **Primo run reale della fase**, dalla sessione ENV-W:
`20260827-0859-envw-9082a02` (suite `full`, modelli veri, `9082a02` — cioè
**prima** dei commit di B, arrivati durante l'esecuzione):
`{"PASS": 5, "FAIL": 1, "XFAIL": 4, "XPASS": 2}`. Contro il riferimento:
T0.1–T0.4 invariati, T0.12 PASS atteso, XFAIL invariati, **T0.9 XFAIL → XPASS**
(da non promuovere: stessa fragilità di #40), **T0.5 PASS → FAIL** — non una
regressione del sistema, ma un artefatto di condizione: lo stesso commit dà
**PASS 3 su 3** a stack caldo, e il diff su `stream-agent/` dalla baseline è
vuoto. Dettaglio in `docs/runs/20260827-0859-envw-9082a02.md`.

**Aperto**
- **#42 verificato con una nightly reale il 27/08** (run 33056266125): il blocco
  è caduto. `RUN_NIGHTLY` resta comunque **spenta**: accenderla è una decisione
  dell'owner, non una conseguenza automatica della verifica.
- **La nightly misura a freddo**: avvia lo stack ed esegue subito la suite, dentro
  la finestra cieca di A-8/#39 e col primo caricamento dei modelli in corso. T0.5 e
  T0.9 hanno dato per questo verdetti diversi dal reale. Serve un *warm-up gate*
  prima che un FAIL della nightly significhi qualcosa — **decisione richiesta
  all'owner**, issue sorella di #39/#40 non ancora aperta.
- **La 3090 di ENV-W è condivisa** con un container estraneo al progetto
  (`C.48865947`, vast.ai): 11,6–22,3 GiB dei 24,5 occupati durante la verifica.
  Variabile non controllata di ogni misura su ENV-W.
- **`ci-smoke` sul push di B era rosso, non per la KRaft — corretto, da riconfermare**:
  run 33057147479, `{"PASS": 3, "FAIL": 2, "XFAIL": 2}`. **T0.6 era PASS** — il
  progression test della release è flippato, P-1 chiuso nel comportamento. I due
  FAIL (T0.2, T0.3) erano **nell'harness**: `t0.02` e `t0.03` invocavano
  `kafka-topics.sh` / `kafka-console-consumer.sh` per nome nudo, e in
  `apache/kafka:4.3.1` i binari stanno in `/opt/kafka/bin/` e non nel PATH
  (verificato con `docker run`). **Sessione B ha corretto e pushato** (v. quarta
  entry del 27/08): entrambi i test ora provano il path assoluto per primo, con
  fallback al nome nudo. **Da riconfermare**: nessun run reale dopo il fix in
  questa sessione (nessun demone Docker) — resta a `ci-smoke` sul nuovo push.
- **P-11/[#45](https://github.com/danielesalpietro/NORTHSTREAM/issues/45) — implementato
  da questa sessione**: `preflight.sh`/`.ps1` rileva un volume `kafka_data` preesistente
  (via le label compose, non un nome hardcoded) e verifica che sia scrivibile
  dall'utente `1000:1000` di `apache/kafka` con un `busybox` usa-e-getta; fallisce col
  comando di rimedio (`docker volume rm ...`) se non lo è. Riga breaking nel CHANGELOG.
  **Non verificabile in CI per costruzione** (ogni run parte da un volume inesistente):
  la logica di branching è stata testata con un `docker` finto in questa sessione;
  **la verifica reale — un volume creato deliberatamente con la proprietà vecchia —
  spetta a ENV-W**.
- **P-12/[#46](https://github.com/danielesalpietro/NORTHSTREAM/issues/46) —
  implementato da questa sessione**: `trino/catalog/.gitkeep` committato, così Docker
  non ricrea più la directory come `root:root` al primo `up`. **Lo sblocco del
  workspace già compromesso su ENV-W resta dell'owner** (richiede `sudo`, che la
  sessione ENV-W non ha): finché non è fatto, la prova vera del fix (due nightly
  consecutive sullo stesso workspace) non può girare.
- **La suite `full` sul codice di B** (`7364349` o successivo) resta da eseguire su
  ENV-W: il run del 27/08 misura `9082a02` e la sua riga T0.6 XFAIL **non** è il
  verdetto sul progression test della release.
- **`preflight.ps1` da collaudare** su un host Windows reale o ENV-L.
- **Debito documentale README** (tabella Kafka, sezione prerequisiti per il
  preflight — v. decisioni sopra) da pagare a fine release, insieme a #20.
- Fuori fase ma tracciato: #40 (T0.10 fragile, Fase 3), P-5 (Fase 2, T-PROF),
  RP-0 (opzionale, Fase 5).

**Conseguenza di pianificazione (27/08)**: il release train ha ora **sette** fasi.
La beta1 si sposta da metà a **fine settembre**. Il costo è accettato dall'owner:
senza O8/O9 la beta1 sarebbe un sistema che passa i propri test tecnici e non
dimostra niente a un utente finale.

**Prossimo passo**: `ci-smoke` è verde e T0.2/T0.3 sono confermati PASS (v.
quinta entry del 27/08) — **T0.6 è il progression test superato**. #45 (P-11)
e #46 (P-12) sono implementati (v. sopra), ma nessuno dei due è verificabile
in CI per costruzione: **serve ENV-W** per (a) creare deliberatamente un
volume `kafka_data` con la proprietà vecchia e osservare che il preflight lo
rifiuti, e (b) far girare due nightly consecutive sullo stesso workspace dopo
che l'owner ha sbloccato con `sudo` la `trino/catalog` root-owned già creata.
Se entrambe verificate: #20 (gate di release, CHANGELOG → versione, README a
fine release, tag).

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

---

## 2026-08-27 — sessione cloud (nessun demone Docker) — sessione B, `claude-sonnet-5`

- **Obiettivo della sessione**: #17 → #16 → #18 → #19, in quest'ordine (vincolato
  dal briefing: l'immagine Kafka prima dei listener, per non scrivere la
  configurazione due volte su due formati di env var diversi).
- **Fatto**:
  - `c33b5b0` — #17: `bitnamilegacy/kafka:3.7.1` → `apache/kafka:4.3.1@sha256:...`
    (env `KAFKA_CFG_*` → `KAFKA_*`, comportamento del broker invariato); le altre
    7 immagini mobili (`kafka-ui`, `adminer`, `minio`, `mc`, `qdrant`, `ollama`,
    `open-webui`) pinnate a versione+digest.
  - `d00c3ea` — #16: doppio listener `INTERNAL://kafka:9092` /
    `EXTERNAL://localhost:29092`; T0.6 promosso nella suite `ci` di
    `bench/t0/run.sh` (requisito esplicito del briefing); nuovo test statico
    `T-REPRO`; fix di `kafka_advertises_host()` in `doc_truth.py` (v. Decisioni
    nella sintesi).
  - `e7933b4` — #18: tutte le porte pubblicate (17, comprese le due di Kafka)
    da `porta:porta` a `127.0.0.1:porta:porta`, su entrambi i compose e su
    `bench/ci/mock-ollama.yml`.
  - `3295c5a` — #19: `preflight.sh` / `preflight.ps1` — `vm.max_map_count`,
    RAM/disco per tier, GPU con `--gpu`.
- **Decisioni prese**: v. SINTESI DI FASE sopra (non ripetute qui per evitare
  la duplicazione che CLAUDE.md §8 chiede di non produrre tra logbook e testa).
- **Test eseguiti**:
  - `bash bench/t0/run.sh --suite static --env sandbox-*` (4 esecuzioni, una
    per commit) → `T0.1 PASS, T0.12 PASS, T-REPRO PASS`, `RESULT: OK` ogni volta.
  - `docker compose -f ... config -q` sulle 4 combinazioni rilevanti (base;
    +addon; +addon+gpu; +addon+mock-ollama) → tutte valide dopo ogni commit.
  - Verifica programmatica via `docker compose config` parsato in Python: ogni
    porta pubblicata ha `host_ip: 127.0.0.1`.
  - `preflight.sh` eseguito realmente (bash vero, nessun demone Docker):
    rileva `vm.max_map_count=65530`, 15 GiB RAM, 29 GiB disco liberi — tutti
    sotto soglia `minimal` in questa sandbox — `FAIL` con rimedi, exit 1;
    `--gpu` senza `nvidia-smi` → `FAIL`; tier sconosciuto → exit 2.
  - `yamllint -c .yamllint.yml .` e `ruff check stream-agent/ data-generator/
    bench/` → puliti (un warning preesistente non bloccante su una riga
    >120 caratteri, intrinseco alla lunghezza di `image@sha256:...`).
  - **Non eseguiti** (nessun demone Docker in questa sessione): T0.2–T0.5,
    T0.6 stesso, T0.8, T0.9–T0.11, la suite `core`/`full`. Nessun claim di
    esito per questi.
- **Costo della sessione**: `claude-sonnet-5` (come configurato). Durata
  dalla creazione all'ultimo turno registrato: ~20 minuti a metà sessione,
  sessione ancora aperta al momento di scrivere. Token/costo nozionale: **non
  esposti da `get_session`** per questo tipo di sessione al momento della
  misurazione (il campo `usage` non è presente nel risultato) — non stimato,
  come da CLAUDE.md §4.
- **Non funziona / sospeso**: la verifica comportamentale reale del cambio
  Kafka (T0.6, non-regressione T0.1–T0.5/T0.8/T0.11) è sospesa in attesa
  dell'esito di `ci-smoke` sul push di questa sessione, e di una sessione
  ENV-W/ENV-L per T0.5/suite `full`. `preflight.ps1` non collaudato (nessun
  PowerShell in questa sessione).
- **Prossimo passo per la sessione successiva**: controllare `ci-static`/
  `ci-smoke` sul push di `release/v0.0.2` a `3295c5a`; se verde, #20 (gate di
  release); se rosso, il primo sospetto è la configurazione KRaft
  dell'immagine `apache/kafka` (nome env var, path healthcheck, `CLUSTER_ID`)
  — v. le decisioni sopra per che cosa è dedotto da documentazione contro
  osservato davvero.
- **Decisioni richieste all'owner**: nessuna bloccante. Segnalazione: la
  scelta di non invocare automaticamente il preflight da `start-addon.sh` è
  reversibile e proposta per essere rivista dopo che lo script avrà girato
  su almeno un host reale (ENV-L o Z8).

## 2026-08-27 — ENV-W (Z8, sessione bridge Claude CLI) — host di verifica

- **Obiettivo della sessione**: eseguire su ENV-W il **progression test dichiarato di
  [#42](https://github.com/danielesalpietro/NORTHSTREAM/issues/42)** — una nightly reale
  dopo cui `ollama_data` esiste ancora e i modelli sono elencati — e archiviare il run
  secondo la convenzione `RUN_ID`. Sessione di sola esecuzione: nessun codice committato.
- **Fatto**:
  - Fotografia dello stato della macchina prima del run (richiesta dalla supervisione):
    stack spento e container rimossi, otto volumi `wap-northstream-lab_*` presenti,
    runner `z8-env-w` `active` da 10 h, 291 G liberi su `/mnt/wdc-docker`, 83 G su `/`.
  - Innescata la prima nightly reale del progetto:
    `gh workflow run ci-nightly.yml --ref release/v0.0.2 -f suite=full` → run
    **33056266125** su `9082a02`. **`RUN_NIGHTLY` non impostata** (il dispatch bypassa il
    gate di riga 31 per costruzione): accenderla resta una decisione dell'owner.
  - Run report `docs/runs/20260827-0859-envw-9082a02.md` committato; grezzi in
    `~/NORTHSTREAM-archive/20260827-0859-envw-9082a02/` (28 file, `sha256sum -c` 27/27
    OK, più la cartella `diagnosi-T0.5/` con i sei tentativi di riesecuzione).
- **Decisioni prese**:
  - **T0.5 non è trattato come blocco di release, e il perché è una misura, non un
    giudizio.** Il verdetto grezzo della nightly (`PASS` → `FAIL`) bloccherebbe la
    release per §5. Ma il retrieval nel run funziona (`context_used` porta 91.73 in
    entrambi i tentativi), il diff `5eb456a..9082a02` su `stream-agent/`, generatore,
    init e connettori è **vuoto**, e riesecuzioni mirate sullo stesso commit danno
    **PASS 3 su 3** a stack caldo. Il fallimento è un artefatto della condizione di run
    — suite lanciata a freddo subito dopo `start-addon.sh` — non un difetto della
    release. *Alternativa scartata*: dichiarare il blocco e fermare la release. Sarebbe
    stato letterale e sbagliato: avrebbe attribuito a v0.0.2 un difetto che il codice
    di v0.0.2 non contiene, e avrebbe insegnato a leggere la nightly come oracolo
    invece che come misura da interpretare.
  - **La prima riesecuzione è stata progettata male e lo si dice**: i tentativi 1-3
    hanno fallito **per un motivo diverso** dalla nightly (`context_used does not carry
    91.73`), perché lanciati dentro la finestra cieca di A-8/#39. Non riproducevano
    nulla. Solo i tentativi 4-6, a stack caldo, sono una misura del punto in questione.
    Registrato perché la lezione vale più del risultato: una riesecuzione che fallisce
    *diversamente* non conferma il fallimento originale.
  - **L'XPASS di T0.9 non va promosso a PASS**, per la stessa ragione per cui non fu
    promosso quello di T0.10 nel run di riferimento: nessuna riga dell'agent è cambiata,
    e il test dipende da quanti eventi la collection contiene al momento della domanda.
- **Test eseguiti**:
  - `gh workflow run ci-nightly.yml --ref release/v0.0.2 -f suite=full` → run
    33056266125, job **failure** in 10 min 48 s, **unico step fallito** `Run the T0 suite
    with real models`. Gli step `Start the full stack with the addon` (P-9, #41) e
    `Tear down` (P-10, #42, `if: always()`) sono **verdi**.
  - **Progression test #42 → PASS.** `docker volume ls | grep wap-northstream-lab` dopo
    il run: `kafka_data`, `postgres_data`, `qdrant_data` **rimossi**, `ollama_data`
    **presente**. `ollama list` (da container usa-e-getta montato sul volume, perché
    sull'host il binario non esiste): `granite-embedding:30m` 62 MB e `granite4:1b`
    3,3 GB **elencati**. `diff` dei 7 blob prima/dopo: **nessuna differenza** — non
    cancellati e riscaricati, proprio gli stessi bit.
  - **Verificato di sponda #41 (P-9)**: lo step `./start-addon.sh --gpu` non muore più
    con `Permission denied`; `git ls-files -s` dà `100755` sui tre script.
  - Suite `full` su `9082a02`, attese `current.json`:
    `{"PASS": 5, "FAIL": 1, "XFAIL": 4, "XPASS": 2}`. Contro il run di riferimento:
    T0.1–T0.4 PASS invariati, T0.12 PASS (atteso, flippato in v0.0.1), T0.6/T0.7/T0.8/
    T0.11 XFAIL invariati, T0.10 XPASS invariato, **T0.9 XFAIL → XPASS**, **T0.5 PASS →
    FAIL** (v. Decisioni).
  - `bench/t0/run.sh --suite full --only T0.5` ×6 su `9082a02`: **FAIL ×3** a stack
    freddo (fallimento di retrieval, A-8), **PASS ×3** a stack caldo (`ollama ps`:
    entrambi i modelli `100% GPU`), risposta che cita il valore al primo tentativo in
    1-2 s.
- **Costo della sessione**: **non misurabile** — sessione bridge (Claude CLI locale), il
  campo `usage` non è esposto (`CLAUDE.md` §4).
- **Non funziona / sospeso**:
  - **La nightly esegue la suite nella condizione peggiore**: avvia lo stack e misura
    subito, dentro la finestra cieca di A-8 e col primo caricamento dei modelli in corso.
    T0.5 e T0.9 hanno dato verdetti diversi dal reale per questo. Finché non esiste un
    *warm-up gate*, la nightly è una guardia di non-regressione indebolita. **Decisione
    richiesta all'owner**: aprire una issue sorella di #39/#40 per quel gate.
  - **La 3090 è condivisa con un container estraneo al progetto** (`C.48865947`,
    vast.ai), che in questa sessione ha occupato fra **11,6 e 22,3 GiB** dei 24,5. Non ha
    impedito il run, ma è una variabile non controllata di ogni misura su ENV-W.
  - `ollama` **non è installato sull'host**: ogni verifica sui modelli richiede un
    container. Da sapere per chi scriverà procedure di verifica su ENV-W.
  - Questo run misura `9082a02`, **prima** dei commit della sessione B arrivati durante
    l'esecuzione: la riga T0.6 XFAIL non è il verdetto sul progression test della release.
- **Prossimo passo per la sessione successiva**: eseguire un nuovo run `full` su ENV-W
  contro `7364349` (o successivo) per misurare **T0.6**, il progression test dichiarato
  di v0.0.2, ora che #17+#16 sono sul branch — e verificare che il binding su
  `127.0.0.1` (#18) non abbia rotto i PASS T0.2/T0.3.

### Addendum (stessa sessione, 09:25Z) — diagnosi del rosso di `ci-smoke` sul push di B

Controllato l'esito della CI prima di chiudere il turno. `ci-smoke`
[33057147479](https://github.com/danielesalpietro/NORTHSTREAM/actions/runs/33057147479)
sul push di sessione B è **rosso**: `{"PASS": 3, "FAIL": 2, "XFAIL": 2}`.

**La notizia buona, e va detta per prima**: **T0.6 → PASS**
(`host client obtained usable broker metadata from localhost:29092`). Il progression
test dichiarato di v0.0.2 è **flippato**: P-1 è chiuso nel comportamento, non solo nel
codice.

**I due FAIL sono nell'harness, non nel broker**:

```
T0.2  FAIL  (243s) not reachable within 240s: kafka
T0.3  FAIL  (5s)   sentinel 77.31 not observed on northstream.public.sensor_readings within 30s
```

Causa individuata e **verificata per misura**:

```
$ docker run --rm --entrypoint sh apache/kafka:4.3.1 -c 'command -v kafka-topics.sh; ls /opt/kafka/bin/kafka-topics.sh; echo $PATH'
NON in PATH
/opt/kafka/bin/kafka-topics.sh
PATH=/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

`bench/t0/tests/t0.02_stack_health.sh:19` invoca `kafka-topics.sh` e
`t0.03_cdc_sentinel.sh:28` invoca `kafka-console-consumer.sh` **per nome nudo**, contando
sul PATH. Nell'immagine Bitnami i binari erano nel PATH; in `apache/kafka:4.3.1` stanno
in `/opt/kafka/bin/` e **non** ci sono. Il broker sta benissimo — lo dimostra proprio
T0.6, che lo interroga dall'host e passa, e l'healthcheck del compose, che usa il path
assoluto ed è verde.

È la stessa lezione della Fase 0 sul `bash -lc` che perde il PATH, ripetuta da un altro
lato: **un cambio d'immagine sposta i binari, e i test che li chiamano per nome nudo
falliscono mentendo sul soggetto** — accusano il broker mentre il difetto è nella sonda.

**Non corretto qui**: questa sessione non committa codice (`CLAUDE.md` §2, riga sessioni).
Il fix è di sessione B, due righe: usare `/opt/kafka/bin/<comando>` con fallback al nome
nudo, come già fa l'healthcheck.

## Decisioni richieste all'owner

1. **`RUN_NIGHTLY`**: con #42 verificato per misura, il blocco che teneva la variabile
   spenta è caduto. Accenderla resta una tua decisione e non è stata presa qui.
2. **Warm-up gate della nightly** (v. "Non funziona / sospeso"): senza, i FAIL di T0.5 e
   T0.9 nelle notti future saranno rumore di condizione e non regressioni.

---

## 2026-08-27 (seconda entry) — sessione cloud (nessun demone Docker) — sessione B, `claude-sonnet-5`

- **Obiettivo della sessione**: rispondere al check-in della supervisione — `ci-smoke`
  rosso sul push precedente di questa sessione (run 33057147479), T0.2/T0.3 regrediti
  da PASS a FAIL. Diagnosi già fatta e verificata per misura dalla sessione ENV-W
  (v. entry precedente): non riprodotta qui, solo applicato il fix.
- **Fatto**:
  - `git pull --rebase origin release/v0.0.2` per integrare i commit di sessione A
    (`83b416c`, `5534ef7`) e della sessione ENV-W/supervisione (`9082a02`, `62a424b`,
    `be70f93`) arrivati nel frattempo.
  - Fix in `bench/t0/tests/t0.02_stack_health.sh` e `t0.03_cdc_sentinel.sh`: entrambi
    provano `/opt/kafka/bin/<comando>` per primo, con fallback al nome nudo (stesso
    pattern già in uso nell'healthcheck del compose) — commit successivo, v. SHA in
    testa dopo il push.
- **Decisioni prese**: nessuna nuova — il fix è meccanico e la diagnosi non era da
  rifare (indicazione esplicita del check-in). L'unica scelta è stata *dove* mettere
  l'assoluto: prima del nome nudo, non dopo, così un'immagine futura che avesse i
  binari in entrambi i posti userebbe sempre il percorso noto per costruzione invece
  di dipendere dall'ordine di risoluzione del PATH.
- **Test eseguiti**:
  - `bash -n` su entrambi i file modificati → sintassi valida.
  - Simulazione locale (senza container) delle due catene di fallback via `sh -c`
    con lo stesso comando costruito dallo script: entrambe risolvono nell'ordine
    atteso (assoluto → nome nudo), verificato che `$cmd` in `t0.03` resti
    letterale nella stringa passata a `sh -c` del container e non venga espanso
    prematuramente dalla bash esterna.
  - `bash bench/t0/run.sh --suite static` → `T0.1 PASS, T0.12 PASS, T-REPRO PASS`,
    nessuna regressione.
  - **Non eseguibile qui**: T0.2/T0.3 stessi, servono un demone Docker e un broker
    reale — la riconferma spetta a `ci-smoke` sul push di questa entry.
  - `yamllint`/`ruff` puliti (invariato).
- **Costo della sessione**: `claude-sonnet-5` (come configurato), stessa sessione
  dell'entry precedente — turno ripreso dopo un check-in schedulato, non una nuova
  sessione.
- **Non funziona / sospeso**: la riconferma di T0.2/T0.3/T0.6 su `ci-smoke` e la
  suite `full` su ENV-W restano aperte, come già in "Aperto" nella testa.
- **Prossimo passo per la sessione successiva**: verificare che `ci-smoke` sia
  verde sul push di questa entry; se sì, è il segnale che manca ancora un run
  `full` su ENV-W per T0.6/non-regressione prima di #20. Se `ci-smoke` è ancora
  rosso, il fix del PATH non è bastato — controllare l'esatto layout binari di
  `apache/kafka:4.3.1` (potrebbe essere cambiato path o nome) prima di altre
  ipotesi.

## 2026-08-27 (seconda entry ENV-W) — ENV-W (Z8, finestra esclusiva) — host di verifica

- **Obiettivo della sessione**: sfruttare la finestra di manutenzione esclusiva di 12 h
  dichiarata dall'owner per (1) eseguire la suite `full` contro l'head e chiudere la
  misura di v0.0.2, (2) verificare per misura se `granite4:32b-a9b-h` entra nella 3090.
- **Fatto**:
  - **Compito 2 completato**: misura di capacità archiviata come
    `docs/runs/20260827-1115-envw-c424928-vram32b.md`, grezzi in
    `~/NORTHSTREAM-archive/20260827-1115-envw-c424928-vram32b/`. Esito: **entra**,
    **100% GPU**, picco **19 788 MiB su 24 576**, margine 4,7 GiB, contesto 32k
    preallocato, latenza 101 s a freddo e 1-3 s a caldo.
  - **Compito 1 non eseguito**: bloccato da due difetti trovati per strada (sotto).
  - Rimosso `wap-northstream-lab_kafka_data` **dopo** aver raccolto le prove e su via
    libera esplicita della supervisione.
- **Decisioni prese**:
  - **La prima misura del 32b è stata scartata e archiviata come falsa**, non corretta in
    silenzio. Dava `100% CPU`, VRAM 9 MiB, latenza 29 s — cioè la risposta che l'ipotesi
    si aspettava («19 GB non entrano in 24») — ma era un artefatto: il container Ollama
    era stato ricreato senza passthrough GPU da un mio `docker compose up -d` privo
    dell'override `--gpu`. Il log grezzo resta in archivio come `inferenza-cpu-invalida.log`.
    *Motivo di merito*: l'artefatto confermava l'ipotesi attesa, ed è la circostanza in cui
    una misura sbagliata ha meno probabilità di essere controllata.
  - **Aggiunto al report un controllo minimo pre-misura GPU** (`DeviceRequests` non null,
    `inference compute` che dice `library=CUDA`), perché la stessa trappola non si ripeta.
  - **Le prove sul difetto Kafka sono state raccolte prima di cancellare il volume**, su
    indicazione della supervisione. Cancellare e riprovare avrebbe reso il run verde e
    fatto sparire il finding.
- **Test eseguiti**:
  - `gh workflow run ci-nightly.yml --ref release/v0.0.2 -f suite=full` → run
    **33061800518**, **fallito in 10 s** allo step `actions/checkout`:
    `EACCES: permission denied, rmdir '.../trino/catalog'`. La directory è `root:root`,
    creata da Docker (bind-mount di `./trino/catalog`, finding **P-2**) durante la
    nightly delle 08:58. **Conseguenza**: la prima nightly su un workspace pulito funziona,
    **tutte le successive falliscono**. Non rimossa: `sudo rm`/`sudo rmdir` sono negati a
    questa sessione.
  - **Difetto di migrazione su Kafka, verificato per misura** (v. "Non funziona"):
    con volume `kafka_data` preesistente il broker va in crash-loop
    (`java.nio.file.AccessDeniedException: /var/lib/kafka/data/bootstrap.checkpoint.tmp`,
    46 restart); con volume fresco è **healthy in 23 s**.
    `bitnamilegacy/kafka:3.7.1` gira `uid=1001 gid=0(root)`, `apache/kafka:4.3.1` gira
    `uid=1000(appuser) gid=1000`; le directory del volume sono `0:0` modo `775`, cioè
    scrivibili dal **gruppo root** — di cui il vecchio broker faceva parte e il nuovo no.
  - Misura 32b: v. sopra e il run report.
- **Costo della sessione**: **non misurabile** — sessione bridge, `usage` non esposto.
- **Non funziona / sospeso**:
  - **`ci-nightly` non è ripetibile sul runner self-hosted** finché `trino/catalog`
    root-owned resta nel workspace. **Decisione richiesta all'owner**: eseguire
    `sudo rmdir .../trino/catalog && sudo rmdir .../trino` (la dir è vuota), e far
    correggere la causa — la via più pulita sembra committare `trino/catalog/.gitkeep`,
    così Docker non crea la directory come root. Issue da aprire, sorella di #41/#42.
  - **v0.0.2 rompe i lab esistenti**: chi aggiorna con un volume `kafka_data` creato
    dall'immagine Bitnami trova Kafka che non parte, con un errore che non nomina né i
    permessi né il cambio d'immagine. La CI **non può accorgersene per costruzione**,
    perché parte sempre da volume inesistente. **Decisione richiesta all'owner**: nota di
    migrazione nel CHANGELOG/README, oppure controllo esplicito all'avvio. Osservazione a
    supporto della seconda via: la nota la legge chi sospetta già un problema di
    aggiornamento; chi non lo sospetta vede solo un broker che non parte.
  - **Finestra esclusiva spesa in buona parte a debuggare**, che è il rischio contro cui
    la §2.1 appena scritta mette in guardia: due difetti di infrastruttura, più ~35 minuti
    persi per un mio errore (un `docker compose up -d` senza override GPU che ha ucciso il
    pull al 92% e poi tolto la GPU a Ollama). La prova a secco prescritta dalla regola 2
    di §2.1, se fosse esistita per la nightly, avrebbe intercettato il primo dei due.
- **Prossimo passo per la sessione successiva**: sbloccare `trino/catalog` e rieseguire
  la suite `full` contro l'head — **T0.6 con modelli veri resta non misurato**, e con esso
  il progression test della release.

---

## 2026-08-27 (terza entry) — sessione cloud (nessun demone Docker) — sessione B, `claude-sonnet-5`

- **Obiettivo della sessione**: rispondere al check-in della supervisione — `ci-smoke`
  verde confermato, T0.2/T0.3 tornati PASS; la finestra esclusiva su ENV-W ha trovato
  due nuovi difetti nello scope di questa sessione, **P-11** ([#45](https://github.com/danielesalpietro/NORTHSTREAM/issues/45))
  e **P-12** ([#46](https://github.com/danielesalpietro/NORTHSTREAM/issues/46)), entrambi
  già verificati per misura dalla sessione ENV-W (v. entry precedente): non ridiagnosticati
  qui, solo implementati i fix richiesti.
- **Fatto**:
  - `git pull --rebase origin release/v0.0.2` per integrare i commit di supervisione/ENV-W
    arrivati nel frattempo (misura VRAM 32b, apertura P-11/P-12, finestra ENV-W in CLAUDE.md).
  - `trino/catalog/.gitkeep` committato (P-12, #46): la directory ora esiste in git, quindi
    Docker non la ricrea più `root:root` al primo `up` sul runner self-hosted.
  - `preflight.sh` / `preflight.ps1` estesi (P-11, #45): nuovo controllo che cerca un volume
    `kafka_data` preesistente tramite le label che compose assegna
    (`com.docker.compose.project`/`.volume`, non un nome hardcoded), e se lo trova verifica
    che sia scrivibile dall'utente `1000:1000` di `apache/kafka` con un container `busybox`
    usa-e-getta (`touch` + `rm` di un file di prova). Fallisce con `docker volume rm ...` come
    rimedio se non è scrivibile; un errore generico (docker non raggiungibile, pull fallito)
    diventa `WARN`, non un falso positivo o un `FAIL` fuorviante.
  - `CHANGELOG.md`: nuova sezione "⚠ Breaking (lab esistenti)" in testa a `[Unreleased]` che
    dichiara il cambio di UID come breaking per chi aggiorna un lab esistente, col comando di
    rimedio — richiesto esplicitamente dalla issue #45, non solo la riga tecnica sotto Added.
- **Decisioni prese**:
  - **Rilevamento del volume via label compose, non via nome hardcoded**
    (`wap-northstream-lab_kafka_data`): le label (`com.docker.compose.project=...`,
    `com.docker.compose.volume=kafka_data`) sono ciò che compose stesso assegna e sono
    documentate come il modo robusto di identificare i propri oggetti; un nome hardcoded si
    romperebbe silenziosamente se lo schema di naming di compose cambiasse in una versione
    futura. *Alternativa scartata*: `docker volume ls --filter name=kafka_data` — più fragile,
    matcherebbe anche un volume di un altro progetto con lo stesso suffisso.
  - **Test di scrivibilità con `busybox --user 1000:1000`, non con l'immagine reale
    `apache/kafka`**: replica esattamente il meccanismo del difetto (l'utente 1000:1000 non
    scrivendo il volume) senza il costo di tirare giù l'immagine Kafka intera solo per un
    controllo di permessi. *Alternativa scartata*: ispezionare `stat` dei file nel volume e
    confrontare owner/gid con valori hardcoded (1001/0) — funziona solo se quei valori esatti
    sono quelli osservati; il test comportamentale (può scrivere o no l'utente 1000:1000) resta
    valido anche se i numeri storici cambiassero.
  - **Errore generico → `WARN`, non `FAIL` né `OK` silenzioso**: distinguere "il volume non è
    scrivibile" da "non sono riuscito a verificare" (docker non raggiungibile, pull di
    `busybox` fallito per assenza di rete) evita sia un falso positivo bloccante sia un
    falso negativo che nasconde un problema reale dietro un errore di infrastruttura.
  - **Sezione "⚠ Breaking" separata nel CHANGELOG**, non solo una riga sotto "Changed": la
    issue #45 la richiede esplicitamente come complemento del controllo automatico, non come
    sostituto — chi legge il CHANGELOG prima di aggiornare deve vederla senza dover leggere
    ogni riga tecnica.
- **Test eseguiti**:
  - `bash -n` su `preflight.sh` → sintassi valida (`preflight.ps1` non verificabile, nessun
    PowerShell in questa sessione).
  - **Simulazione della logica di branching con un `docker` finto** (funzione bash che
    intercetta le sotto-chiamate `info`/`volume`/`run`): verificate le quattro strade —
    nessun volume esistente → `OK`; volume scrivibile → `OK`; volume non scrivibile
    (`Permission denied` nello stderr simulato) → `FAIL` col rimedio; errore generico →
    `WARN`. Tutte e quattro si comportano come atteso.
  - `./preflight.sh` reale in questa sandbox (nessun demone Docker): la nuova sezione P-11
    stampa correttamente `WARN docker CLI present but daemon not reachable`, coerente col
    ramo "docker non raggiungibile" della logica.
  - `docker compose -f ... config -q` su tutte le combinazioni → validano ancora, inclusa la
    presenza della nuova `trino/catalog/.gitkeep` (bind-mount ora punta a una directory che
    esiste davvero in git, non solo creata da Docker).
  - `bash bench/t0/run.sh --suite static` → `T0.1 PASS, T0.12 PASS, T-REPRO PASS`, nessuna
    regressione.
  - `yamllint`/`ruff` puliti (invariato).
  - **Non verificabile qui, per costruzione (dichiarato esplicitamente dalla issue)**: il
    comportamento reale del controllo P-11 richiede un volume `kafka_data` creato
    deliberatamente con la vecchia proprietà, e il comportamento reale di P-12 richiede due
    nightly consecutive sullo stesso workspace — **entrambi spettano a ENV-W**, come chiesto
    dalla supervisione nel check-in.
- **Costo della sessione**: `claude-sonnet-5` (come configurato), stessa sessione delle
  entry precedenti — turno ripreso dopo un check-in schedulato.
- **Non funziona / sospeso**: la verifica reale di P-11 (volume a proprietà vecchia) e di
  P-12 (due nightly consecutive, bloccata finché l'owner non sblocca con `sudo` il workspace
  ENV-W già compromesso) restano aperte — v. "Aperto" in testa.
- **Prossimo passo per la sessione successiva**: dopo il push, verificare `ci-static`/
  `ci-smoke` (dovrebbero restare verdi: nessuna modifica comportamentale allo stack, solo un
  nuovo controllo preflight e una directory vuota) e poi passare la palla a ENV-W per le due
  verifiche reali di P-11/P-12. Se entrambe confermano i fix, l'ultimo passo della fase è
  #20.
- **Decisioni richieste all'owner**: nessuna nuova oltre a quella già in sospeso da
  P-12/#46 — sbloccare `trino/catalog` root-owned sul workspace ENV-W (`sudo rmdir`), che
  nessuna sessione agente può fare da sola.
