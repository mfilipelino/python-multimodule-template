"""Tests for module1."""

from module1 import greet


def test_greet() -> None:
    """Test greet function."""
    assert greet("World") == "Hello, World!"
    assert greet("Python") == "Hello, Python!"


def test_greet_empty_string() -> None:
    """Test greet with empty string."""
    assert greet("") == "Hello, !"
