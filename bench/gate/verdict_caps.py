#!/usr/bin/env python3
"""Verdict for the caps gate — §4.3.1(d) of docs/piano_ricovero.md.

Kept separate from the run on purpose. A verdict that lives beside the raw
data can be re-run when the rule changes, which is exactly what happened to
soak #1: it was adjudicated again against thresholds written after it ran.

Three conditions, all of which must hold:
  1. RestartCount unchanged from start to end, for every container.
  2. No capped service above 90% of its own mem_limit for >= 10 consecutive
     samples.
  3. Total RSS of capped services within the sum of their caps.

Condition 1 exists because 2 and 3 missed the most broken service of the
nineteen: open-webui restarted 3474 times in 7.4 hours and its longest run
above 90% was two samples. A cap set below the footprint kills the process
before it can press against the ceiling, so its RSS reads LOW, not high.

Anything unmeasurable is UNKNOWN, never OK. Usage: verdict_caps.py <archive>
"""
import sys
import pathlib
import statistics

# Services the compose deliberately leaves uncapped, with the reason it gives.
# Without this the verdict can never return OK on a real archive: ollama has no
# mem_limit on purpose and sits in every profile, so every run ends UNKNOWN --
# the exact degeneration §4.3.1(d) corrected in the plan on 2026-08-28, walked
# back in through the code. Per that rule an exempt service is not waved
# through: its RSS is reported separately, so it stays in the reader's view
# without a ceiling to fail against.
# This list must match the compose. Drift is a real risk and is deliberately
# visible: an unlisted uncapped service still reads UNKNOWN, never OK.
DECLARED_EXEMPT = {
    "northstream-ollama": "no mem_limit on purpose: what it needs is set by the model loaded",
}

# A window this short cannot exercise the ">= 10 consecutive samples above 90%"
# condition at all, so a verdict over fewer samples would be green having looked
# at nothing. Truncated series are not hypothetical here: the ENV-W session died
# mid-run four times in three days.
MIN_SAMPLES = 12

UNIT = {"B": 1 / 1048576, "KIB": 1 / 1024, "MIB": 1.0, "GIB": 1024.0,
        "KB": 1000 / 1048576, "MB": 1e6 / 1048576, "GB": 1e9 / 1048576}


def to_mib(text):
    """'679.7MiB' -> 679.7. Returns None when it cannot be read, never 0."""
    text = text.strip()
    for i, ch in enumerate(text):
        if not (ch.isdigit() or ch == "."):
            try:
                return float(text[:i]) * UNIT[text[i:].strip().upper()]
            except (ValueError, KeyError):
                return None
    return None


def read_inspect(path):
    out = {}
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        f = line.split("\t")
        if len(f) < 6:
            continue
        name = f[0].lstrip("/")
        try:
            restarts = int(f[1])
        except ValueError:
            restarts = None          # unknown, not zero
        try:
            cap = int(f[4]) / 1048576 or None
        except ValueError:
            cap = None
        out[name] = {"restarts": restarts, "state": f[2], "health": f[3],
                     "cap_mib": cap, "oomkilled": f[5]}
    return out



def read_jsonl(path):
    """ENV-W's own sampler format: one JSON object per sample, every container's
    restarts/limit/rss/current/peak in each. Richer than the stats.tsv shape --
    it sees a restart *inside* the window, not only across the endpoints -- so
    when both are present this one wins.

    Judged on `current_mib`, the figure the cgroup actually enforces, with
    `peak_mib` kept as a separate signal: elasticsearch was caught by a peak
    sitting at exactly its limit while the median looked survivable.
    """
    import json
    start, end, series, peaks, missing = {}, {}, {}, {}, 0
    seen_restarts = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            sample = json.loads(line)
        except ValueError:
            missing += 1
            continue
        for name, c in (sample.get("containers") or {}).items():
            cap = c.get("limit_mib") or None
            rec = {"restarts": c.get("restarts"), "state": c.get("status", "?"),
                   "health": c.get("health", "?"), "cap_mib": cap,
                   "oomkilled": str(c.get("oom_killed", "?"))}
            start.setdefault(name, rec)
            end[name] = rec
            series.setdefault(name, []).append(c.get("current_mib"))
            if c.get("peak_mib") is not None and cap:
                peaks[name] = max(peaks.get(name, 0), c["peak_mib"])
            seen_restarts.setdefault(name, []).append(c.get("restarts"))
    # A restart that happens and is undone within the window would hide between
    # the endpoints; compare against the max seen instead of the last value.
    for name, values in seen_restarts.items():
        known = [v for v in values if v is not None]
        if known:
            end[name]["restarts"] = max(known)
    return start, end, series, peaks, missing


