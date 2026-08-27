#!/usr/bin/env bash
# T0.1 — every documented compose combination is syntactically valid.
# Input:  the three compose files of the repository under test.
# Expect: `docker compose config -q` exits 0 for base, base+addon, base+addon+gpu.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.1"

ns_have_docker || ns_finish "$NS_SKIP" "docker CLI not available"

base="docker-compose-northstream-ai.yml"
addon="docker-compose.addon.yml"
gpu="docker-compose.gpu.yml"

for f in "$base" "$addon" "$gpu"; do
    [[ -f "$NS_REPO/$f" ]] || ns_finish "$NS_KO" "missing compose file: $f"
done

failures=0
run_config() {
    local label="$1"; shift
    local output
    if output="$(cd "$NS_REPO" && docker compose "$@" config -q 2>&1)"; then
        ns_observe "$label: exit 0"
    else
        ns_observe "$label: FAILED -> ${output//$'\n'/ }"
        failures=$((failures + 1))
    fi
}

run_config "base" -f "$base"
run_config "base+addon" -f "$base" -f "$addon"
run_config "base+addon+gpu" -f "$base" -f "$addon" -f "$gpu"

if ((failures == 0)); then
    ns_finish "$NS_OK" "all 3 compose combinations validate"
fi
ns_finish "$NS_KO" "$failures compose combination(s) failed validation"
