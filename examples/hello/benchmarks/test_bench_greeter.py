"""Benchmarks for the greeter module."""

from hello.greeter import greet
from pytest_benchmark.fixture import BenchmarkFixture


def test_greet_short_name(benchmark: BenchmarkFixture) -> None:
    result = benchmark(greet, "alice")
    assert result == "Hello, Alice!"


def test_greet_long_name(benchmark: BenchmarkFixture) -> None:
    result = benchmark(greet, "john fitzgerald kennedy")
    assert result == "Hello, John Fitzgerald Kennedy!"
