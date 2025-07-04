# Multi-Module Python Project with Shared Package Repository

This project contains multiple Python modules that depend on each other through built packages rather than source code dependencies.

## Project Structure

```
project-root/
├── shared/
│   └── packages/         # Built packages (.whl files)
├── module1/              # Base module (no dependencies)
├── module2/              # Depends on module1 package
├── README.md             # This file
└── Makefile              # Root build system
```

## Key Features

- **Package-based Dependencies**: Modules depend on built packages, not source code
- **Shared Repository**: All built packages stored in `shared/packages/`
- **Dependency Order**: Builds modules in correct dependency order
- **Isolation**: Each module is self-contained and testable independently
- **Version Control**: Dependencies use specific package versions
- **Modern Tooling**: Ruff for linting/formatting, Bandit for security, Pyright for type checking
- **Selective CI**: Only tests changed modules and their dependents for faster feedback

## Prerequisites

- Python 3.12+
- [uv](https://github.com/astral-sh/uv) - Python package manager
- Make

## Quick Start

### Build All Modules (Recommended)
```bash
make all
```
This will:
1. Setup the shared package repository
2. Build all modules in dependency order
3. Install all modules with their dependencies

### Step-by-Step Build
```bash
make setup-shared    # Setup shared repository
make build-deps      # Build all modules in order
make install         # Install all modules
```

### Run Tests
```bash
make test
```

### Clean Everything
```bash
make clean
```

## Working with Individual Modules

### Build module1 (no dependencies)
```bash
make module1
```

### Build module2 (depends on module1)
```bash
make module2  # This will build module1 first if needed
```

### Work directly in a module directory
```bash
cd module2
make install-deps    # Install dependencies from shared repo
make dev-install     # Install dev dependencies
make test           # Run tests
```

## Dependency Management

### Adding Dependencies Between Modules

1. **In the dependent module's `pyproject.toml`**, add:
   ```toml
   dependencies = [
       "module1 @ file://../shared/packages/module1-0.1.0-py3-none-any.whl",
   ]
   ```

2. **Update the root Makefile** `MODULE_ORDER` to ensure proper build sequence:
   ```makefile
   MODULE_ORDER := module1 module2 module3
   ```

3. **Update the dependent module's Makefile** to check for dependencies:
   ```makefile
   install-deps:
       @if [ ! -f $(SHARED_PACKAGES)/module1-0.1.0-py3-none-any.whl ]; then \
           echo "Error: module1 package not found"; \
           exit 1; \
       fi
   ```

## Available Commands

### Root Level Commands
- `make all` - Complete build: setup, build deps, install (default)
- `make setup-shared` - Setup shared package repository
- `make build-deps` - Build all modules in dependency order
- `make install` - Install all modules from shared repository
- `make test` - Test all modules
- `make lint` - Lint all modules
- `make clean` - Clean all modules and shared repository
- `make rebuild` - Clean and rebuild everything
- `make module1` - Build and install only module1
- `make module2` - Build and install module2 (includes module1)

### Module Level Commands
(Available in each module directory)
- `make install` - Install dependencies and dev dependencies
- `make install-deps` - Install module dependencies from shared repo
- `make test` - Run module tests
- `make lint` - Run module linting (black, ruff, bandit, pyright)
- `make format` - Format code (black, ruff)
- `make build-shared` - Build and copy to shared repository
- `make clean` - Clean module build artifacts

## Development Workflow

1. **Make changes** in the relevant module
2. **Build dependencies** if needed: `make build-deps`
3. **Test your changes**: `make test`
4. **Lint your code**: `make lint`
5. **Rebuild if needed**: `make rebuild`

## Adding New Modules

1. **Create module directory** following the pattern `moduleN/`
2. **Copy structure** from an existing module
3. **Update `pyproject.toml`** with:
   - New module name
   - Dependencies on other modules (if any)
4. **Update root Makefile** `MODULE_ORDER` to include the new module
5. **Update dependent module Makefiles** to check for new dependencies

## Troubleshooting

### "Package not found" errors
- Run `make build-deps` to build all dependencies
- Check that the shared repository exists: `ls shared/packages/`

### Circular dependencies
- Review the `MODULE_ORDER` in the root Makefile
- Ensure no circular dependencies exist between modules

### Version mismatches
- Update the version references in `pyproject.toml` files
- Rebuild with `make rebuild`