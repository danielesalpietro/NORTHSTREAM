#!/usr/bin/env python3
"""Memory-ceiling provenance linter (test T0.13).

Every `mem_limit` in the compose files must be traceable to a measurement, and
every service that deliberately has none must say why.

The rule exists because v0.0.3 -- the release whose whole subject was being
honest about resources -- shipped two ceilings set below the footprint the
service actually needed. open-webui restarted 3474 times in 7.4 hours under a
512m cap it needed 680 MiB to clear; elasticsearch sat at 99.5% of a 1536m cap
that was exactly its heap plus its direct memory, with nothing left for
anything else. Both were reasoned about carefully and neither was measured,
and the reasoning read as sound right up until a real stack ran.

So the check is not "is the number right" -- no linter can know that. It is
"does this number cite where it came from", which is the property that would
have caught both: a ceiling with no measurement behind it is a guess, and a
guess should be visible as one.

A ceiling is considered sourced when the comment block directly above it
carries a figure with a memory unit, or names a measurement (misurat*,
measured, soak, T-PROF, a RUN_ID). A service with no mem_limit is considered
deliberate when its comment says so -- the same declared-exemption rule as
docs/piano_ricovero.md §4.3.1(d), which exists so that "we decided not to cap
this" stays distinguishable from "we forgot".

Exit 0 when every ceiling is sourced, 1 when any is not, 2 on a usage error.
"""
import pathlib
import re
import sys

SERVICE_RE = re.compile(r"^  ([a-zA-Z0-9._-]+):\s*$")
TOP_RE = re.compile(r"^([a-zA-Z0-9._-]+):\s*$")
LIMIT_RE = re.compile(r"^\s*mem_limit:\s*(\S+)")
# A figure with a unit, or a word that names where the figure came from.
SOURCED_RE = re.compile(
    r"\d[\d.,\s]*\s*(?:MiB|GiB|MB|GB)\b"
    r"|misurat|measured|soak|T-PROF|20\d{6}-\d{4}-env",
    re.IGNORECASE,
)
DELIBERATE_RE = re.compile(
    r"on purpose|deliberate|di proposito|no mem_limit here|senza tetto",
    re.IGNORECASE,
)


def comment_block_above(lines, index):
    """The unbroken run of comment lines directly above lines[index]."""
    out, i = [], index - 1
    while i >= 0 and lines[i].strip().startswith("#"):
        out.insert(0, lines[i].strip().lstrip("#").strip())
        i -= 1
    return " ".join(out)


def audit(path):
    """Returns (sourced, violations) for one compose file."""
    lines = path.read_text(encoding="utf-8").splitlines()
    service, sourced, violations = None, [], []
    seen_limit = set()

    # Only entries under the top-level `services:` key are services. Without
    # this, `volumes:` and `networks:` members read as uncapped services and
    # the linter reports six violations that do not exist -- a wrong answer
    # that looks plausible, which is the kind this project keeps meeting.
    section = None
    in_services = [False] * len(lines)
    for i, line in enumerate(lines):
        top = TOP_RE.match(line)
        if top:
            section = top.group(1)
        in_services[i] = (section == "services")

    for i, line in enumerate(lines):
        if not in_services[i]:
            continue
        match = SERVICE_RE.match(line)
        if match:
            service = match.group(1)
            continue
        limit = LIMIT_RE.match(line)
        if not limit or service is None:
            continue
        seen_limit.add(service)
        context = comment_block_above(lines, i)
        if SOURCED_RE.search(context):
            sourced.append(f"{path.name}:{service}")
        else:
            violations.append(
                f"{path.name}:{i + 1}: {service} declares mem_limit {limit.group(1)} "
                f"with no measurement cited above it"
            )

    # Services with no ceiling at all: deliberate only if they say so.
    for i, line in enumerate(lines):
        if not in_services[i]:
            continue
        match = SERVICE_RE.match(line)
        if not match or match.group(1) in seen_limit:
            continue
        name = match.group(1)
        block = comment_block_above(lines, i)
        # also look a few lines into the service body for the explanation
        body = " ".join(l.strip().lstrip("#").strip()
                        for l in lines[i + 1:i + 12] if l.strip().startswith("#"))
        if not DELIBERATE_RE.search(block + " " + body):
            violations.append(
                f"{path.name}:{i + 1}: {name} has no mem_limit and no comment "
                f"saying that is deliberate"
            )
    return sourced, violations


def main(argv):
    root = pathlib.Path(argv[1]) if len(argv) > 1 else pathlib.Path(__file__).resolve().parents[3]
    files = sorted(root.glob("docker-compose*.yml"))
    if not files:
        print(f"T0.13: no compose files under {root}", file=sys.stderr)
        return 2

    sourced, violations = [], []
    for path in files:
        s, v = audit(path)
        sourced += s
        violations += v

    if violations:
        print(f"T0.13: {len(violations)} ceiling(s) without a measurement behind them, "
              f"{len(sourced)} sourced")
        for line in violations:
            print(f"  {line}")
        return 1
    print(f"T0.13: all {len(sourced)} memory ceilings cite a measurement")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
