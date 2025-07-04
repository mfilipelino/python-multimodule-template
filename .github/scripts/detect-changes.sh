#!/bin/bash
set -euo pipefail

# Detect changed modules for selective CI testing
# Usage: ./detect-changes.sh [base-ref] [head-ref]
# Returns JSON array of modules to test

# Default to comparing with main branch
BASE_REF="${1:-origin/main}"
HEAD_REF="${2:-HEAD}"

# Get module dependencies using dynamic discovery
get_module_dependencies() {
    local module="$1"
    python .github/scripts/discover-dependencies.py dependencies "$module" 2>/dev/null || echo ""
}

# Get all available modules using dynamic discovery
get_all_modules() {
    python .github/scripts/discover-dependencies.py list 2>/dev/null || find ./modules -maxdepth 1 -type d -name "module*" | sed 's|^\./modules/||' | sort
}

# Get changed files
get_changed_files() {
    if git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
        git diff --name-only "$BASE_REF...$HEAD_REF"
    else
        # If base ref doesn't exist (e.g., first push), get all files
        git ls-files
    fi
}

# Map file to module
file_to_module() {
    local file="$1"
    
    # Check if file belongs to a specific module
    if [[ "$file" =~ ^(module[0-9]+)/ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Root files that affect all modules
    if [[ "$file" =~ ^(Makefile|\.github/workflows|shared/) ]]; then
        echo "all"
        return 0
    fi
    
    # Documentation-only changes (skip CI)
    if [[ "$file" =~ ^(README\.md|LICENSE|CONTRIBUTING\.md|\.github/ISSUE_TEMPLATE|\.github/pull_request_template\.md)$ ]]; then
        echo "docs"
        return 0
    fi
    
    # Other files affect all modules
    echo "all"
}

# Get dependents of a module using dynamic discovery
get_dependents() {
    local target_module="$1"
    python .github/scripts/discover-dependencies.py dependents "$target_module" 2>/dev/null || echo ""
}

# Main logic
main() {
    local changed_files
    local affected_modules=()
    local all_modules
    
    changed_files=$(get_changed_files)
    all_modules=($(get_all_modules))
    
    if [[ -z "$changed_files" ]]; then
        echo "No changes detected"
        echo "[]"
        return 0
    fi
    
    echo "Changed files:" >&2
    echo "$changed_files" >&2
    echo "" >&2
    
    # Track unique modules using a temporary file
    local temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT
    
    # Process each changed file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        local module
        module=$(file_to_module "$file")
        
        case "$module" in
            "docs")
                echo "Documentation-only change detected: $file" >&2
                ;;
            "all")
                echo "Root file change detected: $file (affects all modules)" >&2
                printf '%s\n' "${all_modules[@]}" >> "$temp_file"
                ;;
            *)
                echo "Module change detected: $file -> $module" >&2
                echo "$module" >> "$temp_file"
                
                # Add dependents
                local dependents
                dependents=$(get_dependents "$module")
                if [[ -n "$dependents" ]]; then
                    echo "  Adding dependents: $dependents" >&2
                    echo "$dependents" >> "$temp_file"
                fi
                ;;
        esac
    done <<< "$changed_files"
    
    # Get unique sorted modules
    if [[ -s "$temp_file" ]]; then
        affected_modules=($(sort -u "$temp_file"))
    fi
    
    # Output results
    if [[ ${#affected_modules[@]} -eq 0 ]]; then
        echo "No modules affected by changes" >&2
        echo "[]"
    else
        echo "Modules to test: ${affected_modules[*]}" >&2
        printf '%s\n' "${affected_modules[@]}" | jq -R . | jq -s -c .
    fi
}

main "$@"