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


def sample_connector(connect_url, connector_name):
    """Kafka Connect REST status for the CDC connector — collected once at
    run start (not per-sample) for the manifest's initial-conditions record.
    Same discipline as everywhere else: unreachable or malformed means null
    fields and an explicit error, never a guessed state."""
    endpoint = f"{connect_url}/connectors/{connector_name}/status"
    try:
        with urllib.request.urlopen(endpoint, timeout=10) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        return {
            "name": connector_name,
            "connector_state": body.get("connector", {}).get("state"),
            "task_states": [t.get("state") for t in body.get("tasks", [])],
            "error": None,
        }
    except urllib.error.HTTPError as exc:
        return {"name": connector_name, "connector_state": None, "task_states": None, "error": f"HTTP {exc.code}"}
    except Exception as exc:  # noqa: BLE001
        return {"name": connector_name, "connector_state": None, "task_states": None, "error": str(exc)}


# The only two values this query can legitimately produce for a slot's
# active flag (see the CASE in the query below, which pins the encoding
# instead of trusting how `active || ':'` happens to stringify a boolean —
# that produced literal 'true'/'false' against real Postgres, not the 't'/'f'
# the parser expected, and a naive `== "t"` comparison then silently reads
# EVERY slot as inactive: a constant masquerading as a measurement, worse
# than a missing field because it looks like real data).
_SLOT_ACTIVE = {"t": True, "f": False}


def sample_postgres(container, db, user):
    query = (
        "SELECT 'slot:' || slot_name || ':' || "
        "(CASE WHEN active THEN 't' WHEN NOT active THEN 'f' ELSE 'u' END) || ':' || "
        "COALESCE(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn), 0) "
        "FROM pg_replication_slots "
        "UNION ALL SELECT 'table:sensor_readings:' || count(*) FROM sensor_readings "
        "UNION ALL SELECT 'table:orders:' || count(*) FROM orders;"
    )
    out, err = run(["docker", "exec", container, "psql", "-U", user, "-d", db, "-tA", "-c", query])
    if err:
        return {"replication_slots": [], "table_counts": {}, "warnings": [], "error": err}

    slots = []
    tables = {}
    warnings = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(":")
        if parts[0] == "slot" and len(parts) == 4:
            _, slot_name, active_raw, retained = parts
            # A value outside the two the query can produce is never coerced
            # to a boolean: it is recorded as unknown, with a warning, so it
            # cannot be mistaken for a real "inactive" reading.
            if active_raw in _SLOT_ACTIVE:
                active = _SLOT_ACTIVE[active_raw]
            else:
                active = None
                warnings.append(f"slot {slot_name}: unrecognized active value {active_raw!r}, recorded as unknown")
            slots.append({
                "slot_name": slot_name,
                "active": active,
                "retained_bytes": int(retained) if retained.isdigit() else None,
            })
        elif parts[0] == "table" and len(parts) == 3:
            _, table, count = parts
            tables[table] = int(count) if count.isdigit() else None
        else:
            warnings.append(f"unrecognized row from replication/count query: {line!r}")

    return {"replication_slots": slots, "table_counts": tables, "warnings": warnings, "error": None}


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
    warnings = []
    for line in stats_out.splitlines():
        if "\t" not in line:
            warnings.append(f"unparsed docker stats line: {line!r}")
            continue
        name, mem = line.split("\t", 1)
        containers[name] = {"rss_mib": parse_mem_usage(mem)}

    # A container docker ps saw but docker stats did not report for is a real
    # gap, not "no data": surface it instead of letting it disappear as if it
    # had never been asked for.
    missing = sorted(set(names) - set(containers))
    if missing:
        warnings.append(f"docker ps listed but docker stats did not report: {missing}")
    if warnings:
        containers["_warnings"] = warnings
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
            if not line.strip():
                continue
            parts = [p.strip() for p in line.split(",")]
            if len(parts) == 3 and all(p.isdigit() for p in parts):
                gpus.append({
                    "index": int(parts[0]),
                    "memory_used_mib": int(parts[1]),
                    "memory_total_mib": int(parts[2]),
                })
            else:
                errors.append(f"nvidia-smi: unparsed gpu line {line!r}")
        result["gpu"] = gpus

    if errors:
        result["error"] = "; ".join(errors)
    return result


def collect_diagnostics(sample):
    """Flatten every subsystem's error/warning into one-line diagnostics, so a
    problem is visible in soak.err.log (run.sh redirects this script's stderr
    there) as soon as it happens rather than discovered by reading 24 hours of
    samples.jsonl after the fact. This is the general form of the "active"
    bug: any silent per-field default is exactly what stays invisible."""
    lines = []
    for section in ("qdrant", "postgres", "host"):
        err = sample[section].get("error")
        if err:
            lines.append(f"{section}: {err}")
    for warning in sample["postgres"].get("warnings", []):
        lines.append(f"postgres: {warning}")
    containers = sample["containers"]
    if "_error" in containers:
        lines.append(f"containers: {containers['_error']}")
    for warning in containers.get("_warnings", []):
        lines.append(f"containers: {warning}")
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["sample", "init"], default="sample",
                         help="'sample' (default): one periodic observation, JSON-lines. "
                              "'init': one-shot pipeline state (connector + replication slot) "
                              "for the manifest's initial conditions — issue #44.")
    parser.add_argument("--seq", type=int, default=0, help="required for --mode sample")
    parser.add_argument("--out", default=None, help="JSON-lines file to append to (default: stdout)")
    parser.add_argument("--qdrant-url", default=os.environ.get("NS_QDRANT_URL", "http://localhost:6333"))
    parser.add_argument("--qdrant-collection", default=os.environ.get("NS_QDRANT_COLLECTION", "stream_events"))
    parser.add_argument("--postgres-container", default=os.environ.get("NS_C_POSTGRES", "northstream-source-postgres"))
    parser.add_argument("--postgres-db", default=os.environ.get("NS_PG_DB", "sales"))
    parser.add_argument("--postgres-user", default=os.environ.get("NS_PG_USER", "demo"))
    parser.add_argument("--container-prefix", default=os.environ.get("NS_CONTAINER_PREFIX", "northstream-"))
    parser.add_argument("--connect-url", default=os.environ.get("NS_CONNECT_URL", "http://localhost:8083"))
    parser.add_argument("--connector-name", default=os.environ.get("NS_CONNECTOR_NAME", "northstream-postgres-connector"))
    args = parser.parse_args()

    if args.mode == "init":
        postgres = sample_postgres(args.postgres_container, args.postgres_db, args.postgres_user)
        init_state = {
            "ts": now_iso(),
            "connector": sample_connector(args.connect_url, args.connector_name),
            "replication_slots": postgres["replication_slots"],
            "table_counts": postgres["table_counts"],
            "postgres_error": postgres["error"],
            "postgres_warnings": postgres["warnings"],
        }
        sys.stdout.write(json.dumps(init_state, sort_keys=True) + "\n")
        return

    sample = {
        "seq": args.seq,
        "ts": now_iso(),
        "qdrant": sample_qdrant(args.qdrant_url, args.qdrant_collection),
        "postgres": sample_postgres(args.postgres_container, args.postgres_db, args.postgres_user),
        "containers": sample_containers(args.container_prefix),
        "host": sample_host(),
    }

    for diagnostic in collect_diagnostics(sample):
        print(f"sample {args.seq}: {diagnostic}", file=sys.stderr)

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
