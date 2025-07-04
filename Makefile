# Root Makefile - dual-mode operation (workspace dev mode + package build mode)
.PHONY: all install test lint clean build help setup-shared build-deps workspace-install workspace-mode version-show version-analyze version-bump version-bump-dry pre-commit-install pre-commit-update pre-commit-run pre-commit-run-staged pre-commit-uninstall setup-dev

# Mode detection
WORKSPACE_MODE := $(shell test -f pyproject.toml && grep -q "\[tool.uv.workspace\]" pyproject.toml && echo "1" || echo "0")

# Dynamic module discovery
MODULE_ORDER := $(shell python .github/scripts/discover-dependencies.py list 2>/dev/null || echo "module1 module2")

# Shared directories
SHARED_DIR := shared
PACKAGES_DIR := $(SHARED_DIR)/packages
INDEX_DIR := $(SHARED_DIR)/index

# Default target - choose mode based on workspace detection
all: workspace-mode

# Workspace mode (for development)
workspace-mode:
ifeq ($(WORKSPACE_MODE),1)
	@echo "Using workspace mode for development..."
	@$(MAKE) workspace-install
else
	@echo "Using package mode for production..."
	@$(MAKE) setup-shared build-deps install
endif

# Workspace install (development mode)
workspace-install:
	@echo "Installing workspace in development mode..."
	uv sync --dev
	@echo "All modules installed in workspace mode"

# Setup shared directory structure
setup-shared:
	@echo "Setting up shared package repository..."
	@mkdir -p $(PACKAGES_DIR)
	@mkdir -p $(INDEX_DIR)
	@echo "Shared repository ready at $(PACKAGES_DIR)"

# Build all modules in dependency order (package mode)
build-deps: setup-shared
	@echo "Building all modules in dependency order..."
	@for module in $(MODULE_ORDER); do \
		echo "Building $$module and publishing to shared repository..."; \
		$(MAKE) -C modules/$$module build-shared || exit 1; \
	done

# Install all modules (assumes packages are built) - package mode
install: setup-shared
	@echo "Installing all modules from shared repository..."
	@for module in $(MODULE_ORDER); do \
		echo "Installing $$module..."; \
		$(MAKE) -C modules/$$module install || exit 1; \
	done

# Test all modules
test:
ifeq ($(WORKSPACE_MODE),1)
	@echo "Testing all modules in workspace mode..."
	@for module in $(MODULE_ORDER); do \
		echo "Testing $$module..."; \
		uv run pytest modules/$$module/tests/ -v || exit 1; \
	done
else
	@echo "Testing all modules in package mode..."
	@for module in $(MODULE_ORDER); do \
		echo "Testing $$module..."; \
		$(MAKE) -C modules/$$module test || exit 1; \
	done
endif

# Lint all modules
lint:
ifeq ($(WORKSPACE_MODE),1)
	@echo "Linting all modules in workspace mode..."
	uv run black --check modules/
	uv run ruff check modules/
	uv run bandit -r modules/*/src/
	uv run pyright modules/*/src/
else
	@echo "Linting all modules in package mode..."
	@for module in $(MODULE_ORDER); do \
		echo "Linting $$module..."; \
		$(MAKE) -C modules/$$module lint || exit 1; \
	done
endif

# Clean all modules and shared repository
clean:
	@echo "Cleaning all modules..."
	@for module in $(MODULE_ORDER); do \
		echo "Cleaning $$module..."; \
		$(MAKE) -C modules/$$module clean || exit 1; \
	done
	@echo "Cleaning shared repository..."
	@rm -rf $(SHARED_DIR)
	@echo "Cleaning workspace cache..."
	@rm -rf .venv

# Build packages for all modules
build: build-deps

# Rebuild everything from scratch
rebuild: clean all

# Individual module targets (package mode)
module1: setup-shared
	@echo "Building module1..."
	@$(MAKE) -C modules/module1 build-shared
	@$(MAKE) -C modules/module1 install

module2: setup-shared module1
	@echo "Building module2 (depends on module1)..."
	@$(MAKE) -C modules/module2 build-shared
	@$(MAKE) -C modules/module2 install

# Update shared package index
update-index:
	@echo "Updating shared package index..."
	@cd $(PACKAGES_DIR) && python -m pip install --upgrade pip
	@cd $(PACKAGES_DIR) && python -m pip index --simple $(INDEX_DIR)

# Semantic versioning targets
version-show:
	@echo "Current versions:"
	@python .github/scripts/semantic-version.py version

version-analyze:
	@echo "Analyzing commits for version bumps:"
	@python .github/scripts/semantic-version.py analyze

