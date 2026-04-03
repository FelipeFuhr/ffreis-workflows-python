# Hello

A minimal Python hello-world app demonstrating the platform workflow self-test.

## Usage

```bash
uv run hello world
# Hello, World!
```

## API

### `greet(name: str) -> str`

Returns a greeting for the given name.

**Raises** `ValueError` if `name` is empty or whitespace-only.

## CLI

The example also exposes a `hello` console script and supports:

```bash
python -m hello --help
```
