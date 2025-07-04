#!/bin/bash
set -euo pipefail

# Developer environment setup script
# This script sets up a complete development environment for the multi-module project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up development environment for multi-module Python project...${NC}"
echo ""

# Check if we're in the project root
if [ ! -f "pyproject.toml" ] || [ ! -d "modules" ]; then
    echo -e "${RED}❌ Please run this script from the project root directory${NC}"
    exit 1
fi

# Step 1: Check Python version
echo -e "${YELLOW}📋 Step 1: Checking Python version...${NC}"
if command -v python3.12 &> /dev/null; then
    python_cmd="python3.12"
elif command -v python3 &> /dev/null; then
    python_version=$(python3 --version | grep -oE '3\.[0-9]+')
    if [[ $(echo "$python_version >= 3.12" | bc -l) -eq 1 ]]; then
        python_cmd="python3"
    else
        echo -e "${RED}❌ Python 3.12+ is required. Found: $python_version${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Python 3.12+ is required but not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Python version check passed: $(${python_cmd} --version)${NC}"
echo ""

# Step 2: Check UV installation
echo -e "${YELLOW}📋 Step 2: Checking UV installation...${NC}"
if ! command -v uv &> /dev/null; then
    echo -e "${YELLOW}⚠️  UV not found. Installing UV...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
    
    if ! command -v uv &> /dev/null; then
        echo -e "${RED}❌ Failed to install UV. Please install manually: https://github.com/astral-sh/uv${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ UV check passed: $(uv --version)${NC}"
echo ""

# Step 3: Pin Python version
echo -e "${YELLOW}📋 Step 3: Setting up Python version...${NC}"
if [ ! -f ".python-version" ]; then
    echo "3.12" > .python-version
    echo -e "${GREEN}✅ Created .python-version file${NC}"
else
    echo -e "${GREEN}✅ .python-version file already exists${NC}"
fi
echo ""

# Step 4: Install workspace dependencies
echo -e "${YELLOW}📋 Step 4: Installing workspace dependencies...${NC}"
if uv sync --dev; then
    echo -e "${GREEN}✅ Workspace dependencies installed successfully${NC}"
else
    echo -e "${RED}❌ Failed to install workspace dependencies${NC}"
    exit 1
fi
echo ""

# Step 5: Install pre-commit hooks
echo -e "${YELLOW}📋 Step 5: Setting up pre-commit hooks...${NC}"
if make pre-commit-install; then
    echo -e "${GREEN}✅ Pre-commit hooks installed successfully${NC}"
else
    echo -e "${RED}❌ Failed to install pre-commit hooks${NC}"
    exit 1
fi
echo ""

# Step 6: Run initial tests
echo -e "${YELLOW}📋 Step 6: Running initial tests...${NC}"
if make test; then
    echo -e "${GREEN}✅ All tests passed${NC}"
else
    echo -e "${RED}❌ Some tests failed. Please check the output above.${NC}"
    exit 1
fi
echo ""

# Step 7: Run linting
echo -e "${YELLOW}📋 Step 7: Running code linting...${NC}"
if make lint; then
    echo -e "${GREEN}✅ All linting checks passed${NC}"
else
    echo -e "${RED}❌ Linting issues found. Please check the output above.${NC}"
    exit 1
fi
echo ""

# Step 8: Initialize git hooks (if in git repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${YELLOW}📋 Step 8: Configuring Git...${NC}"
    
    # Set up conventional commit template
    if [ ! -f ".gitmessage" ]; then
        cat > .gitmessage << 'EOF'
# <type>(<scope>): <subject>
#
# <body>
#
# <footer>

# Type can be:
#   feat     (new feature)
#   fix      (bug fix)
#   docs     (documentation)
#   style    (formatting, missing semicolons, etc)
#   refactor (code change that neither fixes bug nor adds feature)
#   perf     (performance improvement)
#   test     (adding missing tests)
#   chore    (maintain, build process, etc)
#
# Scope is optional and should be the module name if specific to one module
#
# Breaking changes should include "BREAKING CHANGE:" in the footer
# or add ! after the type/scope: feat!: breaking change
EOF
        git config commit.template .gitmessage
        echo -e "${GREEN}✅ Git commit template configured${NC}"
    fi
    
    # Configure git to use conventional commits
    git config --local commit.template .gitmessage
    echo -e "${GREEN}✅ Git configuration completed${NC}"
else
    echo -e "${YELLOW}⚠️  Not in a git repository, skipping git configuration${NC}"
fi
echo ""

# Step 9: Display development commands
echo -e "${BLUE}🎉 Development environment setup completed!${NC}"
echo ""
echo -e "${YELLOW}📚 Quick start commands:${NC}"
echo "  make help                    # Show all available commands"
echo "  make test                    # Run all tests"
echo "  make lint                    # Run all linting checks"
echo "  make version-show            # Show current versions"
echo "  make pre-commit-run          # Run pre-commit on all files"
echo ""
echo -e "${YELLOW}🔧 Development workflow:${NC}"
echo "  1. Make changes to modules"
echo "  2. Stage your changes: git add ."
echo "  3. Commit (pre-commit hooks will run automatically): git commit"
echo "  4. Pre-commit will check your code and enforce conventional commits"
echo ""
echo -e "${YELLOW}📖 More information:${NC}"
echo "  - Pre-commit hooks run automatically on git commit"
echo "  - Use conventional commit format: type(scope): description"
echo "  - Tests run automatically for changed modules only"
echo "  - Semantic versioning based on conventional commits"
echo ""
echo -e "${GREEN}✅ Happy coding! 🚀${NC}"