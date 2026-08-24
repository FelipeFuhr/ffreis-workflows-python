#!/usr/bin/env python3
"""Extract a workflow step's `run:` script verbatim from a workflow YAML file.

Used by the bats tests in this directory so they exercise the exact script
that ships in .github/workflows/*.yml, rather than a hand-copied duplicate
that could silently drift from what actually runs in CI.
"""

import sys

import yaml


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_step_script.py <workflow.yml> <step-name>", file=sys.stderr)
        return 2

    path, step_name = sys.argv[1], sys.argv[2]
    with open(path, encoding="utf-8") as fh:
        doc = yaml.safe_load(fh)

    for job in doc.get("jobs", {}).values():
        for step in job.get("steps", []):
            if step.get("name") == step_name and "run" in step:
                sys.stdout.write(step["run"])
                return 0

    print(f"step {step_name!r} not found in {path}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
