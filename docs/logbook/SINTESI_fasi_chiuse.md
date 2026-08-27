# Sintesi delle fasi chiuse — NORTHSTREAM

Memoria distillata delle fasi già concluse, secondo `CLAUDE.md` §8: una pagina per
fase, mai di più. **Si legge in onboarding al posto dei logbook integrali**, che
restano in `docs/logbook/archive/` e si aprono solo per ricostruire un dettaglio
che questa sintesi non copre.

Regola di compressione: decisioni col loro perché e le alternative scartate, numeri
misurati, item aperti e lezioni che hanno generato una regola **non si comprimono
mai**. Tutto il resto sì.

---

## ESITO FASE 0 — chiusa il 2026-08-26 con il tag `v0.0.1` → `d3053be`

**Esito**: fase chiusa. Tag `v0.0.0-baseline` → `5eb456a` e tag `v0.0.1` → `d3053be`
pubblicati; `develop` allineato col merge `60269f7`. Tutte e sette le sub-issue
(#9–#15) chiuse. Consegnato: harness `bench/t0/` (12 test), tre workflow CI con
`ci-static` e `ci-smoke` verdi, runner self-hosted `z8-env-w` registrato e attivo,
README allineato al sistema reale (T0.12 flippato), e il **run T0 di riferimento**
contro il tag baseline con modelli reali — il metro di ogni release successiva.

**Che cosa rilascia v0.0.1**: la capacità di *misurare* il progetto e la verità
documentale. Il runtime di stack e agent è identico alla baseline: v0.0.1 non
ripara il sistema, lo rende osservabile e smette di raccontarlo male.

**Decisioni prese, con il perché**
- **Storyline README accorciata, non costruita**: i layer non collegati (Flink,
  Apicurio, MinIO, Trino, OpenMetadata) sono dichiarati tali invece di
  implementarli. Costruirli erano settimane per una pipeline vista tre minuti in
  demo; un diagramma con frecce inventate è un rischio reputazionale.
- **Niente PR flow, CI con smoke test al suo posto**: a bus factor 1 la review di
  sé stessi è cerimonia; i difetti reali (P-1, P-2) non si vedono in un diff, si
  vedono eseguendo. PR flow al secondo contributor.
- **Boost keyword su `KNOWN_SITES` resta fino a v0.0.4**, solo dichiarato nel
  demo-script: rimuoverlo prima romperebbe la demo senza il sostituto pronto.
- **Scenografia congelata** fino a dopo v0.1.0-beta1.
- **Issue #1 (Norimberga/MoE)**: decisione rimandata ai numeri della matrice EVAL
  (Fase 5) — la premessa dell'issue era imprecisa, il tier Optimal è già MoE.
- **I tag di release sono un'azione locale**: le sessioni cloud hanno il push dei
  tag rifiutato dal proxy git (HTTP 403, verificato).
- **Le sessioni bridge (CLI locale) si raggiungono solo** via `create_trigger`
  con `persistent_session_id` + `fire_trigger`; non espongono `usage`.
- **P-5 (tier RAM) non è verificabile su ENV-W**: con 256 GB fisici le JVM
  auto-dimensionano l'heap e i pesi dei modelli stanno in VRAM. Serve ENV-L o
  `mem_limit` espliciti (v0.0.3, T-PROF).
- **Le attese di `expected/baseline.json` non si piegano ai risultati**: l'XPASS
  di T0.10 non è stato promosso a PASS, perché avrebbe cristallizzato nel metro
  di riferimento una proprietà che il run non dimostra.
- **`NS_RECENCY_SECONDS` = 300 di default** e tetto per-test derivato dai
  parametri del test: un test che coi soli default non può finire è un test che
  non flipperà mai da solo.
- **`RUN_NIGHTLY` si imposta separatamente dalla registrazione del runner, e di
  proposito** (9ª entry): la variabile *è* l'interruttore della nightly, non un
  dettaglio di configurazione. `ci-nightly` ha `schedule: cron "30 2 * * *"` e il
  gate `if: vars.RUN_NIGHTLY == 'true'`, quindi impostarla accende la nightly
  della notte stessa; e il suo ultimo step è `docker compose ... down -v`, che
  **cancella `ollama_data`**. Registrare il runner e accendere la nightly sono
  due decisioni distinte e vanno prese distintamente.

**Numeri misurati**
- **Run di riferimento** `20260826-2053-envw-5eb456a` (ENV-W, modelli reali,
  suite `full` contro il tag): **5 PASS + 6 XFAIL + 1 XPASS**, `RESULT: OK`. È il
  metro di ogni release successiva.
- **P-1, P-2, A-2, A-3, A-5 confermati per misura**; **D-1/D-2/P-1 doc** chiusi da
  T0.12 (XFAIL → PASS, il progression test dichiarato per v0.0.1).
- **A-8 scoperto per misura**: agent cieco ai topic CDC per **4 min 46 s**
  seguendo l'ordine documentato. Non era nella review. Issue #39, fix in v0.0.4.
- **XPASS di T0.10 spiegato**: con 61 punti in collection e `top_k=5` il match
  letterale entra comunque; il test dipende dalla dimensione del corpus → issue
  #40, da rafforzare prima che il suo esito significhi qualcosa.
- **P-9 confermato su clone pulito** (9ª entry): i tre script del Quick Start sono
  `100644` in git e `./start-addon.sh --help` termina con **exit 126**,
  `Permission denied`. Non è un file mancante (sarebbe 127): manca il bit di
  esecuzione. È il primo comando del Quick Start.
- RSS totale dello stack full su ENV-W: **9,52 GiB** (non è una verifica di P-5).
- Costo del processo: ~81,6 M token letti da cache contro ~310 mila generati
  (263:1). Il costo è rilettura, non generazione.

**Aperto**
**Consegnato alla Fase 1 (v0.0.2)**
- **#41 — P-9**: script del Quick Start non eseguibili su clone pulito (exit 126).
- **#42 — P-10**: teardown di `ci-nightly` con `down -v` che cancella `ollama_data`.
  **Da chiudere prima di impostare `RUN_NIGHTLY`**: finché la variabile è spenta il
  gate tiene il workflow dormiente e il runner registrato è innocuo.
- Progression test dichiarato di v0.0.2: **T0.6** (doppio listener Kafka).

**Ancora aperto oltre la Fase 1**
- **#40** — T0.10 non è un test robusto di ciò che dichiara di misurare (Fase 3).
- **P-5** verificabile solo su ENV-L o con `mem_limit` (Fase 2, T-PROF).
- **RP-0** (probe DinD su RunPod) non eseguito — e reso **opzionale**: tutta la
  matrice EVAL entra nei 24 GB della 3090, quindi gira su ENV-W via `ci-nightly`.

**Risolto rispetto alla testa precedente**
- **ENV-W può di nuovo pubblicare su GitHub**: `gh auth status` → autenticato come
  `danielesalpietro` (scope `repo`), `ssh -T git@github.com` → autenticazione OK,
  `git push --dry-run` → exit 0. Il blocco che rendeva ENV-W «un ambiente che
  misura ma non pubblica» non c'è più.

**Correzioni alla review prodotte dalla misura** — la fase ha smentito o
ridimensionato quattro affermazioni del documento che l'ha aperta: **A-8** non è
costante (~5 min) ma uniforme in [0, 5 min]; **P-6** non è riproducibile su host
preconfigurato; **A-1** resta vero nel meccanismo ma la sua premessa sul ranking
non regge su corpus piccolo — e la collection era piccola *a causa di A-3*, un
difetto che ne mascherava un altro; **P-5** stimava 20-24 GB contro 9,52 GiB
misurati. È il funzionamento previsto del metodo: il report comanda sul documento.

