"""Unit tests for the hello CLI."""

from hello.cli import main


def test_main_defaults_to_world(capsys) -> None:
    exit_code = main([])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out == "Hello, World!\n"


def test_main_accepts_name_argument(capsys) -> None:
    exit_code = main(["felipe"])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert captured.out == "Hello, Felipe!\n"
