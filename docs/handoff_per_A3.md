# Handoff — A-3: point-id deterministici (Fase 3, v0.0.4)

> **Per la sessione che riceve questo documento.** È un briefing completo: tutto ciò
> che serve per lavorare sta qui o nei file citati, e non devi ricostruirlo da solo.
> Resta comunque obbligatorio l'onboarding di `CLAUDE.md` §1 — questo documento lo
> integra, non lo sostituisce.

| | |
|---|---|
| **Branch** | `release/v0.0.4` (già aperto da `develop` @ `f585e38`) |
| **Modello** | `claude-opus-5` — codice delicato con gate di qualità da interpretare (`CLAUDE.md` §7) |
| **Ambiente** | serve Docker reale: ENV-W (Z8) o ENV-L. Avviare la sessione con `bench/env-w/start-session.sh` |
| **Scope** | **solo A-3.** Non A-2, non A-1, non A-5 |
| **Progression test** | **T0.8**, oggi XFAIL |
| **Issue di fase** | [#6](https://github.com/danielesalpietro/NORTHSTREAM/issues/6) |

---

## 1. Che cosa è A-3, e perché ha priorità su tutto il resto della fase

La review lo classificava «crescita illimitata dello storage». **È sbagliato, ed è
peggio.** Il 28/08, durante il soak #2, è stato osservato in produzione:

> Il punto `id=3` porta un evento delle **13:41:55Z** mentre `id=27413` ne porta
> ancora uno delle **12:31Z**.

Il contatore riparte da zero a ogni riavvio dell'agent, il volume Qdrant è
persistente, quindi l'agent **sovrascrive il corpus esistente**. Non è igiene dello
storage: è **distruzione silenziosa di dati**, e si presenta con la faccia più
rassicurante possibile — un conteggio dei punti perfettamente piatto.

Tre conseguenze che spiegano perché viene prima di tutto:

1. I check **(a)** e **(c)** del soak falliscono **per costruzione**: (a) legge la
   serie piatta come «crescita limitata» proprio mentre i dati vengono distrutti.
   Finché A-3 è aperto, **T-SOAK-24h non si prenota** — spenderebbe 24 ore per
   rimisurare un guasto già documentato.
2. Il corpus su cui il RAG risponde **non è ricostruibile**, quindi **nessuna misura
   EVAL presa oggi sarebbe confrontabile** con una presa dopo. Tutta la Fase 3
   dipende da questo.
3. A-1 (boost keyword) è già stato **ridimensionato** da A-3 una volta: T0.10 dava
   XPASS perché la collection era minuscola *a causa* di A-3. Un difetto ne
   mascherava un altro.

---

## 2. Il codice, esattamente com'è adesso

`stream-agent/app.py`, tre punti:

```python
# righe 48-49
_point_id_lock = threading.Lock()
_point_id = 0

# righe 87-91
def next_point_id() -> int:
    global _point_id
    with _point_id_lock:
        _point_id += 1
        return _point_id

# righe 130-139, dentro consume_loop()
qdrant.upsert(
    collection_name=COLLECTION,
    points=[
        qmodels.PointStruct(
            id=next_point_id(),
            vector=vector,
            payload={"text": text, "topic": msg.topic},
        )
    ],
)
```

Il consumer (righe 98-104) gira **senza `group_id`** e con
`auto_offset_reset="latest"`.

---

## 3. Il fix, e la trappola che ci sta dentro

**Obiettivo**: l'id di un punto deve essere una funzione deterministica di
`(topic, partition, offset)`. Lo stesso evento riletto produce lo stesso id, quindi
un `upsert` ripetuto è idempotente e un replay diventa sicuro invece che distruttivo.

`msg.partition` e `msg.offset` sono già disponibili sull'oggetto messaggio di
`kafka-python`, accanto a `msg.topic` che il codice usa già.

### La trappola, e va detta prima che qualcuno ci cada

Qdrant accetta come id **solo un intero senza segno o un UUID**. `(topic, partition,
offset)` non è né l'uno né l'altro, quindi serve una mappatura — ed è lì che si
sbaglia:

- **`hash()` di Python è salato per processo.** Da Python 3.3, `PYTHONHASHSEED` è
  casuale a ogni avvio: `hash("orders-0-42")` dà un valore diverso a ogni riavvio
  del container. Usarlo riprodurrebbe **esattamente il bug che stiamo chiudendo**,
  con un costume nuovo e molto più difficile da vedere. Non usarlo.
- **Un troncamento a 64 bit di uno hash generico** introduce collisioni silenziose:
  due eventi diversi che finiscono sullo stesso id, cioè di nuovo sovrascrittura.
- La via pulita è **`uuid.uuid5(NAMESPACE, f"{topic}:{partition}:{offset}")`** —
  deterministico per definizione, stabile fra processi e versioni, e accettato da
  Qdrant come id. Il namespace va fissato come costante nel modulo, non generato.

**Alternativa accettabile** se preferisci un intero: una funzione crittografica
stabile (es. i primi 8 byte di uno SHA-256 della stessa stringa) — deterministica
fra processi, a differenza di `hash()`. Se la scegli, **dichiara nel logbook perché**
e verifica il comportamento su una collection già popolata.

**Da non fare**: `uuid4()`. È deterministico quanto un dado, perde l'idempotenza, e
la review lo elenca come alternativa banale proprio per scartarla.

### Il collo di bottiglia della migrazione, da decidere e dichiarare

I punti già in `qdrant_data` hanno id vecchi (interi 1..N) e **non sono più
raggiungibili** con lo schema nuovo. Sono anche, in parte, già corrotti da A-3. Tre
strade, e la scelta va scritta nel logbook con il perché:

1. **Non fare nulla**: i vecchi punti restano, i nuovi si aggiungono accanto. Il
   corpus resta sporco ma il conteggio cresce, e T0.8 passa.
2. **Ricreare la collection all'avvio**, coerentemente con `auto_offset_reset="latest"`
   — è ciò che la review suggerisce come alternativa in A-2.
3. **Migrazione one-shot**: non ne vale il costo per un lab.

Non decido io: è una scelta di progetto e la fa chi implementa, ma **va dichiarata**.
La mia inclinazione è la (1) per il fix, con la (2) valutata quando si chiude A-2,
che tocca lo stesso punto.

---

## 4. Il progression test, e ciò che non copre

`bench/t0/tests/t0.08_qdrant_restart_ids.sh`. Prende il conteggio, riavvia l'agent,
attende ~10 eventi nuovi, e **verifica che il conteggio sia cresciuto di almeno 8**.

Oggi XFAIL: col contatore da zero il conteggio resta piatto finché il contatore non
supera il massimo precedente, quindi la crescita è 0.

**Due cose da sapere su questo test, verificate leggendolo:**

- L'intestazione promette «none of the pre-existing ids is reused», ma **l'unica
  asserzione è sulla crescita**. Il conteggio `reused` viene osservato e mai
  asserito — e non discriminerebbe comunque, perché un id sovrascritto resta
  presente esattamente come uno preservato. La crescita è il segnale che discrimina,
  e funziona; ma il commento promette più di quanto il test verifichi. **Allinealo**:
  o l'asserzione copre il contratto, o il commento dice ciò che il test fa davvero.
  Questo progetto ha già speso una giornata su T0.7 per la stessa ragione.
- `sample_ids` scorre **200 punti**. Con id UUID il campione resta valido, ma
  verificalo invece di darlo per scontato.

### Falsificalo prima di crederci

Regola non negoziabile di `CLAUDE.md` §5, terzo caso: **un test mai visto fallire non
è un test, è una decorazione.** Quando T0.8 diventa verde, rompi di proposito la
condizione — per esempio rimettendo `next_point_id()` in una copia — e verifica che
torni rosso. Trascrivi entrambi gli esiti nel report.

---

## 5. Definition of done

1. **T0.8 flippa XFAIL → PASS** su Docker reale, e la falsificazione mostra che può
   ancora fallire.
2. **Nessuna regressione**: i 9 PASS dell'ultimo run archiviato restano PASS.
   `bench/t0/expected/current.json` aggiornato (`T0.8: PASS`, `target` invariato).
3. **La prova diretta del difetto è sparita**: dopo un riavvio, nessun punto con id
   basso porta un evento più recente di uno con id alto. È il controllo che ha
   scoperto A-3, e deve essere quello che lo dichiara chiuso — non il solo conteggio.
4. Run archiviato secondo la convenzione `RUN_ID` (`docs/runs/` + archivio locale con
   checksum), riga di `CHANGELOG.md` che cita **A-3** e **O5.1**, entry di logbook in
   `docs/logbook/LOGBOOK_v0.0.4.md` **e aggiornamento della testa**.
5. Push su `release/v0.0.4`.

---

## 6. Fuori scope, e perché

- **A-2, A-1, A-5**: stessa fase, sessioni diverse. A-1 in particolare **non può
  partire** finché #40 non ha irrobustito T0.10, che altrimenti non può fare da gate.
- **T-SOAK-24h**: si prenota *dopo* questo fix, non prima.
- **Il boost keyword su `KNOWN_SITES`**: si rimuove in A-1, non «si sistema» per
  altre vie passando di lì.
- **Compose e tetti di memoria**: chiusi con v0.0.3. Se tocchi un `mem_limit`, T0.13
  pretende che il commento citi la misura.

---

## 7. Che cosa si può anticipare, se resta tempo morto

L'owner ha chiesto esplicitamente di anticipare ciò che copre i tempi morti.
`CLAUDE.md` §3.2 lo consente per **infrastruttura di test** ed **esecuzione di run**,
non per modifiche al comportamento del sistema. Quindi, in ordine di utilità:

1. **[#40](https://github.com/danielesalpietro/NORTHSTREAM/issues/40) — irrobustire
   T0.10.** È infrastruttura di test, è anticipabile, e **sblocca A-1**, che è il
   prossimo lavoro della fase. Il caso di prova esiste già ed è documentato: XPASS
   alle 12:40Z e XFAIL alle 12:47Z **sullo stesso stack**, il 28/08.
2. **[#44](https://github.com/danielesalpietro/NORTHSTREAM/issues/44) — riverifica su
   due GPU.** La correzione per-device (`e5588c9`) non è mai stata vista girare, e la
   Z8 ha due schede dal 29/08. È mezz'ora e chiude l'ultimo residuo della Fase 2.
   Serve il protocollo a tre stati, per device.
3. **Scheletro della suite EVAL** (O7.1): question set e asserzioni deterministiche
   sono codice di test, quindi anticipabili. **Ma non eseguire misure EVAL prima che
   A-3 sia chiuso**: non sarebbero confrontabili con quelle dopo, ed è il motivo per
   cui A-3 viene prima.

**Non anticipare** il generatore di sequenze controllate (G-3): tocca il
comportamento del sistema, ed è scope di v0.0.6.

---

## 8. Regole di questo progetto che valgono qui più che altrove

- **Nessun «fatto» senza test.** Un fix è tale quando l'XFAIL designato flippa e
  nessun PASS regredisce.
- **Una misura che conferma l'ipotesi attesa va controllata due volte.** È la misura
  con meno probabilità di essere verificata, ed è quella che ha depistato tre volte
  questo progetto.
- **Un campo derivato deve distinguere «falso» da «non l'ho potuto sapere».**
- **Le anomalie si scrivono quando si incontrano**, non alla chiusura: bastano tre
  righe nel logbook. Ciò che non finisce in un commit non esiste.
- **Se una regola di questo documento produce un assurdo applicandola alla lettera,
  l'assurdo è la notizia**: dillo invece di aggirarla. Tre soglie del piano sono state
  corrette in due giorni esattamente così.

---

## 9. Riferimenti rapidi

- Agent: `stream-agent/app.py` (porta 8500) · collection Qdrant: `stream_events`
- Test: `bench/t0/run.sh --suite core|full` · attese: `bench/t0/expected/current.json`
- Stack: `docker compose -f docker-compose-northstream-ai.yml up -d` (solo `core`;
  aggiungi `--profile lakehouse --profile governance` per i 19 container)
- Addon: `./start-addon.sh` (`--gpu` per passthrough) · connettore: `./register-connector.sh`
- **LLD**: `docs/lld/northstream-lld.html` — disegna gli interni dell'agent, boost
  keyword compreso. Va riletto quando cambia il comportamento.
- Memoria: `docs/logbook/LOGBOOK_v0.0.4.md` (testa + ultima entry) ·
  `docs/logbook/SINTESI_fasi_chiuse.md` (fasi 0-2 distillate)
