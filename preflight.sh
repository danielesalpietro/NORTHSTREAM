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
#
# This is an explicit, separate step — NOT invoked automatically by
# start-addon.sh. See CHANGELOG.md / the Fase 1 logbook for why.
#
# Usage: ./preflight.sh [--tier minimal|recommended|optimal] [--gpu]
# Exit:  0 all checks pass; 1 at least one hard failure (see the messages).
set -uo pipefail

TIER="minimal"
GPU="no"

while (($#)); do
    case "$1" in
        --tier) TIER="$2"; shift 2 ;;
        --gpu)  GPU="yes"; shift ;;
        -h|--help)
            sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

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
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
fi

echo
if (( fail )); then
    echo "preflight FAILED — fix the FAIL line(s) above before starting the stack." >&2
    exit 1
fi
echo "preflight OK — this host meets the requirements for tier '${TIER}'."
