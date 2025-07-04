# Multi-Module Python Project with UV Workspace

A modern Python multi-module project template featuring **dual-mode operation** with UV workspaces for development and package-based dependencies for production.

## 🏗️ Architecture Overview

This project supports two operation modes:

### 🚀 **Workspace Mode** (Development - Default)
- **Fast Setup**: Single `make all` command installs everything
- **Unified Environment**: All modules in one UV workspace 
- **Live Dependencies**: Editable installs with instant changes
- **Shared Tooling**: Common linting, testing, and formatting

### 📦 **Package Mode** (Production)
- **Distribution Ready**: Modules built as wheel packages
- **Version Control**: Explicit version dependencies
- **Isolation**: Each module is self-contained
- **Traditional**: Compatible with standard Python packaging

## 📁 Project Structure

```
multimodules-template/
├── pyproject.toml          # Workspace configuration & global tools
├── .python-version         # Python version (3.12+)
├── Makefile               # Dual-mode build system
├── modules/               # All project modules
│   ├── module1/           # Base module (no dependencies)
│   │   ├── src/module1/   # Source code
│   │   ├── tests/         # Module tests
│   │   ├── pyproject.toml # Module configuration
│   │   └── Makefile       # Module build commands
│   └── module2/           # Dependent module
│       ├── src/module2/   # Source code  
│       ├── tests/         # Module tests
│       ├── pyproject.toml # Module configuration (depends on module1)
│       └── Makefile       # Module build commands
├── shared/                # Package mode artifacts
│   └── packages/          # Built wheel files (.whl)
├── .github/
│   ├── workflows/ci.yml   # Selective CI pipeline
│   └── scripts/           # Dynamic dependency discovery
│       ├── detect-changes.sh       # Change detection
│       └── discover-dependencies.py # Dependency graph builder
└── README.md              # This file
```

## ✨ Key Features

- **🔄 Dual-Mode Operation**: Workspace for dev, packages for production
- **⚡ Dynamic Dependencies**: Auto-discovers module relationships
- **🎯 Selective CI**: Only tests changed modules and dependents
- **🛠️ Modern Tooling**: UV, Ruff, Black, Bandit, Pyright
- **📊 Dependency Graph**: Automatic build order resolution
- **🔧 Mode Detection**: Automatic mode switching based on configuration

## 🚀 Quick Start

