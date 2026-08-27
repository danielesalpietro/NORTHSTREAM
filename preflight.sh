#!/usr/bin/env bash
# NORTHSTREAM preflight: fails fast, with an actionable message, on a host
# that would otherwise let a container die in a bootstrap loop ten minutes
# in (P-6) instead of telling you why before you start (issue #19).
#
# Checks:
#   - vm.max_map_count >= 262144   (Elasticsearch / OpenMetadata bootstrap)
#   - available RAM  >= tier floor (README hardware table)
#   - free disk      >= tier floor (same table, current directory's filesystem)
#   - an existing kafka_data volume is writable by apache/kafka's user (P-11)
#   - no root-owned/unwritable directories in the repo tree (P-12, P-13)
#   - NVIDIA GPU visible, only with --gpu (mirrors start-addon.sh --gpu)
#   - host exclusivity, only with --gpu (issue #44): is the GPU ours alone,
#     is there enough RAM actually free (not just installed)? ENV-W is
#     rented out on vast.ai outside maintenance windows, and a tenant's
#     process is otherwise indistinguishable from a defect in this project.
#
# This is an explicit, separate step — NOT invoked automatically by
# start-addon.sh. See CHANGELOG.md / the Fase 1 logbook for why.
#
# Usage: ./preflight.sh [--tier minimal|recommended|optimal] [--gpu]
#                        [--require-vram-mib N] [--require-ram-mib N]
#                        [--allow-contention]
#
# --require-vram-mib N   declare how much free VRAM this run needs (issue
#                         #44); only checked with --gpu. Not inferred from
#                         --tier: the examples/*/.env model choice is a
#                         separate decision from what preflight enforces, and
#                         a fabricated default would be a number nobody
#                         actually declared. Default 0 — no requirement
#                         declared, GPU exclusivity is reported, not gated.
# --require-ram-mib N     declare how much RAM must actually be free (not
#                         just installed) for this run to start. Default 0 —
#                         same reasoning as above.
# --allow-contention      start anyway on a host that looks shared. For a
#                         run that is deliberately insensitive to resource
#                         contention (issue #44) — a deliberate override,
#                         never a silent one: every use is logged as WARN.
#
# Exit:  0 all checks pass; 1 at least one hard failure (see the messages).
set -uo pipefail

TIER="minimal"
GPU="no"
REQUIRE_VRAM_MIB=0
REQUIRE_RAM_MIB=0
ALLOW_CONTENTION="no"

while (($#)); do
    case "$1" in
        --tier)               TIER="$2"; shift 2 ;;
        --gpu)                GPU="yes"; shift ;;
        --require-vram-mib)   REQUIRE_VRAM_MIB="$2"; shift 2 ;;
        --require-ram-mib)    REQUIRE_RAM_MIB="$2"; shift 2 ;;
        --allow-contention)   ALLOW_CONTENTION="yes"; shift ;;
        -h|--help)
            sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$REQUIRE_VRAM_MIB" in ''|*[!0-9]*) echo "--require-vram-mib wants an integer (got: $REQUIRE_VRAM_MIB)" >&2; exit 2 ;; esac
case "$REQUIRE_RAM_MIB" in ''|*[!0-9]*) echo "--require-ram-mib wants an integer (got: $REQUIRE_RAM_MIB)" >&2; exit 2 ;; esac

# Floors mirror the hardware table in README.md ("Hardware & Model Tiers"):
# keep the two in sync if the table ever changes.
case "$TIER" in
    minimal)     RAM_GB=16; DISK_GB=30 ;;
    recommended) RAM_GB=32; DISK_GB=50 ;;
    optimal)     RAM_GB=32; DISK_GB=80 ;;
    *) echo "unknown tier: $TIER (use minimal, recommended or optimal)" >&2; exit 2 ;;
esac