version-bump:
	@echo "Bumping versions based on conventional commits:"
	@python .github/scripts/semantic-version.py bump

version-bump-dry:
	@echo "Dry run - showing what version bumps would be made:"
	@python .github/scripts/semantic-version.py bump --dry-run

# Pre-commit targets
pre-commit-install:
ifeq ($(WORKSPACE_MODE),1)
	@echo "Installing pre-commit hooks in workspace mode..."
	uv run pre-commit install --install-hooks
	uv run pre-commit install --hook-type commit-msg
	uv run pre-commit install --hook-type pre-push
else
	@echo "Installing pre-commit hooks in package mode..."
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install --install-hooks; \
		pre-commit install --hook-type commit-msg; \
		pre-commit install --hook-type pre-push; \
	else \
		echo "pre-commit not found. Please install it first."; \
		exit 1; \
	fi
endif

pre-commit-update:
ifeq ($(WORKSPACE_MODE),1)
	@echo "Updating pre-commit hooks in workspace mode..."
	uv run pre-commit autoupdate
else
	@echo "Updating pre-commit hooks in package mode..."
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit autoupdate; \
	else \
		echo "pre-commit not found. Please install it first."; \
		exit 1; \
	fi
endif

pre-commit-run:
ifeq ($(WORKSPACE_MODE),1)
	@echo "Running pre-commit on all files in workspace mode..."
	uv run pre-commit run --all-files
else
	@echo "Running pre-commit on all files in package mode..."
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit run --all-files; \
	else \
		echo "pre-commit not found. Please install it first."; \
		exit 1; \
	fi
endif

pre-commit-run-staged:
ifeq ($(WORKSPACE_MODE),1)
	@echo "Running pre-commit on staged files in workspace mode..."
	uv run pre-commit run
else
	@echo "Running pre-commit on staged files in package mode..."
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit run; \
	else \
		echo "pre-commit not found. Please install it first."; \
		exit 1; \
	fi
endif

pre-commit-uninstall:
ifeq ($(WORKSPACE_MODE),1)
	@echo "Uninstalling pre-commit hooks in workspace mode..."
	uv run pre-commit uninstall
	uv run pre-commit uninstall --hook-type commit-msg
	uv run pre-commit uninstall --hook-type pre-push
else
	@echo "Uninstalling pre-commit hooks in package mode..."
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit uninstall; \
		pre-commit uninstall --hook-type commit-msg; \
		pre-commit uninstall --hook-type pre-push; \
	else \
		echo "pre-commit not found. Please install it first."; \
		exit 1; \
	fi
endif

# Development setup target
setup-dev:
	@echo "Setting up development environment..."
	@./scripts/setup-dev.sh

# Help target
help:
	@echo "Available targets:"
	@echo "  all         - Auto-detect mode and install (default)"
	@echo "  workspace-install - Install in workspace mode (development)"
	@echo "  setup-shared- Setup shared package repository (package mode)"
	@echo "  build-deps  - Build all modules in dependency order (package mode)"
	@echo "  install     - Install all modules from shared repository (package mode)"
	@echo "  test        - Run tests for all modules (mode-aware)"
	@echo "  lint        - Run linting for all modules (mode-aware)"
	@echo "  clean       - Clean all modules and shared repository"
	@echo "  build       - Build all module packages"
	@echo "  rebuild     - Clean and rebuild everything"
	@echo "  module1     - Build and install only module1 (package mode)"
	@echo "  module2     - Build and install only module2 (package mode)"
	@echo "  update-index- Update shared package index"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Semantic Versioning:"
	@echo "  version-show     - Show current versions of all components"
	@echo "  version-analyze  - Analyze commits for version bumps"
	@echo "  version-bump     - Bump versions based on conventional commits"
	@echo "  version-bump-dry - Show what version bumps would be made (dry run)"
	@echo ""
	@echo "Pre-commit Hooks:"
	@echo "  pre-commit-install   - Install pre-commit hooks"
	@echo "  pre-commit-update    - Update pre-commit hooks"
	@echo "  pre-commit-run       - Run pre-commit on all files"
	@echo "  pre-commit-run-staged- Run pre-commit on staged files only"
	@echo "  pre-commit-uninstall - Uninstall pre-commit hooks"
	@echo ""
	@echo "Development Setup:"
	@echo "  setup-dev       - One-command setup for development environment"
	@echo ""
	@echo "Mode detection:"
ifeq ($(WORKSPACE_MODE),1)
	@echo "  Current mode: WORKSPACE (development)"
else
	@echo "  Current mode: PACKAGE (production)"
endif