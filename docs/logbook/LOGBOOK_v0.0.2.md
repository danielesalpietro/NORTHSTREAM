# LOGBOOK — Fase 1: Raggiungibilità e riproducibilità (v0.0.2)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata al 2026-08-26, apertura fase

**Dove siamo**: fase appena aperta, nessuna sessione operativa ancora attiva.
Base: tag `v0.0.1` → `d3053be`, `develop` allineato. Lo stack sulla Z8 è spento
con i volumi conservati; il runner self-hosted `z8-env-w` è registrato e attivo,
ma `ci-nightly` è dormiente perché `RUN_NIGHTLY` non è impostata — e non va
impostata finché #42 non è chiuso.

**Scope della fase** (`docs/piano_ricovero.md` §6, riga v0.0.2 — obiettivo O3):
rendere lo stack raggiungibile dall'host come documentato e riproducibile nel
tempo. Issue di fase [#4](https://github.com/danielesalpietro/NORTHSTREAM/issues/4).

| Sub-issue | Contenuto | Finding |
|---|---|---|
| [#16](https://github.com/danielesalpietro/NORTHSTREAM/issues/16) | Doppio listener Kafka (interno `kafka:9092`, esterno `localhost:29092`) | P-1 |
| [#17](https://github.com/danielesalpietro/NORTHSTREAM/issues/17) | Pin immagini a versione+digest; sostituzione di `bitnamilegacy/kafka` | P-3, P-4 |
| [#18](https://github.com/danielesalpietro/NORTHSTREAM/issues/18) | Binding porte su `127.0.0.1` | P-7 |
| [#19](https://github.com/danielesalpietro/NORTHSTREAM/issues/19) | Script preflight (`vm.max_map_count`, RAM, GPU) | P-6 |
| [#41](https://github.com/danielesalpietro/NORTHSTREAM/issues/41) | Bit di esecuzione sui tre script del Quick Start | **P-9** |
| [#42](https://github.com/danielesalpietro/NORTHSTREAM/issues/42) | Teardown di `ci-nightly` che cancella `ollama_data` | **P-10** |
| [#20](https://github.com/danielesalpietro/NORTHSTREAM/issues/20) | Release v0.0.2: gate, CHANGELOG, tag | — |

**Progression test dichiarati**: **T0.6** (client Kafka dall'host ottiene metadata
utilizzabili) XFAIL → PASS; nuovo **T-REPRO** (due `docker compose pull` a distanza
risolvono gli stessi digest); preflight che fallisce con messaggio chiaro su host
non conforme; per #42, una nightly reale dopo cui `ollama_data` esiste ancora.

**Gate di chiusura**: tutti i PASS di v0.0.1 restano PASS — in particolare i cinque
del run di riferimento — CI verde, e nessun nuovo XFAIL non dichiarato.

**Decisioni prese**: (nessuna ancora in questa fase; quelle ereditate dalla Fase 0
sono in `SINTESI_fasi_chiuse.md` e non vanno rimesse in discussione senza un
motivo tecnico nuovo).

**Numeri misurati**: (nessuno ancora — il metro di partenza è
`docs/runs/20260826-2053-envw-5eb456a-baseline.md`).

**Aperto**
- `RUN_NIGHTLY` spenta finché #42 non è chiuso.
- Fuori fase ma tracciato: #40 (T0.10 fragile, Fase 3), P-5 (Fase 2, T-PROF),
  RP-0 (opzionale, Fase 5).

**Prossimo passo**: aprire `release/v0.0.2` da `develop` e assegnare #16 — il
doppio listener Kafka è il progression test dichiarato della release, e P-1 è
l'unico BLOCKER della review ancora aperto sul comportamento.

---