fail=0
warn() { printf 'WARN  %s\n' "$*" >&2; }
err()  { printf 'FAIL  %s\n' "$*" >&2; fail=1; }
ok()   { printf 'OK    %s\n' "$*"; }
info() { printf 'INFO  %s\n' "$*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- vm.max_map_count (P-6): the first cause of "Elasticsearch never
# becomes healthy" on native Linux, where Docker does not preset it the way
# Docker Desktop/WSL2 do. ---
if [[ -r /proc/sys/vm/max_map_count ]]; then
    current="$(cat /proc/sys/vm/max_map_count)"
    if (( current >= 262144 )); then
        ok "vm.max_map_count=${current} (>= 262144)"
    else
        err "vm.max_map_count=${current} is below the 262144 Elasticsearch requires. Fix: sudo sysctl -w vm.max_map_count=262144  (persist across reboots: echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-northstream.conf)"
    fi
else
    warn "vm.max_map_count not readable on this host — expected on native Windows without WSL2, where Docker Desktop's own VM presets it. Skipping."
fi

# --- RAM available vs the chosen tier ---
total_kb=""
if [[ -r /proc/meminfo ]]; then
    total_kb="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
elif command -v sysctl >/dev/null 2>&1; then
    total_bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"
    [[ -n "$total_bytes" ]] && total_kb=$(( total_bytes / 1024 ))
fi
if [[ -n "$total_kb" ]]; then
    total_gb=$(( total_kb / 1024 / 1024 ))
    if (( total_gb >= RAM_GB )); then
        ok "RAM: ${total_gb} GiB (>= ${RAM_GB} GiB for tier '${TIER}')"
    else
        err "RAM: ${total_gb} GiB is below the ${RAM_GB} GiB the '${TIER}' tier needs (README hardware table). The stack may still start but is likely to OOM under load."
    fi
else
    warn "could not read total RAM on this host — skipping (README hardware table wants ${RAM_GB} GiB for tier '${TIER}')"
fi

# --- RAM actually free right now (issue #44) — a different fact from total
# RAM above: a host with plenty of installed RAM can still have most of it
# claimed by a vast.ai tenant. Only gated when the caller declares a need
# (--require-ram-mib); otherwise this is descriptive, not a fabricated gate. ---
if [[ -r /proc/meminfo ]]; then
    avail_ram_kb="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
    if [[ -n "$avail_ram_kb" ]]; then
        avail_ram_mib=$(( avail_ram_kb / 1024 ))
        if (( REQUIRE_RAM_MIB > 0 )); then
            if (( avail_ram_mib >= REQUIRE_RAM_MIB )); then
                ok "RAM free: ${avail_ram_mib} MiB (>= ${REQUIRE_RAM_MIB} MiB declared with --require-ram-mib)"
            elif [[ "$ALLOW_CONTENTION" == "yes" ]]; then
                warn "RAM free: ${avail_ram_mib} MiB is below the ${REQUIRE_RAM_MIB} MiB this run declared it needs — starting anyway (--allow-contention)."
            else
                err "RAM free: only ${avail_ram_mib} MiB available; this run declared it needs ${REQUIRE_RAM_MIB} MiB free (--require-ram-mib). The host looks shared with another workload. Free RAM first, lower --require-ram-mib if the number was a guess, or pass --allow-contention to start anyway."
            fi
        else
            info "RAM free: ${avail_ram_mib} MiB (no --require-ram-mib declared — descriptive only)"
        fi
    else
        warn "could not read MemAvailable from /proc/meminfo — skipping the RAM-free check"
    fi
else
    warn "/proc/meminfo not readable — skipping the RAM-free check (expected on native Windows/macOS)"
fi

# --- load average (issue #44): descriptive only. No threshold is declared
# anywhere in the plan for "this load average means a shared host" — printing
# an invented one would be exactly the "constant dressed up as a measurement"
# CLAUDE.md section 5 warns against, so this is reported, never gated. ---
if [[ -r /proc/loadavg ]]; then
    load1="$(awk '{print $1}' /proc/loadavg)"
    cores="$(nproc 2>/dev/null || echo '?')"
    info "load average: ${load1} (1 min) on ${cores} core(s) — descriptive, no threshold declared"
fi

# --- free disk on the filesystem preflight.sh is run from (a proxy for
# where Docker will store images and volumes — exact only if you run this
# from the same filesystem as your Docker data-root). ---
avail_kb="$(df -Pk . 2>/dev/null | awk 'NR==2{print $4}')"
if [[ -n "${avail_kb:-}" ]]; then
    avail_gb=$(( avail_kb / 1024 / 1024 ))
    if (( avail_gb >= DISK_GB )); then
        ok "free disk: ${avail_gb} GiB (>= ${DISK_GB} GiB for tier '${TIER}')"
    else
        err "free disk: ${avail_gb} GiB is below the ${DISK_GB} GiB the '${TIER}' tier needs for images and volumes."
    fi
else
    warn "could not read free disk space — skipping"
fi

# --- kafka_data volume vs apache/kafka's user (P-11) ---
# bitnamilegacy/kafka:3.7.1 ran as uid=1001 gid=0(root); apache/kafka:4.3.1
# (#17) runs as uid=1000(appuser) gid=1000. A kafka_data volume already
# populated by the old image is left 0:0 mode 775 — writable by the group
# root the old broker belonged to, not by the new one's gid 1000. The
# broker's own error in that state (AccessDeniedException on a checkpoint
# file, tens of restarts) never mentions permissions or the image change.
# This cannot be caught by CI: every ci-smoke/ci-nightly run starts from a
# volume that does not exist yet, i.e. the one case that always works.
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    kafka_vol="$(docker volume ls \
        --filter 'label=com.docker.compose.project=wap-northstream-lab' \
        --filter 'label=com.docker.compose.volume=kafka_data' \
        --format '{{.Name}}' 2>/dev/null | head -1)"
    if [[ -z "$kafka_vol" ]]; then
        ok "no pre-existing kafka_data volume — nothing to migrate (P-11 does not apply to a fresh install)"
    else
        probe_out="$(docker run --rm --user 1000:1000 -v "${kafka_vol}:/check" busybox \
            sh -c 'touch /check/.preflight-write-test && rm -f /check/.preflight-write-test' 2>&1)"
        probe_status=$?
        if (( probe_status == 0 )); then
            ok "kafka_data volume (${kafka_vol}) is writable by uid 1000 (apache/kafka's user)"
        elif printf '%s' "$probe_out" | grep -qi 'permission denied'; then
            err "kafka_data volume (${kafka_vol}) is NOT writable by uid 1000 (apache/kafka's user, since #17/P-3). This volume was populated by the old bitnamilegacy/kafka image (uid 1001, gid 0) and the new one (uid 1000, gid 1000) cannot write to it — the broker will crash-loop with 'AccessDeniedException' on a checkpoint file, with no mention of permissions in the error. This data is a disposable local cache, not something to preserve: remove it and let the new image recreate it — 'docker volume rm ${kafka_vol}' (stack stopped), or 'docker compose down -v' for a full reset."
        else
            warn "could not verify kafka_data volume (${kafka_vol}) ownership (P-11): ${probe_out}"
        fi
    fi
elif command -v docker >/dev/null 2>&1; then
    warn "docker CLI present but daemon not reachable — cannot check the kafka_data volume for P-11"
else
    warn "docker not available — cannot check the kafka_data volume for P-11"
fi

# --- root-owned/unwritable directories in the repo tree (P-12, P-13) ---
# Same mechanism as P-11, seen from a third side: Docker running as root
# can auto-create a bind-mount target (e.g. trino/catalog, which does not
# exist in the repository) as root:root. On a workspace that is wiped every
# run this only breaks the *next* run's checkout (P-12); on a checkout
# someone actually keeps and updates, it breaks 'git pull'/'git checkout'
# outright with Permission denied, leaving the tree half-updated (P-13).
# Scoped to directories: that is what actually blocks git and rmdir — a
# read-only *file* the current user still owns does not.
mapfile -t unwritable_dirs < <(find "$REPO_ROOT" -type d -not -writable 2>/dev/null)
if (( ${#unwritable_dirs[@]} == 0 )); then
    ok "no root-owned or otherwise unwritable directories in the repository tree"
else
    bad_list="$(printf '%s, ' "${unwritable_dirs[@]}")"
    bad_list="${bad_list%, }"
    err "not writable by the current user ($(id -un)): ${bad_list}. Docker most likely created this as root — the same mechanism as P-11/P-12: a container running as root auto-created a bind-mount target that did not exist. Left in place, this breaks 'git pull'/'git checkout' with Permission denied and leaves the working tree half-updated (P-13). This is Docker-managed state, not something to preserve: remove it with 'sudo rm -rf <path>' for each path above, then re-run this preflight."
fi

# --- GPU, only when --gpu was requested (mirrors start-addon.sh --gpu) ---
if [[ "$GPU" == "yes" ]]; then
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        ok "GPU: $(nvidia-smi -L | head -1)"
    else
        err "GPU: --gpu was requested but 'nvidia-smi' is not available or reports no device. Install the NVIDIA driver (in WSL2: the NVIDIA driver for WSL, not a separate in-distro driver) before passing --gpu to start-addon.sh."
    fi

    # --- GPU exclusivity (issue #44): before the stack starts, nothing of
    # ours should be on the GPU yet, so any usage/compute process this finds
    # is by construction not ours — no container attribution needed here
    # (bench/lib/gpu_exclusivity.py still does it, for reuse during a run in
    # bench/t0/run.sh, where our own containers legitimately use the GPU).
    if command -v python3 >/dev/null 2>&1; then
        excl_json="$(python3 "$REPO_ROOT/bench/lib/gpu_exclusivity.py" 2>/dev/null || true)"
        if [[ -z "$excl_json" ]]; then
            warn "GPU exclusivity (#44): bench/lib/gpu_exclusivity.py produced no output — skipping"
        else
            read -r excl_state excl_free excl_foreign excl_fcount excl_reason < <(NS_EXCL_JSON="$excl_json" python3 -c '
import json, os
d = json.loads(os.environ["NS_EXCL_JSON"])
free = d["gpu_free_mib"] if d["gpu_free_mib"] is not None else "?"
foreign = d["foreign_used_mib"] if d["foreign_used_mib"] is not None else "?"
count = d["foreign_process_count"] if d["foreign_process_count"] is not None else "?"
print(d["state"], free, foreign, count, d["reason"].replace(" ", "_"))
')
            excl_reason="${excl_reason//_/ }"
            case "$excl_state" in
                unknown)
                    warn "GPU exclusivity (#44): could not be determined — ${excl_reason}. Not treated as contention, only as an unmeasured host."
                    ;;
                exclusive)
                    ok "GPU exclusivity (#44): exclusive — ${excl_reason}"
                    ;;
                shared)
                    if (( REQUIRE_VRAM_MIB > 0 )) && [[ "$excl_free" != "?" ]] && (( excl_free < REQUIRE_VRAM_MIB )); then
                        if [[ "$ALLOW_CONTENTION" == "yes" ]]; then
                            warn "GPU exclusivity (#44): shared — ${excl_free} MiB free, ${excl_foreign} MiB held by ${excl_fcount} foreign process(es); this run declared it needs ${REQUIRE_VRAM_MIB} MiB. Starting anyway (--allow-contention)."
                        else
                            err "GPU exclusivity (#44): ${excl_foreign} MiB of ${excl_fcount} foreign process(es) occupy the GPU, leaving ${excl_free} MiB free — this run declared it needs ${REQUIRE_VRAM_MIB} MiB (--require-vram-mib) and will not fit. Wait for the tenant to release the GPU, lower the model/tier, or pass --allow-contention to force a run that does not need the memory it asked for."
                        fi
                    else
                        note="no --require-vram-mib declared, reporting only"
                        (( REQUIRE_VRAM_MIB > 0 )) && note="free VRAM (${excl_free} MiB) still covers the ${REQUIRE_VRAM_MIB} MiB this run declared"
                        warn "GPU exclusivity (#44): shared — ${excl_reason} (${note})"
                    fi
                    ;;
                *)
                    warn "GPU exclusivity (#44): unrecognized state '${excl_state}' from gpu_exclusivity.py — treating as unknown"
                    ;;
            esac
        fi
    else
        warn "python3 not available — skipping GPU exclusivity check (#44)"
    fi
fi

echo
if (( fail )); then
    echo "preflight FAILED — fix the FAIL line(s) above before starting the stack." >&2
    exit 1
fi
echo "preflight OK — this host meets the requirements for tier '${TIER}'."
