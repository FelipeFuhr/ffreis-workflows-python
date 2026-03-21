"""Property-based tests for the greeter module."""

import pytest
from hypothesis import given
from hypothesis import strategies as st

from hello.greeter import greet


@given(st.text(min_size=1).filter(lambda s: bool(s.strip())))
def test_greet_never_crashes_on_valid_input(name: str) -> None:
    result = greet(name)
    assert result.startswith("Hello,")
    assert result.endswith("!")


@given(st.text().filter(lambda s: not s.strip()))
def test_greet_raises_on_empty_or_whitespace(name: str) -> None:
    with pytest.raises(ValueError):
        greet(name)


@given(st.text(min_size=1).filter(lambda s: bool(s.strip())))
def test_greet_is_deterministic(name: str) -> None:
    assert greet(name) == greet(name)
