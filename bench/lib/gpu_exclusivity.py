#!/usr/bin/env python3
"""
NORTHSTREAM GPU exclusivity snapshot — issue #44.

One-shot answer to "is this host's GPU exclusively ours right now?", shared by
preflight.sh (pre-check, before the stack starts) and bench/t0/run.sh
(run-check, sampled between tests). Same discipline as bench/soak/lib/sample.py
on feature/soak-harness: a subsystem that cannot be reached reports null
fields and an explicit error, never a guessed state — CLAUDE.md section 5's
rule against a boolean that collapses "false" and "don't know" into the same
value.

State values:
  "unknown"   — nvidia-smi (or docker, when attribution is needed) is not
                available/reachable: we genuinely cannot tell. This is a
                different fact from "shared", not a synonym for it — e.g. a
                host with no GPU at all is "unknown" for GPU exclusivity, not
                "shared".
  "exclusive" — GPU reachable, no GPU compute process found that this compose
                project cannot account for.
  "shared"    — GPU reachable, at least one process using VRAM cannot be
                attributed to this compose project's own containers.

Attribution: a GPU compute process's container is identified by matching the
64-hex container id in /proc/<pid>/cgroup (present in both cgroup v1's
/docker/<id> and cgroup v2's docker-<id>.scope) against 'docker ps --no-trunc'
for this compose project's label. A process whose id cannot be resolved this
way (no cgroup match, or /proc unreadable — e.g. a bare vast.ai tenant process
outside any of our containers) is treated as foreign, not silently ignored.

Usage:
  gpu_exclusivity.py [--project LABEL]
Prints one JSON object to stdout. Exit code is always 0: this is a
measurement, not a gate — preflight.sh and run.sh each decide what a
"shared" or "unknown" result means for the caller.
"""

import argparse
import json
import re
import subprocess
import sys

TIMEOUT = 10

# The two verified 'clean' baselines in docs/runs/ (20260827-1115-...,
# 20260827-1148-...) both read 9 MiB used with zero compute processes. This
# is headroom for driver/desktop overhead, not a fabricated threshold: it
# only ever matters on the fallback path where per-process attribution
# itself is unavailable (see snapshot()).
CLEAN_EPSILON_MIB = 64

_CGROUP_ID_RE = re.compile(r"[0-9a-f]{64}")


def run(cmd, timeout=TIMEOUT):
    """subprocess.run wrapper: returns (stdout, None) or (None, error string)."""
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
        if proc.returncode != 0:
            return None, (proc.stderr or proc.stdout or f"exit {proc.returncode}").strip()[:500]
        return proc.stdout, None
    except FileNotFoundError:
        return None, f"{cmd[0]}: not found"
    except subprocess.TimeoutExpired:
        return None, f"{cmd[0]}: timed out after {timeout}s"
    except Exception as exc:  # noqa: BLE001 — a sampler must not crash on any single subsystem
        return None, f"{cmd[0]}: {exc}"


def gpu_memory_totals():
    """Per-device readings, plus the sums.

    Returns (devices, used, total, error) where devices is a list of
    {index, name, used_mib, total_mib, free_mib}.

    The per-device list is not decoration. ENV-W went from one GPU to two on
    2026-08-29, and a model does not run on the SUM of the free memory: with a
    tenant holding 22 GiB of a 24 GiB card and a second 16 GiB card idle, the
    sum says 18 GiB free while no single device can hold a 19 GiB model. A
    capacity check against the sum is a false green, so callers deciding
    whether a run fits must use max(free_mib) over the devices, not the sum.
    The sums stay because "how loaded is this host" is a different, still
    useful question from "will my model fit".
    """
    out, err = run(["nvidia-smi",
                    "--query-gpu=index,name,memory.used,memory.total",
                    "--format=csv,noheader,nounits"])
    if err:
        return None, None, None, err
    devices = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != 4 or not (parts[0].isdigit() and parts[2].isdigit() and parts[3].isdigit()):
            return None, None, None, f"unparsed nvidia-smi line: {line!r}"
        used_mib, total_mib = int(parts[2]), int(parts[3])
        devices.append({"index": int(parts[0]), "name": parts[1],
                        "used_mib": used_mib, "total_mib": total_mib,
                        "free_mib": total_mib - used_mib})
    if not devices:
        return None, None, None, "nvidia-smi returned no GPU lines"
    return (devices,
            sum(d["used_mib"] for d in devices),
            sum(d["total_mib"] for d in devices),
            None)


