# LOGBOOK — Fase 2: Stack onesto sulle risorse (v0.0.3)

Memoria di fase secondo `CLAUDE.md` §4. Le **entry** sono append-only e non si
riscrivono mai. La **testa** qui sotto è l'unica parte che si riscrive: è la
forma compressa della fase, e alla chiusura diventa l'ESITO FASE.

> **Per una sessione nuova**: leggi la testa e l'ultima entry. Le entry
> intermedie servono solo per ricostruire un dettaglio che la testa non copre.
> La memoria delle fasi già chiuse è in `docs/logbook/SINTESI_fasi_chiuse.md`.

---

## SINTESI DI FASE — aggiornata al 2026-08-27, apertura fase

**Dove siamo**: fase appena aperta. Base: tag `v0.0.2` → `966422d` (annotato),
`develop` allineato col merge `cfc98f3`. La Fase 1 ha chiuso P-1 nel comportamento
(T0.6 PASS con modelli veri) e la famiglia P-11/P-12/P-13; il suo esito distillato
è in `docs/logbook/SINTESI_fasi_chiuse.md`.

**Scope della fase** (`docs/piano_ricovero.md` §6, riga v0.0.3 — obiettivo O4):
smettere di mentire sulle risorse. Issue di fase
[#5](https://github.com/danielesalpietro/NORTHSTREAM/issues/5).

| Sub-issue | Contenuto | Finding |
|---|---|---|
| [#21](https://github.com/danielesalpietro/NORTHSTREAM/issues/21) | Compose profiles `core`/`lakehouse`/`governance` + `mem_limit` per servizio | **P-5** |
| [#22](https://github.com/danielesalpietro/NORTHSTREAM/issues/22) | `trino/catalog/postgres.properties` + configurazione memoria Trino | **P-2** |
| [#23](https://github.com/danielesalpietro/NORTHSTREAM/issues/23) | Tier hardware riscritti sui numeri misurati + **T-PROF** | §4.2/4.3 review |
| [#44](https://github.com/danielesalpietro/NORTHSTREAM/issues/44) | Esclusività dell'host: pre-check, run-check, post-run nel `manifest.json` | — (nato dalla Fase 1) |
| [#24](https://github.com/danielesalpietro/NORTHSTREAM/issues/24) | Release v0.0.3: gate, CHANGELOG, tag | — |

**Progression test dichiarati**: **T0.7** (catalogo Trino presente e query su
`postgresql.public.orders` con `count(*)` > 0) XFAIL → **PASS**; nuovo **T-PROF**:
profilo `core` completo con RSS totale ≤ 14 GB **su ENV-L** — non su ENV-W, dove
con 256 GB fisici le JVM auto-dimensionano l'heap e il footprint osservato è un
limite superiore (v. riga ENV-W del piano §2).

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

**Numeri misurati**: (nessuno ancora in questa fase — il metro resta
`docs/runs/20260826-2053-envw-5eb456a-baseline.md`, più i run di v0.0.2 elencati
nell'ESITO FASE 1).

**Prossimo passo**: assegnare **#22 e #21**. #22 chiude l'altra metà di P-2 —
la prima metà, la directory `trino/catalog` mancante, è già chiusa dal `.gitkeep`
di P-12 — ed è il progression test dichiarato della release.
