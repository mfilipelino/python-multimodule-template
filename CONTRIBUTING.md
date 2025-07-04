# Contributing to Python Multi-Module Template

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/mfilipelino/python-multimodule-template.git
   cd python-multimodule-template
   ```

2. **Install prerequisites**
   - Python 3.12+
   - [UV package manager](https://github.com/astral-sh/uv)
   - Make

3. **Set up the development environment**
   ```bash
   make all
   ```

## Development Workflow

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the existing code style
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**
   ```bash
   make test    # Run all tests
   make lint    # Run linting
   ```

   Note: The CI system will automatically detect which modules changed and only test those modules + their dependents. This provides faster feedback while maintaining correctness.

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: your descriptive commit message"
   ```

5. **Push and create a pull request**
   ```bash
   git push origin feature/your-feature-name
   ```

## Code Standards

### Linting and Formatting
- **Black** for code formatting
- **Ruff** for linting and import sorting
- **Bandit** for security analysis
- **Pyright** for type checking

Run all linting with: `make lint`
Auto-format code with: `make format`

### Testing
- Write tests for all new functionality
- Maintain 100% test coverage
- Use descriptive test names
- Follow the existing test patterns

### Documentation
- Update README.md for new features
- Add docstrings to all functions and classes
- Update help text in Makefiles

## Project Structure

```
├── module1/              # Base module (no dependencies)
├── module2/              # Example dependent module
├── shared/               # Shared package repository
├── .github/              # GitHub workflows and templates
├── Makefile              # Root build commands
└── README.md
```

## Adding New Modules

1. Create a new directory following the pattern `moduleN/`
2. Copy the structure from an existing module
3. Update the root `Makefile` `MODULE_ORDER` to include the new module
4. Add dependencies to the new module's `pyproject.toml` if needed

## Commit Message Format

Use conventional commits:
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `style:` for formatting changes
- `refactor:` for code refactoring
- `test:` for test additions
- `chore:` for maintenance tasks

## Reporting Issues

- Use the GitHub issue templates
- Provide clear reproduction steps
- Include environment details
- Add relevant logs or error messages

## Questions?

Feel free to open an issue for any questions about contributing!