def gpu_compute_processes():
    out, err = run(["nvidia-smi", "--query-compute-apps=pid,used_memory", "--format=csv,noheader,nounits"])
    if err:
        return None, err
    procs = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != 2 or not all(p.isdigit() for p in parts):
            return None, f"unparsed compute-apps line: {line!r}"
        procs.append({"pid": int(parts[0]), "used_mib": int(parts[1])})
    return procs, None


def our_container_ids(project_label):
    out, err = run(["docker", "ps", "-q", "--no-trunc", "--filter", f"label=com.docker.compose.project={project_label}"])
    if err:
        return None, err
    return {line.strip() for line in out.splitlines() if line.strip()}, None


def container_id_for_pid(pid):
    try:
        with open(f"/proc/{pid}/cgroup", encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        return None, str(exc)
    match = _CGROUP_ID_RE.search(text)
    return (match.group(0) if match else None), None


def snapshot(project_label):
    result = {
        "state": "unknown",
        "reason": None,
        "gpu_used_mib": None,
        "gpu_total_mib": None,
        "gpu_free_mib": None,
        "gpu_devices": None,
        "gpu_count": None,
        "gpu_max_free_single_device_mib": None,
        "foreign_used_mib": None,
        "foreign_process_count": None,
        "docker_attribution": None,
        "errors": [],
    }

    devices, used, total, err = gpu_memory_totals()
    if err:
        result["reason"] = f"nvidia-smi unavailable ({err}) — not applicable on this host, not evidence of contention"
        return result
    result["gpu_used_mib"], result["gpu_total_mib"] = used, total
    result["gpu_free_mib"] = total - used
    result["gpu_devices"] = devices
    result["gpu_count"] = len(devices)
    # What a single model can actually get. Compare capacity requirements
    # against this, never against gpu_free_mib -- see gpu_memory_totals().
    result["gpu_max_free_single_device_mib"] = max(d["free_mib"] for d in devices)

    procs, err = gpu_compute_processes()
    if err:
        result["errors"].append(f"nvidia-smi --query-compute-apps: {err}")
        # Total usage is known but per-process attribution is not: only the
        # near-zero case can still be called exclusive (nothing measurable to
        # attribute to anyone). Above that we genuinely cannot tell whose it
        # is, so the state stays "unknown" rather than guessing "shared".
        if used <= CLEAN_EPSILON_MIB:
            result["state"] = "exclusive"
            result["reason"] = f"GPU memory used ({used} MiB) is at the clean baseline and per-process attribution is unavailable, so there is nothing to attribute"
        else:
            result["reason"] = f"{used} MiB of GPU memory in use but per-process attribution is unavailable — cannot rule out a foreign tenant"
        return result

    ours, err = our_container_ids(project_label)
    if err:
        result["errors"].append(f"docker: {err}")
        result["docker_attribution"] = "unavailable"
        if not procs:
            if used <= CLEAN_EPSILON_MIB:
                result["state"] = "exclusive"
                result["reason"] = f"GPU memory used ({used} MiB) at the clean baseline, no compute processes listed"
            else:
                result["reason"] = f"{used} MiB of GPU memory in use, no compute process listed, and docker is unreachable to attribute it"
        else:
            result["reason"] = f"docker unreachable — cannot attribute {len(procs)} GPU compute process(es) to this compose project"
        return result

    result["docker_attribution"] = "ok"
    foreign = []
    unattributable = []
    for proc in procs:
        cid, cerr = container_id_for_pid(proc["pid"])
        if cerr:
            unattributable.append({**proc, "error": cerr})
            continue
        if cid is None or cid not in ours:
            foreign.append(proc)

    result["foreign_process_count"] = len(foreign) + len(unattributable)
    result["foreign_used_mib"] = sum(p["used_mib"] for p in foreign) + sum(p["used_mib"] for p in unattributable)
    if unattributable:
        detail = "; ".join(f"pid {p['pid']}: {p['error']}" for p in unattributable)
        result["errors"].append(
            f"{len(unattributable)} GPU compute process(es) could not be matched to a container and are counted as foreign: {detail}"
        )

    if result["foreign_process_count"] == 0:
        result["state"] = "exclusive"
        result["reason"] = f"{len(procs)} GPU compute process(es), all attributed to this compose project's own containers"
    else:
        result["state"] = "shared"
        result["reason"] = (
            f"{result['foreign_process_count']} GPU compute process(es) not attributable to this compose project, "
            f"using {result['foreign_used_mib']} MiB"
        )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--project",
        default="wap-northstream-lab",
        help="docker compose project label treated as 'ours' (default: wap-northstream-lab)",
    )
    args = parser.parse_args()
    print(json.dumps(snapshot(args.project), sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
