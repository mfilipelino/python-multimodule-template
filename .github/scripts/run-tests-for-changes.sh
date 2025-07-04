#!/bin/bash
# Smart testing script for multi-module projects
# Only runs tests for changed modules and their dependents

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULES_DIR="$WORKSPACE_ROOT/modules"
DEPENDENCIES_SCRIPT="$WORKSPACE_ROOT/.github/scripts/discover-dependencies.py"

# Logging functions
log_info() {
    echo "[INFO] $*" >&2
}

log_warning() {
    echo "[WARNING] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Function to detect operation mode
detect_mode() {
    if [[ -f "$WORKSPACE_ROOT/pyproject.toml" ]] && grep -q "\[tool\.uv\.workspace\]" "$WORKSPACE_ROOT/pyproject.toml"; then
        echo "workspace"
    else
        echo "package"
    fi
}

# Function to get changed modules from git
get_changed_modules() {
    local base_ref="${1:-HEAD~1}"
    local head_ref="${2:-HEAD}"
    
    log_info "Detecting changes between $base_ref and $head_ref"
    
    # Get changed files
    local changed_files
    if ! changed_files=$(git diff --name-only "$base_ref" "$head_ref" 2>/dev/null); then
        log_warning "Could not detect git changes, testing all modules"
        find "$MODULES_DIR" -maxdepth 1 -type d -name "*" | while read -r dir; do
            if [[ -f "$dir/pyproject.toml" ]]; then
                basename "$dir"
            fi
        done
        return
    fi
    
    # Find affected modules
    local affected_modules=()
    
    while IFS= read -r file; do
        if [[ "$file" =~ ^modules/([^/]+)/ ]]; then
            local module_name="${BASH_REMATCH[1]}"
            if [[ ! " ${affected_modules[*]} " =~ " ${module_name} " ]]; then
                affected_modules+=("$module_name")
            fi
        elif [[ "$file" =~ ^(pyproject\.toml|\.github/workflows/|Makefile)$ ]]; then
            # Workspace-level changes affect all modules
            log_info "Workspace-level change detected: $file"
            find "$MODULES_DIR" -maxdepth 1 -type d -name "*" | while read -r dir; do
                if [[ -f "$dir/pyproject.toml" ]]; then
                    basename "$dir"
                fi
            done
            return
        fi
    done <<< "$changed_files"
    
    # Output affected modules
    for module in "${affected_modules[@]}"; do
        echo "$module"
    done
}

# Function to get modules that depend on the given modules
get_dependent_modules() {
    local modules=("$@")
    local all_modules=()
    
    for module in "${modules[@]}"; do
        all_modules+=("$module")
        
        # Get dependents using Python script
        if [[ -x "$DEPENDENCIES_SCRIPT" ]]; then
            while IFS= read -r dependent; do
                if [[ ! " ${all_modules[*]} " =~ " ${dependent} " ]]; then
                    all_modules+=("$dependent")
                fi
            done < <(python "$DEPENDENCIES_SCRIPT" dependents "$module" 2>/dev/null || true)
        fi
    done
    
    # Remove duplicates and sort
    printf '%s\n' "${all_modules[@]}" | sort -u
}

# Function to run tests in workspace mode
run_tests_workspace() {
    local modules_to_test=("$@")
    
    log_info "Running tests in workspace mode"
    
    if [[ ${#modules_to_test[@]} -eq 0 ]]; then
        log_info "No modules to test"
        return 0
    fi
    
    # Create test paths for pytest
    local test_paths=()
    for module in "${modules_to_test[@]}"; do
        local module_path="$MODULES_DIR/$module"
        if [[ -d "$module_path/tests" ]]; then
            test_paths+=("$module_path/tests")
        fi
    done
    
    if [[ ${#test_paths[@]} -eq 0 ]]; then
        log_warning "No test directories found for modules: ${modules_to_test[*]}"
        return 0
    fi
    
    log_info "Testing modules: ${modules_to_test[*]}"
    log_info "Test paths: ${test_paths[*]}"
    
    # Run pytest from workspace root
    cd "$WORKSPACE_ROOT"
    
    # Ensure we have the right environment
    if [[ ! -d ".venv" ]]; then
        log_warning "No virtual environment found, creating one"
        uv venv
    fi
    
    # Install dependencies if needed
    if ! uv pip list | grep -q pytest; then
        log_info "Installing test dependencies"
        uv sync --dev
    fi
    
    # Run tests
    uv run pytest "${test_paths[@]}" \
        --verbose \
        --tb=short \
        --cov-report=term-missing \
        --cov-report=xml \
        --cov="$(IFS=,; echo "${modules_to_test[*]}")" \
        "$@"
}

# Function to run tests in package mode
run_tests_package() {
    local modules_to_test=("$@")
    
    log_info "Running tests in package mode"
    
    if [[ ${#modules_to_test[@]} -eq 0 ]]; then
        log_info "No modules to test"
        return 0
    fi
    
    # Test each module independently
    local failed_modules=()
    
    for module in "${modules_to_test[@]}"; do
        local module_path="$MODULES_DIR/$module"
        
        if [[ ! -d "$module_path" ]]; then
            log_warning "Module directory not found: $module_path"
            continue
        fi
        
        if [[ ! -d "$module_path/tests" ]]; then
            log_warning "No tests directory for module: $module"
            continue
        fi
        
        log_info "Testing module: $module"
        
        cd "$module_path"
        
        # Check if module has its own environment
        if [[ ! -d ".venv" ]]; then
            log_info "Setting up environment for $module"
            uv venv
            uv sync --dev
        fi
        
        # Run tests for this module
        if ! uv run pytest tests/ --verbose --tb=short; then
            failed_modules+=("$module")
            log_error "Tests failed for module: $module"
        else
            log_info "Tests passed for module: $module"
        fi
        
        cd "$WORKSPACE_ROOT"
    done
    
    # Report results
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        log_error "Tests failed for modules: ${failed_modules[*]}"
        return 1
    else
        log_info "All tests passed"
        return 0
    fi
}

# Function to validate environment
validate_environment() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi
    
    # Check if modules directory exists
    if [[ ! -d "$MODULES_DIR" ]]; then
        log_error "Modules directory not found: $MODULES_DIR"
        return 1
    fi
    
    # Check if UV is available
    if ! command -v uv >/dev/null 2>&1; then
        log_error "UV package manager not found. Please install UV first."
        return 1
    fi
    
    return 0
}

# Main function
main() {
    local base_ref="${1:-}"
    local head_ref="${2:-}"
    local force_all="${3:-}"
    
    # Validate environment
    if ! validate_environment; then
        exit 1
    fi
    
    # Detect operation mode
    local mode
    mode=$(detect_mode)
    log_info "Detected mode: $mode"
    
    # Get changed modules
    local changed_modules=()
    if [[ "$force_all" == "--all" ]]; then
        log_info "Running tests for all modules"
        while IFS= read -r module; do
            changed_modules+=("$module")
        done < <(find "$MODULES_DIR" -maxdepth 1 -type d -name "*" | while read -r dir; do
            if [[ -f "$dir/pyproject.toml" ]]; then
                basename "$dir"
            fi
        done)
    else
        while IFS= read -r module; do
            changed_modules+=("$module")
        done < <(get_changed_modules "$base_ref" "$head_ref")
    fi
    
    if [[ ${#changed_modules[@]} -eq 0 ]]; then
        log_info "No modules changed, skipping tests"
        return 0
    fi
    
    # Get all modules that need testing (including dependents)
    local modules_to_test=()
    while IFS= read -r module; do
        modules_to_test+=("$module")
    done < <(get_dependent_modules "${changed_modules[@]}")
    
    log_info "Changed modules: ${changed_modules[*]}"
    log_info "Modules to test (including dependents): ${modules_to_test[*]}"
    
    # Run tests based on mode
    if [[ "$mode" == "workspace" ]]; then
        run_tests_workspace "${modules_to_test[@]}"
    else
        run_tests_package "${modules_to_test[@]}"
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Handle command line arguments
    case "${1:-}" in
        --help|-h)
            echo "Usage: $0 [base_ref] [head_ref] [--all]"
            echo "  base_ref: Git ref to compare from (default: HEAD~1)"
            echo "  head_ref: Git ref to compare to (default: HEAD)"
            echo "  --all: Test all modules regardless of changes"
            echo ""
            echo "Examples:"
            echo "  $0                    # Test changes since last commit"
            echo "  $0 main HEAD         # Test changes since main branch"
            echo "  $0 --all             # Test all modules"
            exit 0
            ;;
        --all)
            main "" "" "--all"
            ;;
        *)
            main "$@"
            ;;
    esac
fi