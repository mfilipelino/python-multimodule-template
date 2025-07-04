#!/bin/bash
set -euo pipefail

# Get build order for modules up to a specific target
# Usage: ./get-build-order.sh [target-module]

TARGET_MODULE="${1:-}"

# Get module dependencies
get_module_dependencies() {
    local module="$1"
    case "$module" in
        "module1") echo "" ;;
        "module2") echo "module1" ;;
        *) echo "" ;;
    esac
}

# Get all modules in dependency order
get_all_modules_in_order() {
    echo "module1"
    echo "module2"
}

# Main logic
main() {
    if [[ -z "$TARGET_MODULE" ]]; then
        # Return all modules in order
        get_all_modules_in_order
    else
        # Return modules needed to build target (including target)
        local all_modules
        all_modules=$(get_all_modules_in_order)
        
        while IFS= read -r module; do
            echo "$module"
            if [[ "$module" == "$TARGET_MODULE" ]]; then
                break
            fi
        done <<< "$all_modules"
    fi
}

main "$@"