# NORTHSTREAM test harness

`bench/` holds the executable half of the recovery plan
([`docs/piano_ricovero.md`](../docs/piano_ricovero.md)): every finding of the
technical review becomes a test that fails today, and every release declares
which of those tests it flips to passing.

```
bench/
├── t0/
│   ├── run.sh                 # runner: --suite ci|static|core|full
│   ├── tests/                 # one script per test, order-independent
│   ├── lib/common.sh          # shared helpers, sentinel constants
│   ├── lib/doc_truth.py       # the T0.12 documentation linter (standalone)
│   └── expected/              # declared outcome per target (baseline, current)
└── ci/
    ├── mock-ollama.yml        # compose override used by ci-smoke
    └── mock-ollama/           # deterministic HTTP stub (no model, no GPU)
```

## Result semantics

| Verdict | Meaning | Blocking |
|---|---|---|
| `PASS` | expected to work, and it does | must never regress |
| `XFAIL` | known defect from the review, still failing | no — it is on the release train |
| `FAIL` | expected to work, but it does not | **yes** |
| `XPASS` | known defect that unexpectedly passes | no, but explain it before believing it |
| `SKIP` | prerequisite missing (no Docker, stack down) | no — and it proves nothing either way |

A run exits non-zero only on `FAIL`. `SKIP` is never evidence of success: a
suite that skipped half its tests has measured half a system.

## Running

```bash
# everything that needs no running stack (compose validation + doc linter)
bench/t0/run.sh --suite static

# what ci-smoke runs: pipeline tests against the mock model
bench/t0/run.sh --suite ci

# the day-to-day set on a workstation with real models
bench/t0/run.sh --suite core

# all twelve tests, including the slow recency test
bench/t0/run.sh --suite full --env envl
```

Useful options: `--only T0.3,T0.12` for a single test, `--report <dir>` to
choose the output directory, `--list` to print the suite composition.

### Running against another checkout

The harness never has to modify the code it measures. Point it at a separate
checkout — typically the baseline tag — and give it the matching expectations:

```bash
git worktree add /tmp/ns-baseline v0.0.0-baseline
bench/t0/run.sh --suite core \
  --repo /tmp/ns-baseline \
  --expected bench/t0/expected/baseline.json \
  --env envl
```

`expected/baseline.json` is the contract of the starting point;
`expected/current.json` carries the release branch's own expectations and
differs only where this release declares a progression test.

## Sentinel values

The tests inject fixed, recognisable rows rather than reading whatever the
generator happens to produce, so input and output are verifiable by anyone:

| Value | Used by | Meaning |
|---|---|---|
| `77.31` | T0.3, T0.4 | CDC delivery and agent buffer visibility |
| `91.73` | T0.5, T0.9 | known anomaly for the grounded answer |
| `93.17` at `Depot-9` | T0.10 | anomaly at a site outside `KNOWN_SITES` |

Each test deletes its own sentinel rows before and after running, which is what
makes the suite order-independent.

## Output

Each run writes to `results/<RUN_ID>/` (git-ignored):

| File | What it is |
|---|---|
| `manifest.json` | machine-readable record: verdicts, durations, and a `stack` section with the image ids and digests of the running `northstream-*` containers plus the Ollama models loaded |
| `summary.md` | the table that goes into `docs/runs/` |
| `<test>.json`, `<test>.log` | per-test result and full output |
| `SHA256SUMS` | checksums of everything above, generated last and self-verified |

`RUN_ID` follows `docs/piano_ricovero.md` section 3:
`<YYYYMMDD-HHMM>-<env>-<git-sha-short>`.

Both `SHA256SUMS` and the `stack` section exist because section 3 of the plan
requires an archive that can be verified and a run that can be reproduced — and
a rule nobody can follow without extra manual work is a rule that eventually
gets skipped. After copying an archive elsewhere, verify it with
`sha256sum -c SHA256SUMS` from inside the copy; on RunPod that check is what
gates powering the pod off. When the harness runs without a Docker daemon the
`stack` section is empty rather than absent: an honest "nothing observed"
instead of a silent omission.

## Timeouts

`NS_TEST_TIMEOUT` (default 600 s) is a ceiling per test, so one wedged probe
cannot consume a whole CI budget. A test whose own parameters need longer gets
that ceiling raised automatically rather than being killed mid-measurement:
T0.9 has to let an event grow stale, so its floor is
`NS_RECENCY_SECONDS + 300`.

`NS_RECENCY_SECONDS` defaults to **300**, not the 900 the plan mentions. With
900 against a 600 s ceiling the test could never finish — the first reference
run on ENV-W had to override both values by hand. At 300 the assertion is
weaker (the context keeps events older than 5 minutes, not 15) but still shows
the defect, and it holds with the defaults alone. A run that wants the stronger
assertion passes `NS_RECENCY_SECONDS=900` and the timeout follows on its own.

## The mock model

`bench/ci/mock-ollama.yml` swaps Ollama for a ~60-line stub that returns
hash-derived embedding vectors and echoes the retrieved context. It exists so
the pipeline can be tested on a GPU-less runner in minutes. It tests plumbing,
never answer quality — tests that depend on a real model (T0.5, T0.9, T0.10)
are excluded from the `ci` suite for exactly this reason.
