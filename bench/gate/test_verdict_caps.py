#!/usr/bin/env python3
"""Falsification cases for verdict_caps.py, kept so they cannot be lost.

Every case here corresponds to a defect that shipped and was found by someone
running the verdict against real data rather than reading it. Written down as
a test because a rule corrected in prose gets reintroduced by the next edit --
which is exactly what happened to §4.3.1(d)'s declared exemptions, fixed in
the plan on 28/08 and reintroduced in this script's code two days later.

    red        the 28/08 numbers: elasticsearch pinned at its cap,
               open-webui restarting 3474 times                     -> FAIL (1)
    green      the corrected caps with their measured footprints    -> OK   (0)
    exempt     a run whose only uncapped service is a declared one  -> OK   (0)
    truncated  two samples: the ">=10 consecutive" condition cannot
               even be reached, so a verdict would be green having
               looked at nothing                                    -> UNKNOWN (2)
    unhealthy  a container unhealthy but not restarting: passes every
               condition of §4.3.1(d) and must not read as green    -> UNKNOWN (2)
    foreign    another project's container alive for one sample     -> OK   (0)

Run: python3 bench/gate/test_verdict_caps.py
"""
import json
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
VERDICT = HERE / "verdict_caps.py"


def container(limit, current, peak, restarts=0, health="healthy"):
    return {"restarts": restarts, "status": "running", "health": health,
            "limit_mib": limit, "rss_mib": max(current - 15, 0),
            "current_mib": current, "peak_mib": peak, "oom_killed": False}


def archive(path, samples, containers_for):
    path.mkdir(parents=True, exist_ok=True)
    lines = []
    for i in range(samples):
        lines.append(json.dumps({"seq": i, "ts": f"2026-08-29T19:{39 + i % 20:02d}:31Z",
                                 "containers": containers_for(i)}))
    (path / "samples.jsonl").write_text("\n".join(lines) + "\n")
    return path


def run(path):
    proc = subprocess.run([sys.executable, str(VERDICT), str(path)],
                          capture_output=True, text=True)
    return proc.returncode, proc.stdout


def main():
    tmp = pathlib.Path(tempfile.mkdtemp())
    ollama = container(0, 604.5, 700.0, health="-")
    cases = []

    cases.append(("red", 1, archive(tmp / "red", 46, lambda i: {
        "northstream-elasticsearch": container(1536.0, 1529.0, 1536.0),
        "northstream-open-webui": container(512.0, 138.0, 160.0,
                                            restarts=3474 if i > 3 else 0,
                                            health="starting"),
        "northstream-ollama": ollama,
    })))

    good = lambda i: {
        "northstream-elasticsearch": container(2048.0, 1450.0, 1715.6),
        "northstream-open-webui": container(1024.0, 654.8, 747.3),
        "northstream-ollama": ollama,
    }
    cases.append(("green", 0, archive(tmp / "green", 46, good)))
    cases.append(("exempt", 0, archive(tmp / "exempt", 46, lambda i: {
        "northstream-kafka": container(1536.0, 590.0, 700.0),
        "northstream-ollama": ollama,
    })))
    cases.append(("truncated", 2, archive(tmp / "truncated", 2, good)))
    cases.append(("unhealthy", 2, archive(tmp / "unhealthy", 46, lambda i: {
        "northstream-elasticsearch": container(2048.0, 1450.0, 1715.6, health="unhealthy"),
        "northstream-ollama": ollama,
    })))
    cases.append(("foreign", 0, archive(tmp / "foreign", 46, lambda i: dict(
        good(i), **({"some-other-project-worker": container(256.0, 12.0, 15.0, health="-")}
                    if i == 2 else {})))))

    failures = 0
    for name, want, path in cases:
        got, out = run(path)
        ok = got == want
        failures += 0 if ok else 1
        verdict = next((l for l in out.splitlines() if l.startswith(("VERDICT", "UNKNOWN"))), "?")
        print(f"{'ok  ' if ok else 'FAIL'} {name:<10} exit {got} (want {want})  {verdict.strip()}")

    print()
    if failures:
        print(f"{failures} case(s) did not behave as declared")
        return 1
    print(f"all {len(cases)} falsification cases hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
