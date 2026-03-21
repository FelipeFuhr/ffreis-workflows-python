"""Unit tests for the greeter module."""

import pytest

from hello.greeter import greet


def test_greet_simple() -> None:
    assert greet("world") == "Hello, World!"


def test_greet_strips_whitespace() -> None:
    assert greet("  alice  ") == "Hello, Alice!"


def test_greet_title_case() -> None:
    assert greet("john doe") == "Hello, John Doe!"


def test_greet_single_char() -> None:
    assert greet("x") == "Hello, X!"


def test_greet_empty_raises() -> None:
    with pytest.raises(ValueError, match="empty"):
        greet("")


def test_greet_whitespace_only_raises() -> None:
    with pytest.raises(ValueError):
        greet("   ")


def test_greet_tab_whitespace_raises() -> None:
    with pytest.raises(ValueError):
        greet("\t\n")
