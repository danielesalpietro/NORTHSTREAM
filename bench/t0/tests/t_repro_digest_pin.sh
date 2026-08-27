#!/usr/bin/env bash
# T-REPRO — two `docker compose pull` runs, days apart, resolve the same
#           image digests (P-3, P-4, O3.2; docs/piano_ricovero.md sez. 4.1/6).
#
# An image reference pinned as `repo:tag@sha256:<digest>` makes this true by
# construction: the registry serves that exact content or refuses the pull,
# regardless of when the pull happens. So the property this test can check
# mechanically, without waiting days or needing a Docker daemon, is the one
# that makes the guarantee hold in the first place: every pulled image this
# release touched (P-3, P-4) is referenced by digest, not by a mutable tag
# alone.
#
# Input:  the compose files that declare pulled (non-`build:`) images.
# Expect: every `image:` value naming one of the eight images the review
#         flagged (P-3: bitnamilegacy/kafka; P-4: the seven mobile-tag
#         images) carries an `@sha256:<64 hex chars>` digest.
#
# Scoped to those eight on purpose: other images in these compose files
# (postgres, debezium/connect, flink, trino, openmetadata, elasticsearch,
# the landing page nginx) were never `:latest`/mobile-tag and are not this
# issue's finding — pinning them is a separate, undecided scope expansion,
# not something this test should silently start requiring.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T-REPRO"

files=(
    "$NS_REPO/docker-compose-northstream-ai.yml"
    "$NS_REPO/docker-compose.addon.yml"
)

# Repos named in the review (P-3, P-4). A colon or @ after the repo name
# tells apart e.g. "ollama/ollama" from an unrelated image that merely
# contains that substring.
in_scope_repos=(
    "apache/kafka"
    "provectuslabs/kafka-ui"
    "^adminer:" "^adminer@"
    "minio/minio"
    "minio/mc"
    "qdrant/qdrant"
    "ollama/ollama"
    "ghcr.io/open-webui/open-webui"
)

is_in_scope() {
    local image="$1" pattern
    for pattern in "${in_scope_repos[@]}"; do
        [[ "$image" =~ $pattern ]] && return 0
    done
    return 1
}

missing=()
checked=0
for f in "${files[@]}"; do
    if [[ ! -f "$f" ]]; then
        ns_observe "compose file not found: $f"
        continue
    fi
    while IFS= read -r line; do
        image="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*image:[[:space:]]*//')"
        [[ -z "$image" ]] && continue
        is_in_scope "$image" || continue
        checked=$((checked + 1))
        if [[ "$image" =~ @sha256:[0-9a-f]{64}$ ]]; then
            ns_observe "pinned: $image"
        else
            missing+=("$(basename "$f"): $image")
        fi
    done < <(grep -E '^[[:space:]]*image:[[:space:]]*\S' "$f")
done

ns_observe "images checked: $checked"

# Exactly 8: the count is a fixed fact of the review (P-3 + the 7 of P-4),
# not a moving target. Fewer means a scope pattern stopped matching (a
# rename slipping past silently, turning this into a vacuous PASS); more
# means a new mobile-tag image was added without updating this test's scope.
if (( checked != 8 )); then
    ns_finish "$NS_KO" "expected 8 in-scope images (P-3+P-4), found ${checked} — this test's scope patterns are out of date"
fi

if (( ${#missing[@]} > 0 )); then
    ns_observe "not pinned to a digest: ${missing[*]}"
    ns_finish "$NS_KO" "${#missing[@]} image(s) not pinned to version+digest (P-3, P-4)"
fi

ns_finish "$NS_OK" "all ${checked} pulled images pinned to version+digest: repeated pulls resolve the same content by construction"
