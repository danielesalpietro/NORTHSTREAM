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
La sonda va fatta su un ref **coperto dal ruleset** ma privo di valore: un branch
`release/**` usa e getta è il candidato giusto, perché su `release/**` la
cancellazione è consentita per progetto (§3) e quindi la prova si ripulisce da
sola.

**Attenzione al trigger CI**: `ci-static` e `ci-smoke` girano su `release/**`.
Il commit di testa deve contenere `[skip ci]`, altrimenti la sonda accende
25 minuti di runner per niente.

```bash
git checkout -b release/v9.9.9-ruleset-test origin/develop
git commit --allow-empty -m "throwaway: ruleset falsification [skip ci]"
git push -u origin release/v9.9.9-ruleset-test        # atteso: OK (creazione consentita)

git commit --amend --allow-empty -m "throwaway: rewritten [skip ci]"
git push --force origin release/v9.9.9-ruleset-test   # atteso: RIFIUTATO (GH013)

git push origin --delete release/v9.9.9-ruleset-test  # atteso: OK (per progetto)
```

Per i tag, stessa logica con un tag `v*` usa e getta — ma la prova **stranisce
un tag**: se le regole funzionano, il tag non è cancellabile finché non si
disattiva il ruleset. È il costo della verifica, e vale la pena pagarlo una
volta: contestualmente si collauda anche la via d'uscita (disattiva → cancella →
riattiva), che è l'unica prevista visto che non ci sono bypass actor.

**Nota su `develop`**: la regola *Restrict deletions* sul default branch non è
falsificabile, perché GitHub rifiuta comunque la cancellazione del branch di
default a prescindere dai ruleset. Resta utile come rete se un giorno il default
cambia, ma non aspettarsi di vederla scattare.

## 7. Esito della prima esecuzione — 2026-09-01

Eseguita da sessione remota subito dopo l'import dei tre ruleset da parte
dell'owner.

| # | Prova | Ref | Atteso | Osservato | Verdetto |
|---|---|---|---|---|---|
| 1 | Creazione branch | `release/v9.9.9-ruleset-test` | OK | OK | — |
| 2 | **Force-push** | idem | RIFIUTATO | **ACCETTATO**: `+ 07e1f87...b671e05 (forced update)`, exit 0, confermato da `git ls-remote` | **FAIL** |
| 3 | Creazione tag `v0.0.0-ruleset-test` | `refs/tags/v*` | OK | `HTTP 403` dal proxy della sessione | non conclusivo |
| 4 | Spostamento / cancellazione tag | idem | RIFIUTATO | il push non parte (403) | non conclusivo |
| 5 | Cancellazione branch di prova | `release/**` | OK | il push non parte (disconnect del proxy) | non conclusivo |

**Le prove 3-5 non dicono nulla sui ruleset**: le credenziali git di quella
sessione remota non possono creare tag né cancellare ref, quindi il push non
raggiunge mai la valutazione lato GitHub. Un 403 del proxy e un rifiuto GH013
sono due cose diverse, e vanno lette come tali.

**La prova 2 invece è arrivata a GitHub ed è stata accettata**: il ruleset
`protect-release-branches` non era in vigore su quel ref al momento del test.
Le cause possibili, in ordine di probabilità, da verificare nella UI:

1. **Enforcement status ≠ Active.** Un ruleset importato e lasciato `Disabled`
   compare in elenco identico a uno attivo. È la causa più comune.
2. **Target pattern non applicato.** Aprire il ruleset → *Target branches*: deve
   comparire il pattern `release/**`. Se l'import non ha tradotto la condizione,
   la lista è vuota e il ruleset non copre nulla.
3. **Bypass list non vuota.** Se l'import ha aggiunto *Repository admin* o l'app
   che esegue il push, la regola c'è ma non si applica a chi conta.

Lo strumento che distingue i tre casi è **Settings → Rules → Rule Insights**:
elenca i push valutati e per ciascuno dice se è passato, se è stato rifiutato o
se è stato **bypassato** e da chi. Se il force-push della prova 2 non compare
affatto, siamo nel caso 1 o 2; se compare come *bypassed*, nel caso 3.

**Residuo da ripulire a mano**: il branch `release/v9.9.9-ruleset-test`
(commit vuoto `b671e05`) è rimasto su origin, perché la sessione che l'ha creato
non può cancellare ref. Si toglie da
https://github.com/danielesalpietro/NORTHSTREAM/branches o con
`git push origin --delete release/v9.9.9-ruleset-test` da una macchina
dell'owner — che è anche un secondo dato utile: se la cancellazione riesce e il
force-push dalla stessa macchina viene invece rifiutato, la protezione è
esattamente quella progettata.

**Finché la prova 2 non diventa un rifiuto, i tre ruleset vanno considerati
non verificati**, indipendentemente da come appaiono in elenco.

## 8. Nota per il logbook

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
- **Test eseguiti**: falsificazione §6 eseguita il 01/09 — force-push su un branch
  `release/**` di prova **ACCETTATO** (atteso: rifiutato): i ruleset importati non
  erano in vigore su quel ref. Prove su tag e cancellazioni non conclusive (403 del
  proxy della sessione, non di GitHub). Diagnosi e residuo da ripulire in §7 del
  documento.
- **Non funziona / sospeso**: i tre ruleset sono importati ma **non verificati**:
  il force-push di prova è passato. Resta su origin il branch di prova
  `release/v9.9.9-ruleset-test`, che questa sessione non può cancellare.
- **Prossimo passo**: verificare in Rule Insights perché il force-push è passato,
  correggere il ruleset e rieseguire la prova 2 fino al rifiuto GH013.
```
