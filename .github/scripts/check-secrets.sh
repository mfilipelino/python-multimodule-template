#!/bin/bash
set -euo pipefail

# Check for potential secrets in code
# This script scans for common patterns that might indicate secrets

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔐 Checking for potential secrets...${NC}"

# Patterns to look for (case-insensitive)
declare -a SECRET_PATTERNS=(
    # API Keys and tokens
    "api[_-]?key\s*[=:]\s*['\"][^'\"]{20,}['\"]"
    "api[_-]?token\s*[=:]\s*['\"][^'\"]{20,}['\"]"
    "access[_-]?token\s*[=:]\s*['\"][^'\"]{20,}['\"]"
    "auth[_-]?token\s*[=:]\s*['\"][^'\"]{20,}['\"]"
    "bearer\s+[a-zA-Z0-9\-_.]{20,}"
    
    # AWS credentials
    "aws[_-]?access[_-]?key[_-]?id\s*[=:]\s*['\"][^'\"]{16,}['\"]"
    "aws[_-]?secret[_-]?access[_-]?key\s*[=:]\s*['\"][^'\"]{28,}['\"]"
    "AKIA[0-9A-Z]{16}"
    
    # GitHub tokens
    "gh[ps]_[a-zA-Z0-9]{36}"
    "github[_-]?token\s*[=:]\s*['\"][^'\"]{20,}['\"]"
    
    # Database URLs with credentials
    "://[^:/\s]+:[^@/\s]+@[^/\s]+"
    
    # Private keys
    "-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----"
    "-----BEGIN\s+OPENSSH\s+PRIVATE\s+KEY-----"
    
    # JWT tokens (basic pattern)
    "ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9._-]{10,}\.[A-Za-z0-9._-]{10,}"
    
    # Generic secrets
    "secret\s*[=:]\s*['\"][^'\"]{16,}['\"]"
    "password\s*[=:]\s*['\"][^'\"]{8,}['\"]"
    
    # Credit card numbers (basic pattern)
    "\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3[0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b"
    
    # Social Security Numbers
    "\b\d{3}-\d{2}-\d{4}\b"
    
    # Email addresses in config (potential exposure)
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
)

# Files to exclude from scanning
EXCLUDE_PATTERNS=(
    "\.git/"
    "\.venv/"
    "__pycache__/"
    "\.pyc$"
    "\.pyo$"
    "\.egg-info/"
    "build/"
    "dist/"
    "node_modules/"
    "\.log$"
    "\.coverage"
    "htmlcov/"
    "\.pytest_cache/"
    "uv\.lock$"
    "poetry\.lock$"
    "Pipfile\.lock$"
    "\.pre-commit-config\.yaml$"  # This file contains examples
    "check-secrets\.sh$"          # This file contains patterns
)

# Get files to check (staged files if in git, otherwise all files)
if git rev-parse --git-dir > /dev/null 2>&1; then
    # In git repository - check staged files
    files_to_check=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
    if [ -z "$files_to_check" ]; then
        # No staged files, check working directory changes
        files_to_check=$(git diff --name-only --diff-filter=ACMR 2>/dev/null || true)
    fi
else
    # Not in git - check all text files
    files_to_check=$(find . -type f -name "*.py" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.toml" -o -name "*.env*" -o -name "*.conf" -o -name "*.config" 2>/dev/null || true)
fi

if [ -z "$files_to_check" ]; then
    echo -e "${GREEN}✅ No files to check${NC}"
    exit 0
fi

# Filter out excluded files
filtered_files=""
while IFS= read -r file; do
    should_exclude=false
    for exclude_pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file" =~ $exclude_pattern ]]; then
            should_exclude=true
            break
        fi
    done
    
    if [ "$should_exclude" = false ] && [ -f "$file" ]; then
        filtered_files="$filtered_files$file"$'\n'
    fi
done <<< "$files_to_check"

if [ -z "$filtered_files" ]; then
    echo -e "${GREEN}✅ No relevant files to check${NC}"
    exit 0
fi

echo -e "${YELLOW}📁 Checking files:${NC}"
echo "$filtered_files" | sed 's/^/  /' | head -10
if [ $(echo "$filtered_files" | wc -l) -gt 10 ]; then
    echo "  ... and $(( $(echo "$filtered_files" | wc -l) - 10 )) more files"
fi
echo ""

# Check each file for secret patterns
found_secrets=false
temp_results=$(mktemp)

while IFS= read -r file; do
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        continue
    fi
    
    # Skip binary files
    if file "$file" | grep -q "binary"; then
        continue
    fi
    
    for pattern in "${SECRET_PATTERNS[@]}"; do
        # Use grep with Perl-compatible regex for better pattern matching
        matches=$(grep -inP "$pattern" "$file" 2>/dev/null || true)
        if [ -n "$matches" ]; then
            echo "🚨 POTENTIAL SECRET in $file:" >> "$temp_results"
            echo "$matches" | sed 's/^/  /' >> "$temp_results"
            echo "" >> "$temp_results"
            found_secrets=true
        fi
    done
done <<< "$filtered_files"

# Display results
if [ "$found_secrets" = true ]; then
    echo -e "${RED}❌ Potential secrets found:${NC}"
    echo ""
    cat "$temp_results"
    echo ""
    echo -e "${RED}⚠️  Please review these findings and:${NC}"
    echo -e "${RED}   1. Remove any actual secrets from the code${NC}"
    echo -e "${RED}   2. Use environment variables or secure vaults for secrets${NC}"
    echo -e "${RED}   3. Add false positives to .gitignore or exclusion patterns${NC}"
    echo ""
    rm -f "$temp_results"
    exit 1
else
    echo -e "${GREEN}✅ No potential secrets found${NC}"
    rm -f "$temp_results"
    exit 0
fi