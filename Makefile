# Root Makefile - builds all modules using submake with dependency management
.PHONY: all install test lint clean build help setup-shared module1 module2 build-deps

# Module build order (dependencies first)
MODULE_ORDER := module1 module2

# Shared directories
SHARED_DIR := shared
PACKAGES_DIR := $(SHARED_DIR)/packages
INDEX_DIR := $(SHARED_DIR)/index

# Default target
all: setup-shared build-deps install

# Setup shared directory structure
setup-shared:
	@echo "Setting up shared package repository..."
	@mkdir -p $(PACKAGES_DIR)
	@mkdir -p $(INDEX_DIR)
	@echo "Shared repository ready at $(PACKAGES_DIR)"

# Build all modules in dependency order
build-deps: setup-shared
	@echo "Building all modules in dependency order..."
	@for module in $(MODULE_ORDER); do \
		echo "Building $$module and publishing to shared repository..."; \
		$(MAKE) -C $$module build-shared || exit 1; \
	done

# Install all modules (assumes packages are built)
install: setup-shared
	@echo "Installing all modules from shared repository..."
	@for module in $(MODULE_ORDER); do \
		echo "Installing $$module..."; \
		$(MAKE) -C $$module install || exit 1; \
	done

# Test all modules
test:
	@echo "Testing all modules..."
	@for module in $(MODULE_ORDER); do \
		echo "Testing $$module..."; \
		$(MAKE) -C $$module test || exit 1; \
	done

# Lint all modules
lint:
	@echo "Linting all modules..."
	@for module in $(MODULE_ORDER); do \
		echo "Linting $$module..."; \
		$(MAKE) -C $$module lint || exit 1; \
	done

# Clean all modules and shared repository
clean:
	@echo "Cleaning all modules..."
	@for module in $(MODULE_ORDER); do \
		echo "Cleaning $$module..."; \
		$(MAKE) -C $$module clean || exit 1; \
	done
	@echo "Cleaning shared repository..."
	@rm -rf $(SHARED_DIR)

# Build packages for all modules
build: build-deps

# Rebuild everything from scratch
rebuild: clean all

# Individual module targets
module1: setup-shared
	@echo "Building module1..."
	@$(MAKE) -C module1 build-shared
	@$(MAKE) -C module1 install

module2: setup-shared module1
	@echo "Building module2 (depends on module1)..."
	@$(MAKE) -C module2 build-shared
	@$(MAKE) -C module2 install

# Update shared package index
update-index:
	@echo "Updating shared package index..."
	@cd $(PACKAGES_DIR) && python -m pip install --upgrade pip
	@cd $(PACKAGES_DIR) && python -m pip index --simple $(INDEX_DIR)

# Help target
help:
	@echo "Available targets:"
	@echo "  all         - Setup shared repo, build deps, and install all modules (default)"
	@echo "  setup-shared- Setup shared package repository"
	@echo "  build-deps  - Build all modules in dependency order"
	@echo "  install     - Install all modules from shared repository"
	@echo "  test        - Run tests for all modules"
	@echo "  lint        - Run linting for all modules"
	@echo "  clean       - Clean all modules and shared repository"
	@echo "  build       - Build all module packages"
	@echo "  rebuild     - Clean and rebuild everything"
	@echo "  module1     - Build and install only module1"
	@echo "  module2     - Build and install only module2 (includes module1)"
	@echo "  update-index- Update shared package index"
	@echo "  help        - Show this help message"