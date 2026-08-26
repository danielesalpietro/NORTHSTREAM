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
`manifest.json` (machine-readable), `summary.md` (the table that goes into
`docs/runs/`), one `<test>.json` and one `<test>.log` per test. `RUN_ID`
follows `docs/piano_ricovero.md` section 3:
`<YYYYMMDD-HHMM>-<env>-<git-sha-short>`.

## The mock model

`bench/ci/mock-ollama.yml` swaps Ollama for a ~60-line stub that returns
hash-derived embedding vectors and echoes the retrieved context. It exists so
the pipeline can be tested on a GPU-less runner in minutes. It tests plumbing,
never answer quality — tests that depend on a real model (T0.5, T0.9, T0.10)
are excluded from the `ci` suite for exactly this reason.
