"""Module1 - Base module."""

__version__ = "0.1.0"


def greet(name: str) -> str:
    """Return a greeting message.

    Args:
        name: Name to greet

    Returns:
        Greeting message
    """
    return f"Hello, {name}!"


def farewell(name: str) -> str:
    """Return a farewell message.

    Args:
        name: Name to say goodbye to

    Returns:
        Farewell message
    """
    return f"Goodbye, {name}!"
