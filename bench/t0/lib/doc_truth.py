#!/usr/bin/env python3
"""Documentation truth linter (test T0.12).

Checks that the README describes the system that actually exists in the
repository, on the three axes defined in docs/piano_ricovero.md section 4.1:

  (a) every path listed in the README "Repository Layout" block exists;
  (b) no host endpoint listed in the services table is dead with respect to
      the compose files (the port must be published, and a Kafka bootstrap
      endpoint must actually be advertised to host clients);
  (c) the License section agrees with the LICENSE file.

Two extra checks cover the concrete README defects recorded as finding D-2,
which would otherwise have no test of their own:

  (d) no markdown table carries a duplicated header row;
  (e) no unresolved placeholder is left in the instructions.

Usage:
    python3 doc_truth.py [--repo PATH] [--json OUT.json]

Exit code 0 when there are no violations, 1 otherwise.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - reported as a skip by the caller
    print("PyYAML is required (pip install pyyaml)", file=sys.stderr)
    raise SystemExit(2)

COMPOSE_FILES = [
    "docker-compose-northstream-ai.yml",
    "docker-compose.addon.yml",
]

# Ports that belong to the harness itself rather than to the product stack.
IGNORED_PORTS: set[str] = set()


class Violation:
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message

    def as_dict(self) -> dict:
        return {"code": self.code, "message": self.message}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_layout_block(readme: str) -> list[str] | None:
    """Return the lines of the repository-layout code block, if present."""
    lines = readme.splitlines()
    for i, line in enumerate(lines):
        if re.match(r"^#{2,3}\s+.*Repository Layout\s*$", line.strip(), re.IGNORECASE):
            block: list[str] = []
            inside = False
            for candidate in lines[i + 1 :]:
                if candidate.strip().startswith("```"):
                    if inside:
                        return block
                    inside = True
                    continue
                if inside:
                    block.append(candidate)
                elif candidate.startswith("#"):
                    break
            return block if block else None
    return None


def parse_layout_paths(block: list[str]) -> list[str]:
    """Turn the ASCII tree into a list of repository-relative paths.

    Depth comes from the column at which the "+--" marker starts: the tree is
    drawn with a fixed four-column indent per level.
    """
    paths: list[str] = []
    stack: list[str] = []
    for raw in block:
        marker = raw.find("+--")
        if marker < 0:
            continue
        name = raw[marker + 3 :].strip()
        if not name:
            continue
        # Strip trailing comments such as "(existing)" used in some blocks.
        name = re.sub(r"\s*\(.*\)\s*$", "", name).strip()
        if not name or name.startswith("..."):
            continue
        depth = marker // 4
        is_dir = name.endswith("/")
        name = name.rstrip("/")
        # A name may itself carry a path fragment, e.g. "init/postgres/x.sql".
        del stack[depth:]
        full = "/".join(stack + [name])
        paths.append(full + ("/" if is_dir else ""))
        if is_dir:
            stack.append(name)
    return paths


def check_layout(repo: Path, readme: str) -> list[Violation]:
    block = extract_layout_block(readme)
    if block is None:
        return [
            Violation(
                "T0.12-a",
                "README has no 'Repository Layout' block: nothing to verify "
                "(remove the check or restore the block)",
            )
        ]
    violations = []
    for rel in parse_layout_paths(block):
        want_dir = rel.endswith("/")
        target = repo / rel.rstrip("/")
        # The first line of the tree is the project root itself.
        if rel.rstrip("/") in {repo.name, "northstream"}:
            continue
        if not target.exists():
            violations.append(
                Violation(
                    "T0.12-a",
                    f"README layout lists '{rel}' but it does not exist in the repository",
                )
            )
        elif want_dir and not target.is_dir():
            violations.append(
                Violation("T0.12-a", f"README layout lists '{rel}' as a directory but it is a file")
            )
    return violations


def load_compose(repo: Path) -> dict:
    """Merge the compose files the README describes into one service map."""
    services: dict = {}
    for name in COMPOSE_FILES:
        path = repo / name
        if not path.exists():
            continue
        doc = yaml.safe_load(read_text(path)) or {}
        for service, definition in (doc.get("services") or {}).items():
            merged = services.setdefault(service, {})
            merged.update(definition or {})
    return services


def published_ports(services: dict) -> dict[str, str]:
    """Map published host port -> service name."""
    mapping: dict[str, str] = {}
    for service, definition in services.items():
        for entry in definition.get("ports") or []:
            if isinstance(entry, dict):
                host = entry.get("published")
                if host is not None:
                    mapping[str(host)] = service
                continue
            text = str(entry)
            parts = text.split(":")
            if len(parts) >= 2:
                host = parts[-2]
            else:
                host = parts[0]
            host = host.split("/")[0]
            if host.isdigit():
                mapping[host] = service
    return mapping


def kafka_advertises_host(services: dict, port: str) -> bool:
    """True when a host client bootstrapping on localhost:<port> gets usable
    metadata back, i.e. the broker advertises a localhost listener."""
    kafka = services.get("kafka") or {}
    env = kafka.get("environment") or {}
    if isinstance(env, list):
        env = dict(item.split("=", 1) for item in env if "=" in item)
    # KAFKA_CFG_ADVERTISED_LISTENERS was Bitnami's key; the apache/kafka
    # image that replaced it (P-3, issue #17) uses KAFKA_ADVERTISED_LISTENERS.
    # Checking only the old key would make this linter silently blind to the
    # broker's actual behaviour after that migration.
    advertised = str(
        env.get("KAFKA_ADVERTISED_LISTENERS", env.get("KAFKA_CFG_ADVERTISED_LISTENERS", ""))
    )
    return f"localhost:{port}" in advertised or f"127.0.0.1:{port}" in advertised


def check_endpoints(repo: Path, readme: str) -> list[Violation]:
    services = load_compose(repo)
    if not services:
        return [Violation("T0.12-b", "no compose file found: cannot verify the services table")]
    ports = published_ports(services)

    violations = []
    seen: set[str] = set()
    for line in readme.splitlines():
        if not line.strip().startswith("|"):
            continue
        for port in re.findall(r"localhost:(\d+)", line):
            if port in IGNORED_PORTS or port in seen:
                continue
            seen.add(port)
            service = ports.get(port)
            if service is None:
                violations.append(
                    Violation(
                        "T0.12-b",
                        f"services table advertises localhost:{port} but no compose "
                        f"service publishes that port",
                    )
                )
                continue
            if service == "kafka" and not kafka_advertises_host(services, port):
                violations.append(
                    Violation(
                        "T0.12-b",
                        f"services table advertises localhost:{port} for Kafka, but the "
                        f"broker advertises no localhost listener: a host client receives "
                        f"unreachable metadata (finding P-1)",
                    )
                )
    return violations


def check_license(repo: Path, readme: str) -> list[Violation]:
    license_path = repo / "LICENSE"
    if not license_path.exists():
        return []
    first_line = read_text(license_path).splitlines()[0].strip() if read_text(license_path).strip() else ""
    match = re.search(r"^##\s+License\s*$(.*?)(?=^##\s|\Z)", readme, re.MULTILINE | re.DOTALL)
    if not match:
        return [Violation("T0.12-c", "README has no License section but the repository ships a LICENSE file")]
    section = match.group(1)
    violations = []
    if re.search(r"choose the license", section, re.IGNORECASE):
        violations.append(
            Violation(
                "T0.12-c",
                "README License section still asks the reader to choose a license "
                f"while LICENSE says '{first_line}'",
            )
        )
    if first_line.lower().startswith("mit") and "MIT" not in section:
        violations.append(
            Violation("T0.12-c", f"LICENSE is '{first_line}' but the README License section never names it")
        )
    return violations


def check_duplicate_table_headers(readme: str) -> list[Violation]:
    lines = readme.splitlines()
    separator = re.compile(r"^\|[\s:|-]+\|$")
    violations = []
    for i in range(len(lines) - 2):
        if separator.match(lines[i].strip()) and lines[i + 1].strip().startswith("|"):
            if separator.match(lines[i + 2].strip()):
                violations.append(
                    Violation(
                        "T0.12-d",
                        f"markdown table has a duplicated header row at line {i + 2} "
                        f"(renders as a broken table)",
                    )
                )
    return violations


def check_placeholders(readme: str) -> list[Violation]:
    violations = []
    for placeholder in ("<your-repository-url>", "<your-repo-url>", "TODO", "TBD"):
        if placeholder in readme:
            violations.append(
                Violation("T0.12-e", f"README still contains the placeholder '{placeholder}'")
            )
    return violations


def run(repo: Path) -> list[Violation]:
    readme_path = repo / "README.md"
    if not readme_path.exists():
        return [Violation("T0.12", "README.md not found")]
    readme = read_text(readme_path)
    violations: list[Violation] = []
    violations += check_layout(repo, readme)
    violations += check_endpoints(repo, readme)
    violations += check_license(repo, readme)
    violations += check_duplicate_table_headers(readme)
    violations += check_placeholders(readme)
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description="NORTHSTREAM documentation truth linter (T0.12)")
    parser.add_argument("--repo", default=".", help="repository to check (default: current directory)")
    parser.add_argument("--json", dest="json_out", help="write the result as JSON to this file")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    violations = run(repo)

    for violation in violations:
        print(f"{violation.code}: {violation.message}")
    if not violations:
        print("T0.12: no documentation violations found")

    if args.json_out:
        payload = {
            "test": "T0.12",
            "repo": str(repo),
            "violations": [v.as_dict() for v in violations],
            "violation_count": len(violations),
        }
        Path(args.json_out).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    return 1 if violations else 0


if __name__ == "__main__":
    raise SystemExit(main())
