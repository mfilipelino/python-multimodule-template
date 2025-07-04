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

# Developer setup
setup-dev:
	@echo "Running developer environment setup..."
	@scripts/setup-dev.sh

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
	@echo "Dry run - showing what versions would be bumped:"
	@python .github/scripts/semantic-version.py bump --dry-run

# Pre-commit targets
pre-commit-install:
	@echo "Installing pre-commit hooks..."
	uv run pre-commit install
	uv run pre-commit install --hook-type commit-msg
	@echo "✅ Pre-commit hooks installed successfully"

pre-commit-update:
	@echo "Updating pre-commit hooks..."
	uv run pre-commit autoupdate
	@echo "✅ Pre-commit hooks updated"

pre-commit-run:
	@echo "Running pre-commit hooks on all files..."
	uv run pre-commit run --all-files

pre-commit-run-staged:
	@echo "Running pre-commit hooks on staged files..."
	uv run pre-commit run

pre-commit-uninstall:
	@echo "Uninstalling pre-commit hooks..."
	uv run pre-commit uninstall
	uv run pre-commit uninstall --hook-type commit-msg
	@echo "✅ Pre-commit hooks uninstalled"

# Help target
help:
	@echo "Available targets:"
	@echo "  all         - Auto-detect mode and install (default)"
	@echo "  setup-dev   - Complete development environment setup"
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
	@echo "  version-show- Show current versions of all components"
	@echo "  version-analyze - Analyze commits for version bumps"
	@echo "  version-bump- Bump versions based on conventional commits"
	@echo "  version-bump-dry - Show what versions would be bumped (dry run)"
	@echo "  pre-commit-install - Install pre-commit hooks"
	@echo "  pre-commit-update - Update pre-commit hook versions"
	@echo "  pre-commit-run - Run pre-commit hooks on all files"
	@echo "  pre-commit-run-staged - Run pre-commit hooks on staged files"
	@echo "  pre-commit-uninstall - Uninstall pre-commit hooks"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Mode detection:"
ifeq ($(WORKSPACE_MODE),1)
	@echo "  Current mode: WORKSPACE (development)"
else
	@echo "  Current mode: PACKAGE (production)"
endif