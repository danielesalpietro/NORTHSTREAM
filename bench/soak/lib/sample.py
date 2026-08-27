#!/usr/bin/env python3
"""
NORTHSTREAM soak sampler — one shot.

Collects one observation of the four T-SOAK-24h signals (docs/piano_ricovero.md
section 4.3) plus the host-exclusivity fields requested for issue #44, and
appends it as a single JSON line to the output file.

Design constraint: this must never take the run down. Every subsystem is
collected independently and wrapped in its own try/except; a subsystem that
is unreachable (stack not running, no GPU, docker missing) reports its own
"error" field and null values instead of raising. bench/soak/run.sh calls
this once per interval and treats a non-zero exit as "sample failed, keep
looping" — but a clean exit with partial data is always preferred, because a
degraded line is still analysable and a missing one is not.

Usage:
  sample.py --seq N [--repo PATH] [--out FILE]

With --out, the JSON line is appended (open 'a', single write() call, flush +
fsync) so a kill mid-run leaves every prior line intact. Without --out, the
line is printed to stdout.
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

DOCKER_TIMEOUT = 15  # seconds per subprocess call — a wedged docker/psql must not hang the sampler.


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run(cmd, timeout=DOCKER_TIMEOUT):
    """subprocess.run wrapper: returns (stdout, None) or (None, error string)."""
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, check=False
        )
        if proc.returncode != 0:
            return None, (proc.stderr or proc.stdout or f"exit {proc.returncode}").strip()[:500]
        return proc.stdout, None
    except FileNotFoundError:
        return None, f"{cmd[0]}: not found"
    except subprocess.TimeoutExpired:
        return None, f"{cmd[0]}: timed out after {timeout}s"
    except Exception as exc:  # noqa: BLE001 — a sampler must not crash on any single subsystem
        return None, f"{cmd[0]}: {exc}"


def sample_qdrant(url, collection):
    endpoint = f"{url}/collections/{collection}"
    try:
        with urllib.request.urlopen(endpoint, timeout=10) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        points = body.get("result", {}).get("points_count")
        return {"collection": collection, "points_count": points, "error": None}
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return {"collection": collection, "points_count": 0, "error": "collection not found yet"}
        return {"collection": collection, "points_count": None, "error": f"HTTP {exc.code}"}
    except Exception as exc:  # noqa: BLE001
        return {"collection": collection, "points_count": None, "error": str(exc)}


def sample_postgres(container, db, user):
    query = (
        "SELECT 'slot:' || slot_name || ':' || active || ':' || "
        "COALESCE(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn), 0) "
        "FROM pg_replication_slots "
        "UNION ALL SELECT 'table:sensor_readings:' || count(*) FROM sensor_readings "
        "UNION ALL SELECT 'table:orders:' || count(*) FROM orders;"
    )
    out, err = run(["docker", "exec", container, "psql", "-U", user, "-d", db, "-tA", "-c", query])
    if err:
        return {"replication_slots": [], "table_counts": {}, "error": err}

    slots = []
    tables = {}
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(":")
        if parts[0] == "slot" and len(parts) == 4:
            _, slot_name, active, retained = parts
            slots.append({
                "slot_name": slot_name,
                "active": active == "t",
                "retained_bytes": int(retained) if retained.isdigit() else None,
            })
        elif parts[0] == "table" and len(parts) == 3:
            _, table, count = parts
            tables[table] = int(count) if count.isdigit() else None

    return {"replication_slots": slots, "table_counts": tables, "error": None}


def parse_mem_usage(text):
    """'123.4MiB / 1.945GiB' -> 123.4 (float, MiB). None if unparsable."""
    try:
        used = text.split("/")[0].strip()
        for unit, factor in (("GiB", 1024.0), ("MiB", 1.0), ("KiB", 1.0 / 1024), ("B", 1.0 / 1024 / 1024)):
            if used.endswith(unit):
                return round(float(used[: -len(unit)]) * factor, 2)
    except Exception:  # noqa: BLE001
        pass
    return None


def sample_containers(prefix):
    names_out, err = run(["docker", "ps", "--format", "{{.Names}}", "--filter", f"name={prefix}"])
    if err:
        return {"_error": err}
    names = [n for n in names_out.splitlines() if n.strip()]
    if not names:
        return {"_error": "no containers matching prefix — stack not running"}

    stats_out, err = run(
        ["docker", "stats", "--no-stream", "--format", "{{.Name}}\t{{.MemUsage}}", *names],
        timeout=30,
    )
    if err:
        return {"_error": err}

    containers = {}
    for line in stats_out.splitlines():
        if "\t" not in line:
            continue
        name, mem = line.split("\t", 1)
        containers[name] = {"rss_mib": parse_mem_usage(mem)}
    return containers


def sample_host():
    result = {"load1": None, "load5": None, "load15": None,
               "ram_available_mib": None, "ram_total_mib": None,
               "gpu": None, "error": None}
    errors = []

    try:
        result["load1"], result["load5"], result["load15"] = os.getloadavg()
    except OSError as exc:
        errors.append(f"loadavg: {exc}")

    try:
        meminfo = {}
        with open("/proc/meminfo", encoding="utf-8") as fh:
            for line in fh:
                key, _, rest = line.partition(":")
                if key in ("MemAvailable", "MemTotal"):
                    meminfo[key] = int(rest.strip().split()[0]) / 1024.0  # kB -> MiB
        result["ram_available_mib"] = meminfo.get("MemAvailable")
        result["ram_total_mib"] = meminfo.get("MemTotal")
    except Exception as exc:  # noqa: BLE001
        errors.append(f"meminfo: {exc}")

    gpu_out, gpu_err = run([
        "nvidia-smi", "--query-gpu=index,memory.used,memory.total",
        "--format=csv,noheader,nounits",
    ], timeout=10)
    if gpu_err:
        errors.append(f"nvidia-smi: {gpu_err}")
    else:
        gpus = []
        for line in gpu_out.splitlines():
            parts = [p.strip() for p in line.split(",")]
            if len(parts) == 3 and all(p.isdigit() for p in parts):
                gpus.append({
                    "index": int(parts[0]),
                    "memory_used_mib": int(parts[1]),
                    "memory_total_mib": int(parts[2]),
                })
        result["gpu"] = gpus

    if errors:
        result["error"] = "; ".join(errors)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seq", type=int, required=True)
    parser.add_argument("--out", default=None, help="JSON-lines file to append to (default: stdout)")
    parser.add_argument("--qdrant-url", default=os.environ.get("NS_QDRANT_URL", "http://localhost:6333"))
    parser.add_argument("--qdrant-collection", default=os.environ.get("NS_QDRANT_COLLECTION", "stream_events"))
    parser.add_argument("--postgres-container", default=os.environ.get("NS_C_POSTGRES", "northstream-source-postgres"))
    parser.add_argument("--postgres-db", default=os.environ.get("NS_PG_DB", "sales"))
    parser.add_argument("--postgres-user", default=os.environ.get("NS_PG_USER", "demo"))
    parser.add_argument("--container-prefix", default=os.environ.get("NS_CONTAINER_PREFIX", "northstream-"))
    args = parser.parse_args()

    sample = {
        "seq": args.seq,
        "ts": now_iso(),
        "qdrant": sample_qdrant(args.qdrant_url, args.qdrant_collection),
        "postgres": sample_postgres(args.postgres_container, args.postgres_db, args.postgres_user),
        "containers": sample_containers(args.container_prefix),
        "host": sample_host(),
    }

    line = json.dumps(sample, sort_keys=True) + "\n"
    if args.out:
        with open(args.out, "a", encoding="utf-8") as fh:
            fh.write(line)
            fh.flush()
            os.fsync(fh.fileno())
    else:
        sys.stdout.write(line)


if __name__ == "__main__":
    main()
