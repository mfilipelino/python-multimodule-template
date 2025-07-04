"""Tests for module1."""

from module1 import farewell, greet


def test_greet() -> None:
    """Test greet function."""
    assert greet("World") == "Hello, World!"
    assert greet("Python") == "Hello, Python!"


def test_greet_empty_string() -> None:
    """Test greet with empty string."""
    assert greet("") == "Hello, !"


def test_farewell() -> None:
    """Test farewell function."""
    assert farewell("World") == "Goodbye, World!"
    assert farewell("Python") == "Goodbye, Python!"


def test_farewell_empty_string() -> None:
    """Test farewell with empty string."""
    assert farewell("") == "Goodbye, !"
