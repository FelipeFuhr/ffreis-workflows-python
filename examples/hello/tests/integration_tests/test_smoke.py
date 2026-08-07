"""Integration smoke test for the hello example.

Exists so self-test.yml can exercise python-test.yml's
`integration-coverage-min` gate against real pytest output rather than only
the missing-directory skip path. Runs the CLI end-to-end (argument parsing
through stdout) the way a real caller's integration suite would.
"""

import subprocess
import sys

from hello.cli import main


def test_cli_end_to_end_default_name(capsys) -> None:
    exit_code = main([])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out == "Hello, World!\n"


def test_module_entrypoint_via_subprocess() -> None:
    """Exercises `python -m hello` as a real caller would invoke it.

    Runs out-of-process, so it does not count toward this file's own
    pytest-cov measurement — it is here for integration realism, not
    coverage percentage.
    """
    result = subprocess.run(
        [sys.executable, "-m", "hello", "integration"],
        capture_output=True,
        text=True,
        check=True,
    )

    assert result.stdout == "Hello, Integration!\n"
