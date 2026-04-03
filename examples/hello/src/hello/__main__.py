"""Module entrypoint for ``python -m hello``."""

from hello.cli import main


if __name__ == "__main__":
    raise SystemExit(main())
