# NORTHSTREAM soak harness

Measurement tool for **T-SOAK-24h** (`docs/piano_ricovero.md` section 4.3),
built ahead of its v0.0.4 scope on `feature/soak-harness` per `CLAUDE.md`
section 3.2 — test infrastructure can be anticipated because it measures the
system, it never changes it.

It samples the running stack at a fixed interval and writes one append-only
JSON line per sample. It does not start, stop, or configure anything; if the
stack (or any part of it) is down, each affected subsystem records its own
`error` field with a null value instead of crashing the run.

## Usage

```sh
# under tmux/nohup — CLAUDE.md section 5 documents why: a dropped SSH
# connection has already killed a deploy mid-way once.
tmux new -s northstream-soak
bench/soak/run.sh --interval 60 --duration $((24*3600)) --env envw \
  --exclusivity exclusive   # declare it — see below, default is 'unknown'

# turn samples into a verdict, any time during or after the run
python3 bench/soak/verdict.py \
  --samples results/<RUN_ID>/samples.jsonl \
  --manifest results/<RUN_ID>/manifest.json \
  --report results/<RUN_ID>
```

`run.sh --help` and `verdict.py --help` document every flag.

### `--exclusivity` and the manifest's initial conditions (issue #44)

`run.sh` never infers whether ENV-W was exclusively ours for a run — that
classification is issue #44's own pre-check, still to be built in Fase 2.
What this harness does instead, in the meantime:

- **`--exclusivity exclusive|shared|unknown`** (default `unknown`) is declared
  by whoever launches the run and written verbatim into `manifest.json`.
  `unknown` is not a value to avoid — it is the honest answer when nobody
  said, and is strictly better than a guess dressed up as a measurement.
- **`manifest.json.initial_conditions`**, collected once at start via
  `sample.py --mode init`: the CDC connector's state (Kafka Connect REST
  `/connectors/<name>/status`) and the replication slot's state at the
  moment the run began. Same discipline as every sample: unreachable means
  `null` fields and an explicit error, never a guessed state.
- **Per-sample GPU/RAM/load** (already collected every interval, see below)
  is the run-check half of #44: `verdict.py`'s `host_exclusivity` summary
  already reports the min/max GPU memory used across the whole run, so a
  swing partway through is visible without any further code — a run that
  started exclusive and became shared mid-way is distinguishable from one
  that stayed clean throughout, straight from `samples.jsonl`.

What's still #44's own scope, not this harness's: the pre-check gate that
refuses to *start* a run on a shared host, and the automatic
`exclusive`/`shared` classification (this harness only ever writes what was
declared or observed, never infers a verdict).

## What each sample contains

- **Qdrant**: `points_count` for the `stream_events` collection.
- **Postgres**: `pg_replication_slots` (name, active, retained WAL bytes) and
  row counts for `sensor_readings` / `orders`.
- **Containers**: RSS per `northstream-*` container (`docker stats --no-stream`).
- **Host**: load average, RAM available, and — for issue #44 — GPU memory
  used/total per index (`nvidia-smi`, when present).

## What `verdict.py` checks

Four checks from the plan, computed from the first and last sample that can
answer each one:

| Check | Verdict source |
|---|---|
| Qdrant growth vs retention | Real, but retention isn't implemented yet — reports the growth trend and flags unbounded growth; no fabricated ceiling |
| Replication slot size | `OK`/`WARN` if `--max-replication-mib` is given, else trend only |
| Event loss (DB rows vs Qdrant points) | Always a real `OK`/`WARN` — no threshold needed, it is a direct delta comparison |
| RSS vs tier | `OK`/`WARN` if `--rss-ceiling-mib` is given, else trend only — no full-stack RSS ceiling is declared in the plan yet (only `core`, via T-PROF in v0.0.3) |

The two checks without a declared threshold report `UNKNOWN` rather than a
fabricated pass — a number with no basis in the plan is not a gate, it is
noise dressed up as one.

`host_exclusivity` is descriptive only, for issue #44: it surfaces the raw
GPU/RAM/load variability across the run so a human (or #44's own pre-check,
once it exists) can tell whether ENV-W stayed exclusive for the whole window.

## Failure handling

A degraded subsystem never aborts the run: `run.sh` treats a non-zero
`sample.py` exit as "log it and keep looping" (`soak.err.log`), and each
sample line is written with a single flushed+`fsync`'d `write()` call, so a
kill at any point — `SIGINT`/`SIGTERM`, or a harder kill — leaves every prior
line intact and parseable.
