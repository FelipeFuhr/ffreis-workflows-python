"""Command-line interface for the hello example."""

from __future__ import annotations

import argparse
from collections.abc import Sequence

from hello.greeter import greet


def build_parser() -> argparse.ArgumentParser:
    """Create the CLI argument parser."""
    parser = argparse.ArgumentParser(
        prog="hello",
        description="Print a friendly greeting.",
    )
    parser.add_argument(
        "name",
        nargs="?",
        default="world",
        help="Name to greet.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """Run the hello CLI."""
    parser = build_parser()
    args = parser.parse_args(argv)
    print(greet(args.name))
    return 0
