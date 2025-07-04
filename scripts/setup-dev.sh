#!/bin/bash
# One-command developer environment setup
# Sets up everything needed for development in the multi-module workspace

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REQUIRED_PYTHON_VERSION="3.12"

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $*"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get Python version
get_python_version() {
    python3 --version 2>/dev/null | cut -d' ' -f2 | cut -d'.' -f1-2
}

# Function to validate Python version
validate_python() {
    log_step "Validating Python installation"
    
    if ! command_exists python3; then
        log_error "Python 3 is not installed"
        log_error "Please install Python ${REQUIRED_PYTHON_VERSION}+ and try again"
        return 1
    fi
    
    local current_version
    current_version=$(get_python_version)
    
    log_info "Found Python $current_version"
    
    # Simple version comparison (assumes format X.Y)
    local major minor
    IFS='.' read -r major minor <<< "$current_version"
    local required_major required_minor
    IFS='.' read -r required_major required_minor <<< "$REQUIRED_PYTHON_VERSION"
    
    if [[ $major -lt $required_major ]] || [[ $major -eq $required_major && $minor -lt $required_minor ]]; then
        log_error "Python ${REQUIRED_PYTHON_VERSION}+ is required, but found $current_version"
        log_error "Please upgrade Python and try again"
        return 1
    fi
    
    log_info "Python version validation passed"
    return 0
}

