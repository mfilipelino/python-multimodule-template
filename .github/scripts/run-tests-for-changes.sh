#!/bin/bash
set -euo pipefail

# Run tests for changed modules only (for pre-commit hook)
# This script detects which modules have changed and runs tests for them

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧪 Running tests for changed modules...${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Not in a git repository, running all tests${NC}"
    make test
    exit $?
fi

# Get staged files (for pre-commit)
staged_files=$(git diff --cached --name-only --diff-filter=ACMR)

# If no staged files, check working directory changes
if [ -z "$staged_files" ]; then
    staged_files=$(git diff --name-only --diff-filter=ACMR)
fi

# If still no files, run all tests
if [ -z "$staged_files" ]; then
    echo -e "${YELLOW}⚠️  No changed files detected, running all tests${NC}"
    make test
    exit $?
fi

echo -e "${YELLOW}📁 Changed files:${NC}"
echo "$staged_files" | sed 's/^/  /'
echo ""

# Determine which modules are affected
affected_modules=()
root_files_changed=false

while IFS= read -r file; do
    if [[ "$file" =~ ^modules/([^/]+)/ ]]; then
        module_name="${BASH_REMATCH[1]}"
        if [[ ! " ${affected_modules[@]} " =~ " ${module_name} " ]]; then
            affected_modules+=("$module_name")
        fi
    elif [[ "$file" =~ ^(pyproject\.toml|Makefile|\.github/workflows/) ]]; then
        root_files_changed=true
    fi
done <<< "$staged_files"

# If root files changed, test all modules
if [ "$root_files_changed" = true ]; then
    echo -e "${YELLOW}🌍 Root configuration files changed, testing all modules${NC}"
    make test
    exit $?
fi

# If no modules affected, skip tests
if [ ${#affected_modules[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ No module files changed, skipping tests${NC}"
    exit 0
fi

# Add dependent modules to the test list
all_modules_to_test=()
for module in "${affected_modules[@]}"; do
    all_modules_to_test+=("$module")
    
    # Get dependents using our dependency discovery script
    dependents=$(python .github/scripts/discover-dependencies.py dependents "$module" 2>/dev/null || echo "")
    if [ -n "$dependents" ]; then
        echo -e "${YELLOW}📦 Module $module has dependents: $dependents${NC}"
        for dependent in $dependents; do
            if [[ ! " ${all_modules_to_test[@]} " =~ " ${dependent} " ]]; then
                all_modules_to_test+=("$dependent")
            fi
        done
    fi
done

# Remove duplicates and sort
IFS=" " read -r -a unique_modules <<< "$(printf '%s\n' "${all_modules_to_test[@]}" | sort -u | tr '\n' ' ')"

echo -e "${YELLOW}🎯 Testing modules: ${unique_modules[*]}${NC}"
echo ""

# Check if we're in workspace mode
workspace_mode=0
if [ -f pyproject.toml ] && grep -q "\[tool.uv.workspace\]" pyproject.toml; then
    workspace_mode=1
fi

# Run tests for each affected module
test_failed=false
for module in "${unique_modules[@]}"; do
    echo -e "${YELLOW}🧪 Testing $module...${NC}"
    
    if [ "$workspace_mode" = "1" ]; then
        # Workspace mode - use UV to run tests
        if ! uv run pytest "modules/$module/tests/" -v; then
            echo -e "${RED}❌ Tests failed for $module${NC}"
            test_failed=true
        else
            echo -e "${GREEN}✅ Tests passed for $module${NC}"
        fi
    else
        # Package mode - use module makefile
        if ! make -C "modules/$module" test; then
            echo -e "${RED}❌ Tests failed for $module${NC}"
            test_failed=true
        else
            echo -e "${GREEN}✅ Tests passed for $module${NC}"
        fi
    fi
    echo ""
done

# Final result
if [ "$test_failed" = true ]; then
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed for affected modules${NC}"
    exit 0
fi