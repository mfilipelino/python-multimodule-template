#!/bin/bash
# Advanced secrets detection for multi-module Python projects
# Scans for API keys, tokens, credentials, and other sensitive data

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXIT_CODE=0

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Secret patterns (regex)
declare -A SECRET_PATTERNS=(
    # API Keys
    ["API_KEY"]="(api[_-]?key|apikey)[\"'\\s]*[=:][\"'\\s]*[a-zA-Z0-9_\\-]{20,}"
    ["AWS_ACCESS_KEY"]="AKIA[0-9A-Z]{16}"
    ["AWS_SECRET_KEY"]="[\"'][0-9a-zA-Z/+]{40}[\"']"
    ["GITHUB_TOKEN"]="gh[pousr]_[A-Za-z0-9_]{36,251}"
    ["GOOGLE_API_KEY"]="AIza[0-9A-Za-z\\-_]{35}"
    ["SLACK_TOKEN"]="xox[bpoa]-[0-9]{12}-[0-9]{12}-[0-9a-zA-Z]{24}"
    ["STRIPE_KEY"]="[sr]k_(test|live)_[0-9a-zA-Z]{24,}"
    ["TWILIO_SID"]="AC[a-zA-Z0-9_\\-]{32}"
    ["MAILGUN_KEY"]="key-[0-9a-zA-Z]{32}"
    ["SENDGRID_KEY"]="SG\\.[0-9A-Za-z\\-_]{22}\\.[0-9A-Za-z\\-_]{43}"
    
    # Database URLs
    ["DATABASE_URL"]="(postgres|mysql|mongodb)://[^\\s\"']+:[^\\s\"']+@[^\\s\"']+[:/][^\\s\"']*"
    ["REDIS_URL"]="redis://[^\\s\"']+:[^\\s\"']*@[^\\s\"']+[:/][^\\s\"']*"
    
    # JWT Tokens
    ["JWT_TOKEN"]="eyJ[A-Za-z0-9_/+-]*\\.[A-Za-z0-9_/+-]*\\.[A-Za-z0-9_/+-]*"
    
    # Private Keys
    ["PRIVATE_KEY"]="-----BEGIN (RSA |DSA |EC |OPENSSH |)PRIVATE KEY-----"
    ["SSH_KEY"]="ssh-(rsa|dss|ed25519) [A-Za-z0-9+/]+"
    
    # Generic Secrets
    ["SECRET"]="(secret|password|passwd|pwd)[\"'\\s]*[=:][\"'\\s]*[^\\s\"']{8,}"
    ["TOKEN"]="(token|auth)[\"'\\s]*[=:][\"'\\s]*[a-zA-Z0-9_\\-]{16,}"
    ["CREDENTIAL"]="(credential|cred)[\"'\\s]*[=:][\"'\\s]*[^\\s\"']{8,}"
    
    # Credit Card Numbers (basic pattern)
    ["CREDIT_CARD"]="\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3[0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\\b"
    
    # Social Security Numbers
    ["SSN"]="\\b[0-9]{3}-[0-9]{2}-[0-9]{4}\\b"
    
    # Email addresses (in certain contexts)
    ["SUSPICIOUS_EMAIL"]="[a-zA-Z0-9._%+-]+@(gmail|yahoo|hotmail|outlook)\\.(com|net|org)"
    
    # IP Addresses (private ranges)
    ["PRIVATE_IP"]="\\b(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)([0-9]{1,3}\\.){1,2}[0-9]{1,3}\\b"
    
    # URLs with credentials
    ["URL_WITH_CREDS"]="https?://[^\\s\"']*:[^\\s\"']*@[^\\s\"']*"
)

# Files to exclude from scanning
EXCLUDE_PATTERNS=(
    "*.git/*"
    "*.venv/*"
    "*/__pycache__/*"
    "*.pyc"
    "*.pyo"
    "*/.pytest_cache/*"
    "*/node_modules/*"
    "*.egg-info/*"
    "*/dist/*"
    "*/build/*"
    "*/.tox/*"
    "*/.coverage"
    "*.log"
    "*.lock"
    "*/secrets-baseline.json"
    ".pre-commit-config.yaml"
    ".github/scripts/check-secrets.sh"
)

# Extensions to scan
SCAN_EXTENSIONS=(
    "*.py"
    "*.yml"
    "*.yaml" 
    "*.json"
    "*.toml"
    "*.ini"
    "*.cfg"
    "*.conf"
    "*.env"
    "*.txt"
    "*.md"
    "*.rst"
    "*.sh"
    "*.bash"
    "*.zsh"
    "*.fish"
    "Dockerfile*"
    "Makefile*"
    "*.mk"
)

# Function to check if file should be excluded
should_exclude() {
    local file="$1"
    
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file" == $pattern ]]; then
            return 0
        fi
    done
    
    return 1
}

# Function to check if file extension should be scanned
should_scan() {
    local file="$1"
    
    # Check if it matches any scan extension
    for ext in "${SCAN_EXTENSIONS[@]}"; do
        if [[ "$file" == $ext ]]; then
            return 0
        fi
    done
    
    # Check if it's a text file (fallback)
    if file "$file" 2>/dev/null | grep -q "text"; then
        return 0
    fi
    
    return 1
}

