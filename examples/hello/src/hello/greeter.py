"""Simple greeter module — validates the full workflow suite."""


def greet(name: str) -> str:
    """Return a greeting for the given name.

    Args:
        name: The name to greet. Must be non-empty after stripping whitespace.

    Returns:
        A greeting string of the form "Hello, <Name>!".

    Raises:
        ValueError: If name is empty or whitespace-only.
    """
    stripped = name.strip()
    if not stripped:
        raise ValueError("name must not be empty or whitespace-only")
    return f"Hello, {stripped.title()}!"
