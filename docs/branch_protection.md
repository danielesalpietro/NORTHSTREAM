# Protezione dei branch — analisi e regole consigliate

Proposta per il suggerimento GitHub **"Protect your most important branches"**
(Settings → Rules → Rulesets). Documento di decisione: le regole qui sotto
**non sono attive**, vanno importate dall'owner (§5). Nessuna sessione Claude
ha i permessi per crearle.

Redatto il 2026-09-01 sul branch `claude/protect-important-branches-fcz7wa`
(base: `develop` @ `f585e38`).

---

## 1. Contesto misurato, non supposto

| Fatto | Verifica |
|---|---|
| Repository **pubblico**, licenza MIT, default branch **`develop`** (non esiste `main`) | API repo |
| **Un solo collaboratore**: `danielesalpietro`, ruolo `admin`. Bus factor 1 | `list_repository_collaborators` |
| Branch vivi su origin: `develop`, `release/v0.0.1..v0.0.4`, `feature/soak-harness`, branch `claude/**` di sessione | `git ls-remote --heads` |
| Tag di baseline: `v0.0.0-baseline`, `v0.0.1`, `v0.0.2`, `v0.0.3` (annotati) | `git ls-remote --tags` |
| La storia usa **merge commit** deliberati (`Merge release v0.0.3 into develop`) | `git log --merges` |
| `ci-static` e `ci-smoke` girano **solo su `push`** verso `develop` e `release/**`. **Nessun workflow ha il trigger `pull_request`** | `.github/workflows/*.yml` |
| `ci-nightly` è dormiente (`RUN_NIGHTLY` spenta) e gira su runner self-hosted | `.github/workflows/ci-nightly.yml` |
| Le sessioni (owner + Claude) **pushano direttamente** sui branch, e sui propri branch di sessione fanno force-push | `CLAUDE.md` §3.4, §3.8 |
| I commit sono creati in container effimeri, **non firmati** | storia del repo |

Due vincoli di processo già decisi, che non vanno riaperti da una regola di
piattaforma:

- `docs/piano_ricovero.md` §5: *«niente PR flow obbligatorio fino al secondo
  contributor; la protezione è la CI su push»*;
- `docs/review_tecnica.md` §4.5: il PR flow verso sé stessi è *«cerimonia che
  attrita esattamente la persona che deve restare motivata»*, e non avrebbe
  intercettato i difetti reali (P-1, P-2), che si vedono **eseguendo**.

## 2. Perché il template non si importa così com'è

Il suggerimento di GitHub è tarato su un team: branch protetto + PR obbligatoria
+ approvazioni + status check + storia lineare. Applicato qui, tre delle sue
regole rompono il progetto invece di proteggerlo:

1. **Require a pull request before merging** → blocca il push diretto su
   `develop`, che è *l'unico* modo in cui oggi arriva il merge di release. E la
   PR non sarebbe comunque mergeabile con check verdi, perché nessun workflow
   ha il trigger `pull_request`: i check non partono proprio.
2. **Require status checks to pass** → stessa causa. Su push diretto la regola
   rifiuta il commit (i check non possono essere già verdi su un commit che non
   esiste ancora sul server); su PR i check non partono. In entrambi i casi il
   branch diventa non scrivibile.
3. **Require linear history** → vieta i merge commit su cui è costruito il
   release train (`release/vX.Y.Z` → merge in `develop` → tag).

Il rischio reale di questo repository non è «qualcuno mergia codice non
revisionato»: è **un ref riscritto o cancellato da un attore automatico che ha
i permessi di admin**. Le baseline citate in `CLAUDE.md` §2 (`5eb456a`,
`d3053be`, `966422d`, `442bac1`) e i SHA nei report di `docs/runs/` sono
verificabili solo finché quei ref restano dove sono. È lì che va messa la
protezione.

## 3. Verdetto regola per regola

Legenda: **SÌ** = adottare ora · **DOPO** = adottare quando cade la condizione
indicata · **NO** = non adottare, con la ragione.

