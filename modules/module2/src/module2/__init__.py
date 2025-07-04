"""Module2 - Depends on module1."""

from typing import cast

from module1 import greet

__version__ = "0.1.0"


def greet_with_prefix(name: str, prefix: str = "Dr.") -> str:
    """Return a greeting with a prefix.

    Args:
        name: Name to greet
        prefix: Prefix to use (default: "Dr.")

    Returns:
        Greeting message with prefix
    """
    full_name: str = f"{prefix} {name}"
    return cast(str, greet(full_name))
