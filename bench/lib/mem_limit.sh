#!/usr/bin/env bash
# Print the mem_limit a compose file declares for a service.
#
# Why this exists: reading a ceiling with `grep -A3 <container_name>` is a trap.
# The container_name (northstream-open-webui) is not the service key (open-webui),
# and the mem_limit sits ten lines below the key, past the -A3 window and behind a
# comment block. That recipe returns nothing for a service that is capped at 1024m,
# and taken at face value it stops a session that is on the right branch.
#
# Three outcomes, kept distinct on purpose (CLAUDE.md section 5: a derived field must
# tell "false" apart from "I could not know"):
#   cap declared      -> prints the value, exit 0
#   service uncapped  -> prints "none", exit 0
#   service not found -> message on stderr, exit 2
#
# Usage: bench/lib/mem_limit.sh <service> [compose-file ...]
set -euo pipefail

service="${1:-}"
if [[ -z "$service" ]]; then
    echo "usage: ${0##*/} <service> [compose-file ...]" >&2
    exit 64
fi
shift

if [[ $# -eq 0 ]]; then
    repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    mapfile -t files < <(find "$repo" -maxdepth 1 -name 'docker-compose*.yml' | sort)
else
    files=("$@")
fi

for file in "${files[@]}"; do
    # A service key is exactly two spaces deep; anything deeper belongs to it.
    if ! grep -qE "^  ${service}:[[:space:]]*$" "$file"; then
        continue
    fi
    cap="$(awk -v svc="$service" '
        $0 ~ "^  " svc ":[[:space:]]*$" { inside = 1; next }
        inside && /^  [^[:space:]#]/    { inside = 0 }
        inside && $1 == "mem_limit:"    { print $2; found = 1; exit }
    ' "$file")"
    if [[ -n "$cap" ]]; then
        echo "$cap"
    else
        echo "none"
    fi
    exit 0
done

echo "${0##*/}: no service '${service}' in: ${files[*]}" >&2
exit 2