| Regola (nomenclatura UI) | Branch | Tag | Verdetto e ragione |
|---|---|---|---|
| **Restrict deletions** | `develop` | `v*` | **SÌ.** Cancellazione di `develop` o di un tag di baseline = perdita del riferimento di non-regressione (`CLAUDE.md` §3.1). Attrito zero: nessun flusso attuale cancella questi ref. Su `release/**` **no**: il piano (§5) prevede che quei branch muoiano dopo il merge, e il tag conserva già il SHA. |
| **Block force pushes** (`non_fast_forward`) | `develop`, `release/**` | `v*` | **SÌ.** È l'incidente più probabile e l'unico irreversibile: una sessione che sbaglia branch e fa `push --force`. Attrito zero — su questi ref nessuno force-pusha per lavorare. **Esclusi `claude/**` e `feature/**`**: lì il force-with-lease è parte del flusso e va lasciato libero. |
| **Restrict updates** (`update`) | — | `v*` | **SÌ sui tag.** Impedisce di *spostare* un tag esistente. Un tag di baseline che si muove è peggio di uno cancellato: la cancellazione si nota, lo spostamento no — è la stessa classe di errore della «costante travestita da misura» di `CLAUDE.md` §5. La creazione di nuovi tag resta libera (regola distinta: *Restrict creations*). |
| **Restrict creations** | — | — | **NO.** Le sessioni creano `claude/**`, `feature/**`, `release/**` e i tag di release. |
| **Require a pull request before merging** | — | — | **DOPO**, e solo al **secondo contributor** (piano §5, review §4.5). Prerequisito tecnico: aggiungere il trigger `pull_request` a `ci-static` e `ci-smoke`, altrimenti la PR non ha check da attendere. Con un solo maintainer va impostata a **0 approvazioni richieste** (GitHub vieta comunque l'auto-approvazione), altrimenti il branch si autoblocca. |
| **Require status checks to pass** | — | — | **DOPO**, insieme alla precedente e mai prima: oggi la CI gira su `push`, quindi la regola trasformerebbe la protezione in un blocco totale della scrittura. Check da richiedere quando si farà: `static` e `smoke`. Mai `ci-nightly` (runner self-hosted intermittente e oggi spento). |
| **Require linear history** | — | — | **NO.** Incompatibile col release train a merge commit. Adottarla significherebbe riscrivere il modello di branching, non aumentare la sicurezza. |
| **Require signed commits** | — | — | **NO oggi.** Le sessioni committano in container effimeri senza chiavi: la regola bloccherebbe ogni sessione al primo push. Riconsiderabile solo se i commit passassero dall'API GitHub (firma lato server) o se l'owner distribuisse una chiave a tutti gli ambienti (ENV-L, ENV-W, container remoti). |
| **Require deployments to succeed** | — | — | **NO.** Non esistono environment di deploy. |
| **Require code scanning results** | — | — | **DOPO.** Nessun setup CodeQL oggi. Candidata per l'hardening di una fase successiva, non per ora. |
| **Restrict updates** su `release/v0.0.1..3` | opzionale | — | **Opzionale.** Un ruleset su `refs/heads/release/v0.0.[123]` con *Restrict updates* congela le release già taggate. Utile ma marginale: il force-push è già bloccato dalla regola sopra e un commit fast-forward su un branch chiuso è visibile e reversibile. |

**Bypass actors: nessuno.** È la scelta che rende la protezione reale. L'attore
da cui ci si protegge (owner e sessioni Claude) ha già il ruolo `admin`: un
bypass «Repository admin» renderebbe le regole decorative — esattamente il
difetto che `CLAUDE.md` §5 chiama *un test mai visto fallire*. Quando serve
davvero cancellare un tag o riscrivere `develop`, l'owner disabilita il ruleset
dalla UI, fa l'operazione e lo riattiva: due click deliberati, che è il punto.
(La modalità *Evaluate*, non bloccante, è disponibile solo su Enterprise: su un
repo personale i ruleset sono Active o Disabled.)

## 4. Regole consigliate — riepilogo operativo

Tre ruleset, tutti in `.github/rulesets/`:

| File | Target | Regole |
|---|---|---|
| `protect-develop.json` | default branch (`develop`) | Restrict deletions · Block force pushes |
| `protect-release-branches.json` | `refs/heads/release/**` | Block force pushes |
| `protect-version-tags.json` | `refs/tags/v*` | Restrict deletions · Restrict updates · Block force pushes |

Effetto sul lavoro quotidiano: **nessuno**. Nessuno dei flussi descritti in
`CLAUDE.md` §3 e nel piano §5-§6 esegue oggi una delle operazioni vietate.

## 5. Come applicarle (solo owner)

1. Settings → Rules → Rulesets → **New ruleset** → *Import a ruleset* →
   selezionare il file JSON.
2. Ripetere per i tre file. Verificare che *Enforcement status* sia **Active**
   e che *Bypass list* sia **vuota**.
3. Se l'import di `protect-version-tags.json` viene rifiutato sulla regola
   `update`, rimuovere quell'oggetto dal JSON, importare il resto e attivare
   *Restrict updates* dalla UI del ruleset.

## 6. Falsificazione (obbligatoria — `CLAUDE.md` §5)

Una regola mai vista rifiutare un push non è una protezione, è una decorazione.
Prima di considerarle attive:

```bash
# 1. aggiungere temporaneamente refs/heads/test/ruleset-* alle condizioni
#    del ruleset protect-develop (UI: Target branches → Add pattern)

git checkout -b test/ruleset-1 develop
git push -u origin test/ruleset-1            # atteso: OK (creazione consentita)
git commit --allow-empty -m "throwaway"
git push --force origin test/ruleset-1       # atteso: RIFIUTATO — GH013 rule violations
git push origin --delete test/ruleset-1      # atteso: RIFIUTATO — GH013 rule violations

# 2. rimuovere il pattern test/ruleset-* dal ruleset
# 3. cancellare il branch di prova (ora consentito) e verificare che
#    develop e i tag siano rimasti intatti:
git ls-remote --tags origin | grep v0.0.3
```

Un `git push --force` che **riesce** su `test/ruleset-1` significa che il
ruleset non sta guardando quel ref: la regola è scritta ma non applicata.

## 7. Nota per il logbook

La entry di sessione va appesa a `docs/logbook/LOGBOOK_v0.0.4.md`, che esiste
**solo su `release/v0.0.4`** — branch lavorato in questo momento da un'altra
sessione (`CLAUDE.md` §3.8). Crearlo qui su `develop` produrrebbe un conflitto
di merge fra due file nati indipendentemente, quindi la entry è lasciata a chi
integra questa proposta. Testo pronto:

```markdown
## 2026-09-01 — sessione remota (senza Docker) — proposta protezione ref
- **Obiettivo della sessione**: valutare il suggerimento GitHub "Protect your
  most important branches" e proporre le regole da adottare.
- **Fatto**: `docs/branch_protection.md` + tre ruleset importabili in
  `.github/rulesets/` (branch `claude/protect-important-branches-fcz7wa`).
- **Decisioni prese**: si proteggono **i ref, non il processo** — deletion,
  force-push e spostamento dei tag. Scartati PR flow obbligatorio, status check
  richiesti, storia lineare e commit firmati: i primi due sono oggi tecnicamente
  impossibili (nessun workflow ha il trigger `pull_request`, la CI gira su push),
  il terzo rompe il release train a merge commit, il quarto blocca ogni sessione
  che committa in container senza chiavi. Nessun bypass actor: con l'owner admin,
  un bypass renderebbe le regole decorative.
- **Test eseguiti**: nessuno a runtime (sessione senza permessi di admin sul
  repo); procedura di falsificazione scritta in §6 del documento.
- **Non funziona / sospeso**: le regole non sono attive — servono i permessi
  dell'owner.
- **Prossimo passo**: importare i tre ruleset ed eseguire la falsificazione §6.
```
