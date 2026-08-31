#!/usr/bin/env python3
"""
NORTHSTREAM soak verdict — turns bench/soak/run.sh samples into a read on the
four T-SOAK-24h checks (docs/piano_ricovero.md section 4.3), plus the host
resource visibility requested for issue #44.

Deliberately conservative about verdicts: two of the four checks (Qdrant
growth vs retention, RSS vs tier) have no authoritative threshold declared
anywhere in the plan yet — retention is not implemented, and the RSS tier
ceiling declared so far (T-PROF, v0.0.3) applies to the `core` profile, not
the full stack a soak exercises. Rather than invent a number that would look
like a real gate, this script reports the trend and marks those two UNKNOWN
unless the caller supplies an explicit threshold. The other two checks
(replication slot growth, event loss) are computed directly from the deltas
between the first and last valid sample and always get a real verdict.

Usage:
  verdict.py --samples FILE [--manifest FILE] [--report DIR]
             [--max-replication-mib N] [--rss-ceiling-mib N]

Writes verdict.json (and, with --report, summary.md) and prints a table.
Exit code: 0 unless the samples file is missing/unreadable (2) — this script
is observational, it does not gate a release on its own.
"""

import argparse
import json
import sys


def load_samples(path):
    samples = []
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                samples.append(json.loads(line))
            except json.JSONDecodeError as exc:
                print(f"warning: {path}:{lineno}: skipping malformed line ({exc})", file=sys.stderr)
    return samples


def first_last_valid(samples, predicate):
    valid = [s for s in samples if predicate(s)]
    if not valid:
        return None, None
    return valid[0], valid[-1]


def check_qdrant_growth(samples):
    def pred(s):
        return s.get("qdrant", {}).get("points_count") is not None

    first, last = first_last_valid(samples, pred)
    if first is None:
        return {"verdict": "UNKNOWN", "detail": "no sample with a readable Qdrant points_count"}

    points = [s["qdrant"]["points_count"] for s in samples if pred(s)]
    growth = points[-1] - points[0]
    plateaued = any(points[i] <= points[i - 1] for i in range(1, len(points)))
    hours = max(
        (_parse_ts(last["ts"]) - _parse_ts(first["ts"])).total_seconds() / 3600.0, 1e-6
    )
    return {
        "verdict": "OK" if plateaued else "WARN",
        "detail": (
            f"points {points[0]} -> {points[-1]} (+{growth}, {growth / hours:.1f}/h); "
            + ("growth plateaued or dropped at least once — bounded" if plateaued
               else "monotonically increasing across the whole run — no retention observed, matches "
                    "A-3 until it is fixed in v0.0.4; no ceiling declared to fail against")
        ),
    }


def check_replication_slots(samples, max_mib):
    max_bytes = None
    max_sample_ts = None
    for s in samples:
        for slot in s.get("postgres", {}).get("replication_slots", []):
            retained = slot.get("retained_bytes")
            if retained is not None and (max_bytes is None or retained > max_bytes):
                max_bytes = retained
                max_sample_ts = s.get("ts")

    if max_bytes is None:
        return {"verdict": "UNKNOWN", "detail": "no sample with a readable replication slot"}

    max_mib_observed = max_bytes / 1024.0 / 1024.0
    if max_mib is None:
        return {
            "verdict": "UNKNOWN",
            "detail": f"peak retained WAL {max_mib_observed:.1f} MiB at {max_sample_ts} — "
                      "no --max-replication-mib supplied, reporting trend only",
        }
    verdict = "OK" if max_mib_observed <= max_mib else "WARN"
    return {
        "verdict": verdict,
        "detail": f"peak retained WAL {max_mib_observed:.1f} MiB at {max_sample_ts} "
                  f"(ceiling {max_mib} MiB)",
    }


def check_event_loss(samples):
    def pred(s):
        return (
            s.get("qdrant", {}).get("points_count") is not None
            and s.get("postgres", {}).get("table_counts")
        )

    first, last = first_last_valid(samples, pred)
    if first is None:
        return {"verdict": "UNKNOWN", "detail": "no sample with both Qdrant and Postgres counts readable"}

    db_first = sum(v for v in first["postgres"]["table_counts"].values() if v is not None)
    db_last = sum(v for v in last["postgres"]["table_counts"].values() if v is not None)
    q_first = first["qdrant"]["points_count"]
    q_last = last["qdrant"]["points_count"]
    db_delta = db_last - db_first
    q_delta = q_last - q_first

    verdict = "OK" if q_delta >= db_delta else "WARN"
    return {
        "verdict": verdict,
        "detail": f"db rows +{db_delta} ({db_first}->{db_last}), qdrant points +{q_delta} "
                  f"({q_first}->{q_last})"
                  + ("" if verdict == "OK" else f" — {db_delta - q_delta} fewer points than rows"),
    }