# Function to scan a single file
scan_file() {
    local file="$1"
    local found_secrets=false
    
    # Skip if file should be excluded
    if should_exclude "$file"; then
        return 0
    fi
    
    # Skip if file extension shouldn't be scanned
    if ! should_scan "$file"; then
        return 0
    fi
    
    # Skip if file doesn't exist or isn't readable
    if [[ ! -r "$file" ]]; then
        return 0
    fi
    
    # Scan file for each secret pattern
    for secret_type in "${!SECRET_PATTERNS[@]}"; do
        local pattern="${SECRET_PATTERNS[$secret_type]}"
        
        # Use grep to find matches (case insensitive)
        if grep -inE "$pattern" "$file" >/dev/null 2>&1; then
            if [[ "$found_secrets" == false ]]; then
                log_error "Potential secrets found in: $file"
                found_secrets=true
                EXIT_CODE=1
            fi
            
            # Show the matches with line numbers
            grep -inE --color=always "$pattern" "$file" | while IFS=: read -r line_num match; do
                log_error "  Line $line_num [$secret_type]: ${match:0:100}..."
            done
        fi
    done
    
    return 0
}

# Function to scan directory recursively
scan_directory() {
    local dir="$1"
    local file_count=0
    
    log_info "Scanning directory: $dir"
    
    # Find all files to scan
    while IFS= read -r -d '' file; do
        scan_file "$file"
        ((file_count++))
    done < <(find "$dir" -type f -print0 2>/dev/null)
    
    log_info "Scanned $file_count files in $dir"
}

# Function to validate specific patterns (reduce false positives)
validate_findings() {
    local file="$1"
    local line_num="$2"
    local match="$3"
    local secret_type="$4"
    
    # Skip test files and documentation
    if [[ "$file" =~ (test|example|sample|demo|doc) ]]; then
        return 1
    fi
    
    # Skip comments in Python files
    if [[ "$file" =~ \.py$ ]] && [[ "$match" =~ ^[[:space:]]*# ]]; then
        return 1
    fi
    
    # Skip URLs in documentation
    if [[ "$file" =~ \.(md|rst|txt)$ ]] && [[ "$secret_type" == "URL_WITH_CREDS" ]]; then
        return 1
    fi
    
    # Additional validation can be added here
    return 0
}

# Function to generate baseline file
generate_baseline() {
    local baseline_file="$WORKSPACE_ROOT/.secrets-baseline.json"
    
    log_info "Generating secrets baseline file: $baseline_file"
    
    # This is a simplified baseline - in practice, you'd want a more sophisticated approach
    cat > "$baseline_file" << 'EOF'
{
  "version": "1.0.0",
  "plugins_used": [
    {
      "name": "custom-secrets-detector"
    }
  ],
  "filters_used": [
    {
      "path": "detect_secrets.filters.common.is_baseline_file"
    }
  ],
  "results": {},
  "generated_at": "2024-01-01T00:00:00Z"
}
EOF
    
    log_info "Baseline file generated. You can customize it to exclude known false positives."
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [PATHS...]

Advanced secrets detection for multi-module Python projects.

OPTIONS:
  -h, --help          Show this help message
  -b, --baseline      Generate baseline file for excluding known false positives
  -v, --verbose       Verbose output
  -q, --quiet         Quiet mode (errors only)
  --no-color          Disable colored output

PATHS:
  Specific files or directories to scan (default: current directory)

EXAMPLES:
  $0                                 # Scan current directory
  $0 modules/module1/               # Scan specific module
  $0 file1.py file2.py              # Scan specific files
  $0 --baseline                     # Generate baseline file
  $0 --verbose modules/             # Verbose scan of modules

EXIT CODES:
  0 - No secrets found
  1 - Secrets detected
  2 - Error in execution
EOF
}

# Function to process command line arguments
process_args() {
    local paths=()
    local generate_baseline_flag=false
    local verbose=false
    local quiet=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--baseline)
                generate_baseline_flag=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            --no-color)
                RED=''
                YELLOW=''
                GREEN=''
                NC=''
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 2
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done
    
    # Generate baseline if requested
    if [[ "$generate_baseline_flag" == true ]]; then
        generate_baseline
        exit 0
    fi
    
    # Default to current directory if no paths specified
    if [[ ${#paths[@]} -eq 0 ]]; then
        paths=("$WORKSPACE_ROOT")
    fi
    
    # Scan specified paths
    for path in "${paths[@]}"; do
        if [[ -f "$path" ]]; then
            scan_file "$path"
        elif [[ -d "$path" ]]; then
            scan_directory "$path"
        else
            log_warning "Path not found: $path"
        fi
    done
}

# Main execution
main() {
    log_info "Starting secrets detection scan"
    log_info "Workspace root: $WORKSPACE_ROOT"
    
    cd "$WORKSPACE_ROOT"
    
    if [[ $# -eq 0 ]]; then
        # Default scan of workspace
        scan_directory "$WORKSPACE_ROOT"
    else
        # Process command line arguments
        process_args "$@"
    fi
    
    if [[ $EXIT_CODE -eq 0 ]]; then
        log_info "No secrets detected. Scan completed successfully."
    else
        log_error "Potential secrets detected! Please review the findings above."
        log_error "If these are false positives, consider:"
        log_error "1. Moving test data to appropriate test files"
        log_error "2. Using environment variables for real secrets"
        log_error "3. Adding specific exclusions to this script"
        log_error "4. Generating a baseline file with --baseline"
    fi
    
    exit $EXIT_CODE
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi