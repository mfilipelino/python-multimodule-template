"""Tests for module2."""

from module2 import greet_with_prefix


def test_greet_with_prefix() -> None:
    """Test greet_with_prefix function."""
    assert greet_with_prefix("Smith") == "Hello, Dr. Smith!"
    assert greet_with_prefix("Jones", "Prof.") == "Hello, Prof. Jones!"


def test_greet_with_prefix_empty() -> None:
    """Test greet_with_prefix with empty name."""
    assert greet_with_prefix("", "Mr.") == "Hello, Mr. !"