def check_rss(samples, ceiling_mib):
    totals = []
    per_container_max = {}
    for s in samples:
        containers = s.get("containers", {})
        if "_error" in containers:
            continue
        total = 0.0
        any_value = False
        for name, stats in containers.items():
            if name.startswith("_"):  # metadata keys (_error, _warnings), not a container
                continue
            rss = stats.get("rss_mib")
            if rss is None:
                continue
            any_value = True
            total += rss
            per_container_max[name] = max(per_container_max.get(name, 0.0), rss)
        if any_value:
            totals.append(total)

    if not totals:
        return {"verdict": "UNKNOWN", "detail": "no sample with readable container RSS"}

    peak = max(totals)
    detail = f"peak total RSS {peak:.0f} MiB across {len(per_container_max)} container(s)"
    if ceiling_mib is None:
        return {"verdict": "UNKNOWN", "detail": detail + " — no --rss-ceiling-mib supplied"}
    verdict = "OK" if peak <= ceiling_mib else "WARN"
    return {"verdict": verdict, "detail": detail + f" (ceiling {ceiling_mib} MiB)"}


def host_exclusivity_summary(samples):
    """Descriptive only (issue #44's own pre-check/classification logic is out
    of scope here) — makes the raw variability visible so a human, or #44's
    future classifier, can tell whether the host stayed exclusive."""
    gpu_series = {}
    load_series = []
    ram_series = []
    for s in samples:
        host = s.get("host", {})
        for gpu in host.get("gpu") or []:
            gpu_series.setdefault(gpu["index"], []).append(gpu["memory_used_mib"])
        if host.get("load1") is not None:
            load_series.append(host["load1"])
        if host.get("ram_available_mib") is not None:
            ram_series.append(host["ram_available_mib"])

    gpu_summary = {
        f"gpu{idx}": {"min_used_mib": min(v), "max_used_mib": max(v), "samples": len(v)}
        for idx, v in gpu_series.items()
    }
    return {
        "gpu": gpu_summary or None,
        "load1_min_max": [min(load_series), max(load_series)] if load_series else None,
        "ram_available_mib_min_max": [min(ram_series), max(ram_series)] if ram_series else None,
        "note": "descriptive only — a GPU/RAM swing not attributable to our own containers "
                "suggests the host was shared during part of the run; the pre-check gate itself "
                "is issue #44's scope, not this script's",
    }


def _parse_ts(ts):
    from datetime import datetime
    return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", required=True)
    parser.add_argument("--manifest", default=None)
    parser.add_argument("--report", default=None, help="directory to write verdict.json/summary.md into")
    parser.add_argument("--max-replication-mib", type=float, default=None)
    parser.add_argument("--rss-ceiling-mib", type=float, default=None)
    args = parser.parse_args()

    try:
        samples = load_samples(args.samples)
    except OSError as exc:
        print(f"cannot read {args.samples}: {exc}", file=sys.stderr)
        sys.exit(2)

    if not samples:
        print(f"{args.samples}: no valid samples", file=sys.stderr)
        sys.exit(2)

    manifest = {}
    if args.manifest:
        try:
            with open(args.manifest, encoding="utf-8") as fh:
                manifest = json.load(fh)
        except OSError as exc:
            print(f"warning: cannot read manifest {args.manifest}: {exc}", file=sys.stderr)

    checks = {
        "qdrant_growth_vs_retention": check_qdrant_growth(samples),
        "replication_slot_size": check_replication_slots(samples, args.max_replication_mib),
        "event_loss_db_vs_qdrant": check_event_loss(samples),
        "rss_vs_tier": check_rss(samples, args.rss_ceiling_mib),
    }

    result = {
        "run_id": manifest.get("run_id"),
        "sample_count": len(samples),
        "window": [samples[0]["ts"], samples[-1]["ts"]],
        "checks": checks,
        "host_exclusivity": host_exclusivity_summary(samples),
    }

    print(f"soak verdict — {result['run_id'] or args.samples} — {len(samples)} sample(s), "
          f"{result['window'][0]} .. {result['window'][1]}\n")
    for name, check in checks.items():
        print(f"  {check['verdict']:<8} {name}")
        print(f"           {check['detail']}")
    print()
    exclusivity = result["host_exclusivity"]
    print(f"  host exclusivity (descriptive, issue #44): {json.dumps(exclusivity)}")

    if args.report:
        import os
        os.makedirs(args.report, exist_ok=True)
        with open(os.path.join(args.report, "verdict.json"), "w", encoding="utf-8") as fh:
            json.dump(result, fh, indent=2)
        with open(os.path.join(args.report, "summary.md"), "w", encoding="utf-8") as fh:
            fh.write(f"# Soak verdict `{result['run_id'] or ''}`\n\n")
            fh.write(f"- **Campioni**: {len(samples)} · **Finestra**: {result['window'][0]} .. {result['window'][1]}\n\n")
            fh.write("| Verifica | Esito | Dettaglio |\n|---|---|---|\n")
            for name, check in checks.items():
                fh.write(f"| {name} | **{check['verdict']}** | {check['detail']} |\n")
            fh.write(f"\nEsclusività host (#44, descrittivo): `{json.dumps(exclusivity)}`\n")


if __name__ == "__main__":
    main()
