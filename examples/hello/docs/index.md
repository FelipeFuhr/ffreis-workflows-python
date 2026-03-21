# Hello

A minimal Python package demonstrating the platform workflow self-test.

## Usage

```python
from hello.greeter import greet

print(greet("world"))  # Hello, World!
```

## API

### `greet(name: str) -> str`

Returns a greeting for the given name.

**Raises** `ValueError` if `name` is empty or whitespace-only.
