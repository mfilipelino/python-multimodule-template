# Module2 Makefile - dual-mode operation
.PHONY: install test lint clean build help dev-install build-shared install-deps workspace-mode

# Variables
PYTHON := python
UV := uv
MODULE_NAME := module2
SHARED_PACKAGES := ../../shared/packages

# Mode detection
WORKSPACE_MODE := $(shell test -f ../../pyproject.toml && grep -q "\[tool.uv.workspace\]" ../../pyproject.toml && echo "1" || echo "0")

# Default target - choose mode based on workspace detection
install: workspace-mode

# Workspace mode detection
workspace-mode:
ifeq ($(WORKSPACE_MODE),1)
	@echo "$(MODULE_NAME): Using workspace mode (managed by root workspace)"
else
	@echo "$(MODULE_NAME): Using package mode"
	@$(MAKE) install-deps
	@$(MAKE) dev-install
endif

# Install module1 dependency from shared repository
install-deps:
	@echo "Installing dependencies for $(MODULE_NAME) from shared repository..."
	@if [ ! -f $(SHARED_PACKAGES)/module1-0.1.0-py3-none-any.whl ]; then \
		echo "Error: module1 package not found in shared repository"; \
		echo "Please build module1 first: make -C ../module1 build-shared"; \
		exit 1; \
	fi

# Install dependencies using uv (package mode)
dev-install:
	@echo "Installing $(MODULE_NAME) dependencies..."
ifeq ($(WORKSPACE_MODE),1)
	@echo "In workspace mode - dependencies managed by root workspace"
else
	$(UV) add --find-links $(SHARED_PACKAGES) module1==0.1.0
	$(UV) sync --dev
endif

# Install production dependencies only
prod-install:
	@echo "Installing $(MODULE_NAME) production dependencies..."
	$(UV) add --find-links $(SHARED_PACKAGES) module1==0.1.0
	$(UV) sync

# Run tests
test:
	@echo "Running tests for $(MODULE_NAME)..."
ifeq ($(WORKSPACE_MODE),1)
	@echo "In workspace mode - use 'make test' from root directory"
else
	$(UV) run pytest
endif

# Run linting
lint:
	@echo "Running linting for $(MODULE_NAME)..."
ifeq ($(WORKSPACE_MODE),1)
	@echo "In workspace mode - use 'make lint' from root directory"
else
	$(UV) run black --check .
	$(UV) run ruff check .
	$(UV) run bandit -r src/
	$(UV) run pyright src/
endif

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
	@echo "  install     - Install dependencies (mode-aware, default)"
	@echo "  install-deps- Install module dependencies from shared repository"
	@echo "  dev-install - Install dev dependencies (package mode)"
	@echo "  prod-install- Install production dependencies only"
	@echo "  test        - Run tests (mode-aware)"
	@echo "  lint        - Run linting (mode-aware)"
	@echo "  format      - Format code (black, ruff)"
	@echo "  clean       - Clean build artifacts"
	@echo "  build       - Build package"
	@echo "  build-shared- Build and copy to shared repository"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Mode detection:"
ifeq ($(WORKSPACE_MODE),1)
	@echo "  Current mode: WORKSPACE (managed by root)"
else
	@echo "  Current mode: PACKAGE (standalone)"
endif