### Prerequisites
- **Python 3.12+**
- **[UV](https://github.com/astral-sh/uv)** - Fast Python package manager
- **Make**

### Installation & Setup

```bash
# Clone and enter the project
git clone <repository-url>
cd multimodules-template

# Install everything (auto-detects workspace mode)
make all
```

This automatically:
1. 🔍 Detects operation mode (workspace/package)
2. 📦 Installs all dependencies with UV
3. 🔗 Sets up module cross-dependencies
4. ✅ Ready for development!

## 🎮 Available Commands

### 🏠 Root Level Commands

```bash
# Core Operations
make all          # Auto-detect mode and install (default)
make test         # Run all module tests (mode-aware)
make lint         # Run all linting (mode-aware)
make clean        # Clean all artifacts

# Workspace Mode (Development)
make workspace-install  # Force workspace installation

# Package Mode (Production)
make setup-shared       # Setup shared package repository
make build-deps         # Build modules in dependency order
make install           # Install from built packages
make module1           # Build only module1
make module2           # Build module2 (includes module1)

# Utilities
make help         # Show available targets with current mode
make rebuild      # Clean and rebuild everything
```

### 📋 Current Mode Detection

The system automatically shows your current operation mode:

```bash
make help
```

**Output Example:**
```
Mode detection:
  Current mode: WORKSPACE (development)
```

## 🔧 Operation Modes

### 🚀 Workspace Mode (Default for Development)

**When active**: `pyproject.toml` contains `[tool.uv.workspace]`

**Benefits:**
- ⚡ Fast setup: `make all` installs everything instantly
- 🔄 Live changes: Edit any module, changes are immediately available
- 🧪 Unified testing: Run tests across all modules seamlessly
- 🎯 Shared environment: One virtual environment for everything

**Usage:**
```bash
# Install everything
make all

# Test all modules  
make test

# Lint all modules
make lint

# Work on any module - changes are immediately available
vim modules/module1/src/module1/__init__.py
# No rebuild needed! Changes are live.
```

### 📦 Package Mode (Production/Distribution)

**When active**: No workspace configuration detected

**Benefits:**
- 📋 Explicit versions: Clear dependency contracts
- 🔒 Isolation: Each module builds independently  
- 📦 Distribution ready: Produces wheel files
- 🏭 Traditional: Standard Python packaging workflow

**Usage:**
```bash
# Setup package repository
make setup-shared

# Build in dependency order
make build-deps

# Install from packages
make install

# Build individual modules
make module1  # Creates module1-0.1.0-py3-none-any.whl
```

## 🧪 Development Workflow

### Workspace Mode (Recommended for Development)

```bash
# 1. Setup (once)
make all

# 2. Make changes to any module
vim modules/module1/src/module1/__init__.py

# 3. Test your changes (automatically includes dependencies)
make test

# 4. Lint your code
make lint

# 5. Done! No rebuild needed - changes are live
```

### Package Mode (For Distribution)

```bash
# 1. Build dependencies
make build-deps

# 2. Test with built packages
make test

# 3. Lint
make lint

# 4. Distribute wheels from shared/packages/
ls shared/packages/*.whl
```

## 🔍 Dynamic Dependency Management

The system automatically discovers module relationships:

### Adding Module Dependencies

**1. Update `pyproject.toml`** in the dependent module:
```toml
# modules/module2/pyproject.toml
dependencies = [
    "module1",  # Simple workspace reference
]
```

**2. The system automatically**:
- 🔍 Discovers the dependency relationship
- 📊 Updates build order
- 🎯 Includes in selective CI
- ✅ Works in both modes!

### Viewing Dependencies

```bash
# List all modules in build order
python .github/scripts/discover-dependencies.py list

# Show dependencies of module2
python .github/scripts/discover-dependencies.py dependencies module2

# Show what depends on module1  
python .github/scripts/discover-dependencies.py dependents module1
```

## 🚀 Selective CI System

Intelligent CI that only tests what changed:

### How It Works
- **🔍 Change Detection**: Analyzes git diffs to find changed files
- **🗺️ Module Mapping**: Maps files to their modules
- **📊 Dependency Resolution**: Includes dependent modules automatically
- **⚡ Parallel Execution**: Tests affected modules simultaneously

### Change Detection Rules
```bash
# Examples of what triggers testing:

modules/module1/**     → Tests: module1, module2 (dependent)
modules/module2/**     → Tests: module2 only
pyproject.toml         → Tests: all modules (workspace config)
.github/workflows/**   → Tests: all modules (CI changes)
README.md             → Tests: none (docs only)
```

### Benefits
- ⚡ **3x Faster CI**: Only test what matters
- 💰 **Cost Efficient**: Reduced compute usage
- 🔄 **Quick Feedback**: Fast developer feedback loop
- 📈 **Scales**: Better performance as modules grow

## 🔧 Module Development

### Working with Individual Modules

```bash
# Enter module directory
cd modules/module1

# Check current mode
make help

# In workspace mode - managed by root
make test    # → "In workspace mode - use 'make test' from root directory"

# In package mode - independent operation  
make install # Install dependencies
make test    # Run module tests
make lint    # Run module linting
```

### Adding New Modules

```bash
# 1. Create module structure
mkdir -p modules/module3/{src/module3,tests}

# 2. Create pyproject.toml (copy from existing module)
cp modules/module1/pyproject.toml modules/module3/
# Edit name, dependencies, etc.

# 3. Create Makefile (copy from existing module)  
cp modules/module1/Makefile modules/module3/

# 4. Done! System automatically discovers:
python .github/scripts/discover-dependencies.py list
# → module1, module2, module3
```

## 🛠️ Tools & Configuration

### Global Tool Configuration
All tools configured in root `pyproject.toml`:

- **🔧 Ruff**: Linting and formatting (replaces flake8, isort)
- **⚫ Black**: Code formatting  
- **🔒 Bandit**: Security scanning
- **📝 Pyright**: Type checking (faster than mypy)
- **🧪 Pytest**: Testing framework

### Per-Module Configuration
Minimal module `pyproject.toml` files focus on:
- Package metadata
- Dependencies  
- Module-specific settings

## 🐛 Troubleshooting

### Common Issues

**"No module named 'module1'" in workspace mode:**
```bash
# Reinstall workspace
rm -rf .venv uv.lock
make workspace-install
```

**"Package not found" in package mode:**
```bash
# Build dependencies first
make build-deps
```

**Wrong operation mode:**
```bash
# Check current mode
make help

# Force workspace mode (ensure pyproject.toml has [tool.uv.workspace])
# Force package mode (remove/rename pyproject.toml)
```

**CI not detecting changes:**
```bash
# Test change detection locally
.github/scripts/detect-changes.sh HEAD~1 HEAD
```

### Mode Switching

**Switch to workspace mode:**
```bash
# Ensure root pyproject.toml has workspace config
grep -A5 "\[tool.uv.workspace\]" pyproject.toml
make all
```

**Switch to package mode:**
```bash
# Temporarily disable workspace
mv pyproject.toml pyproject.toml.backup
make all  # Now uses package mode
mv pyproject.toml.backup pyproject.toml  # Restore when done
```

## 🎯 Best Practices

### Development
- 🚀 Use **workspace mode** for daily development
- 🧪 Run `make test` frequently  
- 🔧 Use `make lint` before committing
- 📝 Keep module `pyproject.toml` files minimal

### Production
- 📦 Use **package mode** for releases
- 🏷️ Version your modules appropriately
- 📋 Test with built packages before release
- 🔒 Use explicit version dependencies

### CI/CD
- ✅ Leverage selective CI for faster feedback
- 🔄 Test both modes in your pipeline
- 📊 Monitor which modules are tested per change
- ⚡ Optimize based on change patterns

## 📚 Architecture Benefits

### For Developers
- **⚡ Faster Setup**: One command gets everything working
- **🔄 Live Changes**: Edit and test immediately
- **🎯 Focused Testing**: Only test what you changed
- **🛠️ Modern Tools**: Latest Python tooling

### For Teams  
- **📊 Clear Dependencies**: Explicit module relationships
- **🔒 Isolation**: Modules can be developed independently
- **📈 Scalable**: Performance improves with size
- **🔄 Flexible**: Switch modes based on needs

### For Production
- **📦 Standard Packaging**: Compatible with PyPI, pip
- **🏷️ Version Control**: Explicit dependency versions
- **🔒 Reproducible**: Locked dependencies and builds
- **📋 Auditable**: Clear dependency chain

---

## 🤝 Contributing

1. 🍴 Fork the repository
2. 🌿 Create a feature branch
3. 🧪 Test in both modes: `make test`
4. 🔧 Lint your code: `make lint`  
5. 📝 Update documentation if needed
6. 🔄 Submit a pull request

The selective CI system will automatically test only the modules affected by your changes!