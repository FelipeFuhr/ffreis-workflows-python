"""Benchmarks for the greeter module."""

from hello.greeter import greet


def test_greet_short_name(benchmark: object) -> None:
    result = benchmark(greet, "alice")  # type: ignore[operator]
    assert result == "Hello, Alice!"


def test_greet_long_name(benchmark: object) -> None:
    result = benchmark(greet, "john fitzgerald kennedy")  # type: ignore[operator]
    assert result == "Hello, John Fitzgerald Kennedy!"
