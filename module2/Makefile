# Module2 Makefile
.PHONY: install test lint clean build help dev-install build-shared install-deps

# Variables
PYTHON := python
UV := uv
MODULE_NAME := module2
SHARED_PACKAGES := ../shared/packages

# Default target
install: install-deps dev-install

# Install module1 dependency from shared repository
install-deps:
	@echo "Installing dependencies for $(MODULE_NAME) from shared repository..."
	@if [ ! -f $(SHARED_PACKAGES)/module1-0.1.0-py3-none-any.whl ]; then \
		echo "Error: module1 package not found in shared repository"; \
		echo "Please build module1 first: make -C ../module1 build-shared"; \
		exit 1; \
	fi

# Install dependencies using uv
dev-install:
	@echo "Installing $(MODULE_NAME) dependencies..."
	$(UV) add --find-links $(SHARED_PACKAGES) module1==0.1.0
	$(UV) sync --dev

# Install production dependencies only
prod-install:
	@echo "Installing $(MODULE_NAME) production dependencies..."
	$(UV) add --find-links $(SHARED_PACKAGES) module1==0.1.0
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
	@echo "  install     - Install dependencies and dev dependencies (default)"
	@echo "  install-deps- Install module dependencies from shared repository"
	@echo "  dev-install - Install dev dependencies"
	@echo "  prod-install- Install production dependencies only"
	@echo "  test        - Run tests"
	@echo "  lint        - Run linting (black, ruff, bandit, pyright)"
	@echo "  format      - Format code (black, ruff)"
	@echo "  clean       - Clean build artifacts"
	@echo "  build       - Build package"
	@echo "  build-shared- Build and copy to shared repository"
	@echo "  help        - Show this help message"