def main(archive, prefix="northstream-"):
    root = pathlib.Path(archive)
    peaks = {}
    jsonl = root / "samples.jsonl"
    if jsonl.exists():
        start, end, series, peaks, missing = read_jsonl(jsonl)
        if not start:
            print("UNKNOWN — samples.jsonl holds no readable container data")
            return 2
    else:
        start, end = read_inspect(root / "inspect.start.tsv"), read_inspect(root / "inspect.end.tsv")
        if not start or not end:
            print("UNKNOWN — inspect sweeps missing; the gate did not complete")
            return 2
        series, missing = {}, 0
        for line in (root / "stats.tsv").read_text().splitlines() if (root / "stats.tsv").exists() else []:
            parts = line.split("\t")
            if len(parts) < 3 or parts[2].startswith("ERROR"):
                missing += 1
                continue
            for entry in parts[2].split("|"):
                if entry.count(";") < 2:
                    continue
                name, usage, _ = entry.split(";", 2)
                mib = to_mib(usage.split("/")[0])
                series.setdefault(name.strip(), []).append(mib)

    sample_count = max((len(v) for v in series.values()), default=0)
    if sample_count < MIN_SAMPLES:
        print(f"UNKNOWN — {sample_count} samples, below the {MIN_SAMPLES} needed for the "
              f"'>= 10 consecutive above 90%' condition to be reachable at all. "
              f"A verdict here would be green having looked at nothing.")
        return 2

    failures, unknowns, rows, exempt, foreign = [], [], [], [], []
    for name in sorted(set(start) | set(end)):
        # Containers outside this compose project are reported, not judged. One
        # foreign container alive for a single sample used to send the whole
        # gate to UNKNOWN.
        if not name.startswith(prefix):
            foreign.append(name)
            continue
        s, e = start.get(name, {}), end.get(name, {})
        r0, r1, cap = s.get("restarts"), e.get("restarts"), e.get("cap_mib") or s.get("cap_mib")
        samples = [v for v in series.get(name, []) if v is not None]
        med = statistics.median(samples) if samples else None

        if r0 is None or r1 is None:
            unknowns.append(f"{name}: RestartCount unreadable")
        elif r1 != r0:
            failures.append(f"{name}: RestartCount {r0} -> {r1} during the run")

        # Not a condition of §4.3.1(d), so not a FAIL -- but a container that is
        # unhealthy without restarting would otherwise score green in silence,
        # and silence is the failure mode this whole gate exists to remove.
        health = e.get("health", "?")
        # "-" and "none" both mean "this container declares no healthcheck";
        # the real ENV-W sampler writes "-", which read as unhealthy would have
        # turned eleven perfectly fine containers into UNKNOWN.
        if health not in ("healthy", "none", "-", "", "?"):
            unknowns.append(f"{name}: health is {health!r} while its cap holds")

        pct = longest = None
        if cap and samples:
            pct = med / cap * 100
            run = 0
            for v in series[name]:
                run = run + 1 if (v is not None and v > 0.9 * cap) else 0
                longest = max(longest or 0, run)
            if longest >= 10:
                failures.append(f"{name}: above 90% of its {cap:.0f} MiB cap for {longest} consecutive samples")
            peak = peaks.get(name)
            if peak and peak >= 0.99 * cap:
                failures.append(f"{name}: peak {peak:.1f} MiB reached its {cap:.0f} MiB cap")
        elif not cap:
            if name in DECLARED_EXEMPT:
                exempt.append((name, med, DECLARED_EXEMPT[name]))
            else:
                unknowns.append(f"{name}: no mem_limit and not a declared exemption")
        elif not samples:
            unknowns.append(f"{name}: no usable samples")

        rows.append((name, med, cap, pct, r0, r1, longest, health))

    capped = [(m, c) for _, m, c, _, _, _, _, _ in rows if m and c]
    total, budget = sum(m for m, _ in capped), sum(c for _, c in capped)
    if budget and total > budget:
        failures.append(f"total RSS of capped services {total:.0f} > budget {budget:.0f} MiB")

    print(f"# Caps gate — {root.name}\n")
    print(f"{'service':<34}{'MiB':>8}{'cap':>8}{'%':>7}{'restarts':>10}{'>90% run':>10}  health")
    for name, med, cap, pct, r0, r1, longest, health in rows:
        print(f"{name:<34}{(f'{med:.0f}' if med else '?'):>8}"
              f"{(f'{cap:.0f}' if cap else '—'):>8}{(f'{pct:.1f}' if pct else '—'):>7}"
              f"{(f'{r0}->{r1}' if r0 is not None else '?'):>10}"
              f"{(str(longest) if longest is not None else '—'):>10}  {health}")
    print(f"\ncapped total {total:.0f} MiB of {budget:.0f} MiB budget"
          f" over {sample_count} samples"
          f"{f'  ({missing} unreadable)' if missing else ''}")
    for name, med, why in exempt:
        print(f"exempt  {name}: {med:.0f} MiB — {why}" if med else f"exempt  {name}: ? MiB — {why}")
    if foreign:
        print(f"outside {prefix}: {', '.join(foreign)} (reported, not judged)")
    print()

    for f in failures:
        print(f"FAIL    {f}")
    for u in unknowns:
        print(f"UNKNOWN {u}")
    if failures:
        print("\nVERDICT: FAIL")
        return 1
    print("\nVERDICT: UNKNOWN — resolve the entries above" if unknowns else "\nVERDICT: OK")
    return 2 if unknowns else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else ".",
                  sys.argv[2] if len(sys.argv) > 2 else "northstream-"))
