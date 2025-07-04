# Module1 Makefile
.PHONY: install test lint clean build help dev-install build-shared

# Variables
PYTHON := python
UV := uv
MODULE_NAME := module1
SHARED_PACKAGES := ../shared/packages

# Default target
install: dev-install

# Install dependencies using uv
dev-install:
	@echo "Installing $(MODULE_NAME) dependencies..."
	$(UV) sync --dev

# Install production dependencies only
prod-install:
	@echo "Installing $(MODULE_NAME) production dependencies..."
	$(UV) sync

# Run tests
test:
	@echo "Running tests for $(MODULE_NAME)..."
	$(UV) run pytest

# Run linting
lint:
	@echo "Running linting for $(MODULE_NAME)..."
	$(UV) run black --check .
	$(UV) run ruff check .
	$(UV) run bandit -r src/
	$(UV) run pyright src/

# Format code
format:
	@echo "Formatting code for $(MODULE_NAME)..."
	$(UV) run black .
	$(UV) run ruff format .
	$(UV) run ruff check --fix .

# Clean build artifacts
clean:
	@echo "Cleaning $(MODULE_NAME)..."
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	rm -rf .coverage
	rm -rf htmlcov/
	rm -rf .pytest_cache/
	rm -rf .mypy_cache/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

# Build package
build:
	@echo "Building $(MODULE_NAME) package..."
	$(UV) build

# Build and copy to shared repository
build-shared: build
	@echo "Building $(MODULE_NAME) and copying to shared repository..."
	@mkdir -p $(SHARED_PACKAGES)
	@cp dist/*.whl $(SHARED_PACKAGES)/
	@echo "$(MODULE_NAME) package copied to $(SHARED_PACKAGES)"

# Help
help:
	@echo "Available targets for $(MODULE_NAME):"
	@echo "  install     - Install dev dependencies (default)"
	@echo "  dev-install - Install dev dependencies"
	@echo "  prod-install- Install production dependencies only"
	@echo "  test        - Run tests"
	@echo "  lint        - Run linting (black, ruff, bandit, pyright)"
	@echo "  format      - Format code (black, ruff)"
	@echo "  clean       - Clean build artifacts"
	@echo "  build       - Build package"
	@echo "  build-shared- Build and copy to shared repository"
	@echo "  help        - Show this help message"