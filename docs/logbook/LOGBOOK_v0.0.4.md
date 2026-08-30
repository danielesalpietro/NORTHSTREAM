# LOGBOOK — Fase 3: Agent robusto (v0.0.4)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aperta il 2026-08-30, nessuna entry ancora

**Dove siamo**: Fase 2 chiusa col tag `v0.0.3` → `442bac1`, `develop` allineato
col merge `f585e38`. Fase 3 non ancora iniziata: questa testa è il punto di
partenza, non un resoconto.

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

**Prossimo passo**: decidere con l'owner il modello e la suddivisione in sessioni
per la fase (v. `CLAUDE.md` §7), poi aprire A-3.
