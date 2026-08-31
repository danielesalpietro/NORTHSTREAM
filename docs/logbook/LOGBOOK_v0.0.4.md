# LOGBOOK — Fase 3: Agent robusto (v0.0.4)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata il 2026-08-31, dopo la chiusura di A-3

**Dove siamo**: Fase 2 chiusa col tag `v0.0.3` → `442bac1`, `develop` allineato
col merge `f585e38`. **A-3 è chiuso** (31/08, ENV-W): l'id di un punto Qdrant è
`uuid5(NAMESPACE, "topic:partition:offset")` e non più un contatore in RAM.
**T0.8 XFAIL → PASS**, falsificato rimettendo il contatore, suite piena **10 PASS
/ 2 XPASS / 1 XFAIL** senza regressioni. Prova diretta su tutta la collection
attraverso un riavvio: **0 punti preesistenti cambiati, 0 spariti**, +10 nuovi
tutti con id UUID. Report:
[`20260831-1209-envw-db4c22a-a3.md`](../runs/20260831-1209-envw-db4c22a-a3.md).

**Due cose che la prossima sessione deve sapere e non riscoprire.** La
**migrazione è l'opzione (1)**, «non fare nulla»: i 32 841 punti con id intero
restano, quindi **la corruzione storica è nel corpus, congelata** — la
ricreazione della collection (opzione 2) si decide in A-2, che tocca lo stesso
punto. E la DoD «nessun punto con id basso porta un evento più recente di uno con
id alto» **non è applicabile alla lettera**: i legacy conservano per sempre
l'inversione già prodotta, e fra UUID «basso» e «alto» non significano nulla. La
forma che misura la stessa cosa, ed è quella eseguita, è *nessun punto
preesistente cambia payload attraverso un riavvio*.

**Scope della fase** (`docs/piano_ricovero.md` §6, riga v0.0.4): rendere l'agent
robusto. Issue di fase
[#6](https://github.com/danielesalpietro/NORTHSTREAM/issues/6). È **la fase più
costosa del piano** — ridisegno del retrieval, suite EVAL e soak — e tocca
`stream-agent/app.py`, cioè il codice più delicato del progetto.

| Finding | Contenuto | Progression test |
|---|---|---|
| **A-3** | Point-id deterministici da `(topic, partition, offset)` al posto del contatore in RAM | T0.8 |
| **A-2** | Timestamp nel payload + filtro recency in query | T0.9 |
| **A-1** | Rimozione del boost keyword su `KNOWN_SITES`, sostituito da `Filter` su payload | T0.10 |
| **A-5** | `/health` che verifica davvero Kafka, Qdrant, Ollama e il thread consumer | T0.11 |
| — | `group_id` Kafka, logging strutturato, `query_points` al posto della API deprecata | — |

**A-3 ha priorità, e non per l'ordine alfabetico.** La Fase 2 l'ha osservata in
produzione e riclassificata: **non è crescita illimitata, è distruzione
silenziosa di dati**. Il punto `id=3` portava un evento delle 13:41:55Z mentre
`id=27413` ne portava ancora uno delle 12:31Z — il contatore riparte da zero a
ogni riavvio dell'agent e risale sopra il corpus esistente. Finché A-3 è aperto:

- i check **(a) e (c)** del soak falliscono per costruzione, quindi **T-SOAK-24h
  non si prenota** (spenderebbe 24 ore per rimisurare un guasto noto);
- il corpus su cui il RAG risponde non è ricostruibile, quindi **nessuna misura
  EVAL fatta prima della chiusura di A-3 è confrontabile** con quelle dopo.

**Ereditato dalla Fase 2, da non riscoprire**
- Il retrieval attuale contiene il boost keyword su `KNOWN_SITES` (A-1): va
  **rimosso** in questa fase, non "sistemato" per altre vie.
- T0.10 **non è robusto** ([#40](https://github.com/danielesalpietro/NORTHSTREAM/issues/40)):
  colto in flagrante il 28/08 con XPASS alle 12:40Z e XFAIL alle 12:47Z **sullo
  stesso stack**. Quella coppia è il caso di prova per irrobustirlo, non un
  aneddoto. Va sistemato **prima** di usarlo come progression test di A-1.
- L'XPASS di T0.9 è stato lasciato intatto: due letture concordi non bastano a
  dichiarare A-2 chiuso.

**Regole della Fase 2 che valgono qui**
1. **Un test nuovo va falsificato prima di essere creduto**: si rompe di
   proposito la condizione che asserisce e si verifica che diventi rosso.
2. **Un confronto prima/dopo varia una cosa sola** (`piano_ricovero.md` §4.3.2).
3. **Una soglia scritta a tavolino è un'ipotesi**, non un fatto: tre soglie di
   §4.3.1 sono state corrette in due giorni, tutte perché applicate alla lettera
   invece che aggirate.
4. **Un run lungo si archivia da solo**, con checksum, come ultimo passo.

**Aperto all'ingresso in fase**: #23 (ENV-L, tier misurati e `preflight.ps1` su
Windows) · #44 da riverificare su due GPU · #47 (warm-up gate) · `RUN_NIGHTLY`
spenta · T-SOAK-24h in attesa di A-3.

**Prossimo passo**: **#40**, irrobustire T0.10 — è infrastruttura di test, quindi
anticipabile, e **sblocca A-1**; T0.10 ha dato XPASS anche il 31/08, terzo esito
discordante. Poi **A-2**, dove va decisa anche l'opzione (2) sulla ricreazione
della collection.

---

## 2026-08-31 — ENV-W (Z8) — sessione operativa A-3

- **Obiettivo della sessione**: chiudere **A-3** — point-id deterministici da
  `(topic, partition, offset)` in `stream-agent/app.py` — e far flippare **T0.8**.

- **Fatto** (commit in coda a questa entry):
  - `stream-agent/app.py`: via il contatore in RAM `_point_id`/`next_point_id()`, al suo
    posto `point_id(topic, partition, offset)` = `uuid5(POINT_ID_NAMESPACE, "t:p:o")`, con
    il namespace **fissato come costante** e la derivazione scritta nel commento.
  - `bench/t0/tests/t0.08_qdrant_restart_ids.sh`: l'asserzione ora copre il contratto che
    l'intestazione prometteva già.
  - `bench/t0/expected/current.json`: `T0.8: PASS`, `T0.8` tolto da `flips`, `target`
    invariato.
  - Report: [`docs/runs/20260831-1209-envw-db4c22a-a3.md`](../runs/20260831-1209-envw-db4c22a-a3.md);
    grezzi in `~/NORTHSTREAM-archive/20260831-1209-envw-db4c22a-a3/`, 35 file con
    `SHA256SUMS` verificato.

- **Decisioni prese**:
  1. **`uuid5`, non un intero da SHA-256.** L'handoff ammetteva entrambe. Ho scelto l'UUID
     perché non richiede di scegliere quanti byte troncare, e ogni troncamento è una
     decisione sulla probabilità di collisione che nessuno rivede mai. L'alternativa
     scartata resta valida se un giorno servisse un id numerico.
     Prova che `hash()` era la trappola giusta da evitare, misurata su tre processi con
     `PYTHONHASHSEED` diverso: `uuid5` identico tutte e tre le volte, `hash()` diverso
     tutte e tre.
  2. **Migrazione: opzione (1), «non fare nulla».** I 32 841 punti con id intero restano.
     Distruggere dati per chiudere un finding di distruzione dati sarebbe una risposta
     bizzarra, e la ricreazione della collection (opzione 2) tocca lo stesso punto di A-2:
     si decide lì, col filtro recency davanti. **Conseguenza agli atti: la corruzione
     storica resta nel corpus, congelata.**
  3. **La definition of done è stata eseguita in una forma diversa da come è scritta, e il
     perché è la notizia** — v. sotto.

- **Test eseguiti** (Docker reale, 19 container, `release/v0.0.4` @ `db4c22a`):
  - T0.8 sul codice **vecchio**, con l'asserzione nuova → **XFAIL/KO in 33 s**:
    «10 of 200 sampled points changed payload across the restart».
  - T0.8 col **fix** → **XPASS/OK**: «count grew by 12 and all 200 sampled points kept
    their payload».
  - T0.8 con la **falsificazione** (contatore rimesso apposta, rebuild vero) → **XFAIL/KO**,
    stesso messaggio del primo caso. Il test può ancora fallire.
  - Suite `full` dopo il ripristino → **10 PASS / 2 XPASS / 1 XFAIL**, `RESULT: OK (no
    regression)`. I 9 PASS precedenti reggono, T0.8 è il decimo.
  - Prova diretta su **tutta** la collection attraverso un riavvio: 32 984 → 32 994 punti,
    **0 preesistenti cambiati, 0 spariti**, 10 nuovi tutti con id UUID.

- **L'assurdo, riferito invece che aggirato**: la DoD chiede «dopo un riavvio, nessun punto
  con id basso porta un evento più recente di uno con id alto». Con la scelta (1) quella
  condizione **non può passare** — non perché il difetto sia aperto, ma perché i punti
  legacy conservano per sempre l'inversione già prodotta: sono cicatrici, non ferite. E sui
  punti nuovi è **inesprimibile**, perché fra UUID «basso» e «alto» non significano nulla.
  Un criterio che diventa insensato proprio quando il fix funziona non può essere il
  criterio. La forma che misura la stessa cosa — *nessun punto preesistente cambia payload
  attraverso un riavvio* — vale per legacy e nuovi insieme, ed è quella eseguita.

- **Costo della sessione**: **non misurabile** (sessione bridge).

- **Non funziona / sospeso**:
  - **T0.10 di nuovo XPASS** (7 s): terzo esito discordante sullo stesso test.
    [#40](https://github.com/danielesalpietro/NORTHSTREAM/issues/40) va chiuso prima di
    usarlo come gate di A-1. Non toccato: fuori scope.
  - **T0.9 XPASS** (324 s), coerente con la lettura precedente. Lasciato intatto.
  - **Ollama gira ancora 100% CPU** dal riavvio del 30/08: non invalida questo run (il fix
    è sull'id, non sul vettore) ma ogni tempo qui è un tempo su CPU.
  - **Limite residuo dichiarato**: l'id è unico finché il topic non viene ricreato. Se
    Kafka perde il volume, gli offset ripartono e la stessa terna indicherebbe un evento
    diverso. È ciò che farebbe un `down -v`, già vietato per P-10/#42.
  - **Non ero in `tmux`**: detto all'owner prima di iniziare.

- **Prossimo passo per la sessione successiva**: **#40** (irrobustire T0.10 — è
  infrastruttura di test, anticipabile, e sblocca A-1), poi **A-2**, dove va anche decisa
  l'opzione (2) sulla ricreazione della collection.

- **Decisioni richieste all'owner**:
  1. La DoD «id basso / id alto» va **riscritta** nella forma eseguita, altrimenti resterà
     impossibile da soddisfare per chiunque la applichi alla lettera.
  2. Confermare che questa sessione può committare codice: `CLAUDE.md` §2 dice di no, il
     briefing di fase dice di sì. Ho seguito il briefing e l'ho dichiarato.