# Function to install UV
install_uv() {
    log_step "Checking UV installation"
    
    if command_exists uv; then
        local uv_version
        uv_version=$(uv --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
        log_info "UV is already installed (version: $uv_version)"
        return 0
    fi
    
    log_info "Installing UV package manager"
    
    # Install UV using the official installer
    if command_exists curl; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command_exists wget; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install UV manually: https://github.com/astral-sh/uv"
        return 1
    fi
    
    # Add UV to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
    
    # Verify installation
    if command_exists uv; then
        local uv_version
        uv_version=$(uv --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
        log_info "UV installed successfully (version: $uv_version)"
    else
        log_error "UV installation failed"
        log_error "Please install UV manually and try again"
        return 1
    fi
    
    return 0
}

# Function to setup workspace
setup_workspace() {
    log_step "Setting up workspace environment"
    
    cd "$WORKSPACE_ROOT"
    
    # Remove existing virtual environment if it exists
    if [[ -d ".venv" ]]; then
        log_info "Removing existing virtual environment"
        rm -rf .venv
    fi
    
    # Create new virtual environment
    log_info "Creating virtual environment with UV"
    uv venv --python "$REQUIRED_PYTHON_VERSION"
    
    # Install workspace dependencies
    log_info "Installing workspace dependencies"
    uv sync --dev
    
    log_info "Workspace setup completed"
}

# Function to install pre-commit hooks
setup_precommit() {
    log_step "Setting up pre-commit hooks"
    
    cd "$WORKSPACE_ROOT"
    
    # Install pre-commit hooks
    log_info "Installing pre-commit hooks"
    uv run pre-commit install --install-hooks
    
    # Install commit-msg hook for conventional commits
    log_info "Installing commit-msg hook"
    uv run pre-commit install --hook-type commit-msg
    
    # Install pre-push hook
    log_info "Installing pre-push hook"
    uv run pre-commit install --hook-type pre-push
    
    log_info "Pre-commit hooks installed successfully"
}

# Function to validate installation
validate_installation() {
    log_step "Validating installation"
    
    cd "$WORKSPACE_ROOT"
    
    # Check if virtual environment is working
    if [[ ! -d ".venv" ]]; then
        log_error "Virtual environment not found"
        return 1
    fi
    
    # Test UV commands
    log_info "Testing UV workspace"
    if ! uv run python -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}')"; then
        log_error "UV workspace test failed"
        return 1
    fi
    
    # Test module imports
    log_info "Testing module imports"
    if ! uv run python -c "import module1, module2; print('Modules imported successfully')"; then
        log_warning "Module import test failed - modules may not be properly installed"
        log_info "This is normal if modules are not yet fully implemented"
    fi
    
    # Test pre-commit
    log_info "Testing pre-commit installation"
    if ! uv run pre-commit --version >/dev/null; then
        log_error "Pre-commit test failed"
        return 1
    fi
    
    log_info "Installation validation completed"
    return 0
}

# Function to run initial checks
run_initial_checks() {
    log_step "Running initial code quality checks"
    
    cd "$WORKSPACE_ROOT"
    
    # Run pre-commit on all files
    log_info "Running pre-commit hooks on all files"
    if uv run pre-commit run --all-files; then
        log_info "All pre-commit checks passed"
    else
        log_warning "Some pre-commit checks failed or made changes"
        log_info "This is normal for the first run - files may have been auto-formatted"
    fi
    
    # Run tests
    log_info "Running tests"
    if uv run pytest; then
        log_info "All tests passed"
    else
        log_warning "Some tests failed"
        log_info "Check the test output above for details"
    fi
}

# Function to show next steps
show_next_steps() {
    log_step "Setup completed successfully!"
    
    cat << EOF

${GREEN}🎉 Development environment is ready!${NC}

${BLUE}Next steps:${NC}
1. Activate the environment: ${YELLOW}cd $WORKSPACE_ROOT${NC}
2. Start coding in any module: ${YELLOW}modules/module1/src/module1/${NC}
3. Run tests: ${YELLOW}make test${NC}
4. Run linting: ${YELLOW}make lint${NC}
5. Check available commands: ${YELLOW}make help${NC}

${BLUE}Available tools:${NC}
- UV package manager for fast dependency management
- Pre-commit hooks for code quality
- Pytest for testing
- Ruff for linting and formatting
- Black for code formatting
- Bandit for security scanning
- Pyright for type checking

${BLUE}Development workflow:${NC}
1. Make changes to any module
2. Changes are immediately available (workspace mode)
3. Run ${YELLOW}make test${NC} to test your changes
4. Commit with conventional commit messages (e.g., "feat: add new feature")
5. Pre-commit hooks will automatically check your code

${GREEN}Happy coding! 🚀${NC}
EOF
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

One-command developer environment setup for multi-module Python projects.

OPTIONS:
  -h, --help          Show this help message
  -q, --quiet         Quiet mode (less output)
  -v, --verbose       Verbose mode (more output)
  --skip-precommit    Skip pre-commit hooks setup
  --skip-validation   Skip installation validation
  --skip-checks       Skip initial code quality checks

EXAMPLES:
  $0                  # Full setup
  $0 --quiet          # Quiet setup
  $0 --skip-checks    # Setup without running initial checks

This script will:
1. Validate Python ${REQUIRED_PYTHON_VERSION}+ installation
2. Install UV package manager (if not present)
3. Set up workspace environment with dependencies
4. Install and configure pre-commit hooks
5. Validate the installation
6. Run initial code quality checks
EOF
}

# Main function
main() {
    local quiet=false
    local verbose=false
    local skip_precommit=false
    local skip_validation=false
    local skip_checks=false
    
    # Process command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --skip-precommit)
                skip_precommit=true
                shift
                ;;
            --skip-validation)
                skip_validation=true
                shift
                ;;
            --skip-checks)
                skip_checks=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Header
    if [[ "$quiet" != true ]]; then
        cat << EOF
${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}
${BLUE}║                    Multi-Module Python Development Setup                    ║${NC}
${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}

${GREEN}Setting up development environment for multi-module Python project...${NC}

EOF
    fi
    
    # Execute setup steps
    if ! validate_python; then
        exit 1
    fi
    
    if ! install_uv; then
        exit 1
    fi
    
    if ! setup_workspace; then
        exit 1
    fi
    
    if [[ "$skip_precommit" != true ]]; then
        if ! setup_precommit; then
            log_warning "Pre-commit setup failed, continuing anyway"
        fi
    fi
    
    if [[ "$skip_validation" != true ]]; then
        if ! validate_installation; then
            log_error "Installation validation failed"
            exit 1
        fi
    fi
    
    if [[ "$skip_checks" != true ]]; then
        run_initial_checks
    fi
    
    if [[ "$quiet" != true ]]; then
        show_next_steps
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi