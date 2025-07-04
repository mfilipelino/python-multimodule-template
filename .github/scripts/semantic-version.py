#!/usr/bin/env python3
"""
Semantic versioning automation with conventional commits support.

This script analyzes conventional commits to determine semantic version bumps
and manages versioning across multi-module projects.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Conventional commit patterns
COMMIT_PATTERN = re.compile(
    r"^(?P<type>\w+)(?:\((?P<scope>[\w\-\/]+)\))?"
    r"(?P<breaking>!)?: (?P<description>.+)"
    r"(?:\n\n(?P<body>.*?))?(?:\n\n(?P<footer>.*?))?$",
    re.DOTALL
)

# Version bump types
class VersionBump:
    MAJOR = "major"
    MINOR = "minor" 
    PATCH = "patch"
    NONE = "none"

# Conventional commit types and their version impact
COMMIT_TYPES = {
    "feat": VersionBump.MINOR,      # New feature
    "fix": VersionBump.PATCH,       # Bug fix
    "docs": VersionBump.NONE,       # Documentation only
    "style": VersionBump.NONE,      # Formatting, missing semicolons, etc
    "refactor": VersionBump.PATCH,  # Code change that neither fixes bug nor adds feature
    "perf": VersionBump.PATCH,      # Performance improvement
    "test": VersionBump.NONE,       # Adding missing tests
    "chore": VersionBump.NONE,      # Maintain, build process, etc
    "ci": VersionBump.NONE,         # CI/CD changes
    "build": VersionBump.NONE,      # Build system changes
    "revert": VersionBump.PATCH,    # Reverting changes
}

class SemanticVersion:
    """Semantic version representation."""
    
    def __init__(self, major: int = 0, minor: int = 1, patch: int = 0, 
                 prerelease: str = "", metadata: str = ""):
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.metadata = metadata
    
    @classmethod
    def parse(cls, version_str: str) -> "SemanticVersion":
        """Parse a semantic version string."""
        # Remove 'v' prefix if present
        version_str = version_str.lstrip('v')
        
        # Split on '+' for metadata
        if '+' in version_str:
            version_str, metadata = version_str.split('+', 1)
        else:
            metadata = ""
        
        # Split on '-' for prerelease
        if '-' in version_str:
            version_str, prerelease = version_str.split('-', 1)
        else:
            prerelease = ""
        
        # Parse major.minor.patch
        parts = version_str.split('.')
        if len(parts) != 3:
            raise ValueError(f"Invalid semantic version: {version_str}")
        
        major, minor, patch = map(int, parts)
        return cls(major, minor, patch, prerelease, metadata)
    
    def bump(self, bump_type: str) -> "SemanticVersion":
        """Create a new version with the specified bump."""
        if bump_type == VersionBump.MAJOR:
            return SemanticVersion(self.major + 1, 0, 0)
        elif bump_type == VersionBump.MINOR:
            return SemanticVersion(self.major, self.minor + 1, 0)
        elif bump_type == VersionBump.PATCH:
            return SemanticVersion(self.major, self.minor, self.patch + 1)
        else:
            return SemanticVersion(self.major, self.minor, self.patch, 
                                 self.prerelease, self.metadata)
    
    def __str__(self) -> str:
        version = f"{self.major}.{self.minor}.{self.patch}"
        if self.prerelease:
            version += f"-{self.prerelease}"
        if self.metadata:
            version += f"+{self.metadata}"
        return version
    
    def __repr__(self) -> str:
        return f"SemanticVersion({self})"


class ConventionalCommit:
    """Represents a conventional commit."""
    
    def __init__(self, commit_hash: str, message: str):
        self.commit_hash = commit_hash
        self.message = message
        self.parsed = self._parse_message(message)
    
    def _parse_message(self, message: str) -> Optional[Dict]:
        """Parse conventional commit message."""
        match = COMMIT_PATTERN.match(message.strip())
        if not match:
            return None
        
        result = match.groupdict()
        
        # Check for breaking changes
        is_breaking = (
            result.get("breaking") == "!" or
            (result.get("footer") and "BREAKING CHANGE:" in result["footer"])
        )
        
        result["is_breaking"] = is_breaking
        return result
    
    def get_version_bump(self) -> str:
        """Determine version bump type for this commit."""
        if not self.parsed:
            return VersionBump.NONE
        
        # Breaking changes always trigger major version bump
        if self.parsed["is_breaking"]:
            return VersionBump.MAJOR
        
        # Get bump type from commit type
        commit_type = self.parsed["type"]
        return COMMIT_TYPES.get(commit_type, VersionBump.NONE)
    
    def affects_module(self, module_name: str) -> bool:
        """Check if this commit affects a specific module."""
        if not self.parsed:
            return False
        
        scope = self.parsed.get("scope", "")
        
        # Check if scope matches module name
        if scope == module_name:
            return True
        
        # Check if commit message mentions the module
        message_lower = self.message.lower()
        module_lower = module_name.lower()
        
        return (
            f"modules/{module_lower}" in message_lower or
            f"module {module_lower}" in message_lower or
            module_lower in message_lower
        )


class VersionManager:
    """Manages semantic versioning for multi-module projects."""
    
    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
    
    def get_current_version(self, module_path: Optional[Path] = None) -> SemanticVersion:
        """Get current version from pyproject.toml."""
        if module_path:
            pyproject_path = module_path / "pyproject.toml"
        else:
            pyproject_path = self.workspace_root / "pyproject.toml"
        
        try:
            with open(pyproject_path, "r") as f:
                content = f.read()
            
            # Extract version using regex (simple approach)
            version_match = re.search(r'version\s*=\s*"([^"]+)"', content)
            if version_match:
                return SemanticVersion.parse(version_match.group(1))
            else:
                logger.warning(f"No version found in {pyproject_path}")
                return SemanticVersion()
        except FileNotFoundError:
            logger.warning(f"File not found: {pyproject_path}")
            return SemanticVersion()
    
    def update_version(self, new_version: SemanticVersion, 
                      module_path: Optional[Path] = None) -> bool:
        """Update version in pyproject.toml."""
        if module_path:
            pyproject_path = module_path / "pyproject.toml"
        else:
            pyproject_path = self.workspace_root / "pyproject.toml"
        
        try:
            with open(pyproject_path, "r") as f:
                content = f.read()
            
            # Replace version using regex
            new_content = re.sub(
                r'version\s*=\s*"[^"]+"',
                f'version = "{new_version}"',
                content
            )
            
            with open(pyproject_path, "w") as f:
                f.write(new_content)
            
            logger.info(f"Updated {pyproject_path} to version {new_version}")
            return True
        except Exception as e:
            logger.error(f"Failed to update {pyproject_path}: {e}")
            return False
    
    def get_commits_since_tag(self, tag: Optional[str] = None) -> List[ConventionalCommit]:
        """Get commits since the last tag (or all commits if no tag)."""
        try:
            if tag:
                cmd = ["git", "log", f"{tag}..HEAD", "--oneline", "--no-merges"]
            else:
                # Get last tag
                result = subprocess.run(
                    ["git", "describe", "--tags", "--abbrev=0"],
                    capture_output=True, text=True, cwd=self.workspace_root
                )
                if result.returncode == 0:
                    last_tag = result.stdout.strip()
                    cmd = ["git", "log", f"{last_tag}..HEAD", "--oneline", "--no-merges"]
                else:
                    # No tags, get all commits
                    cmd = ["git", "log", "--oneline", "--no-merges"]
            
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.workspace_root)
            if result.returncode != 0:
                logger.error(f"Git command failed: {result.stderr}")
                return []
            
            commits = []
            for line in result.stdout.strip().split('\n'):
                if not line:
                    continue
                parts = line.split(' ', 1)
                if len(parts) >= 2:
                    commit_hash, message = parts[0], parts[1]
                    commits.append(ConventionalCommit(commit_hash, message))
            
            return commits
        except Exception as e:
            logger.error(f"Failed to get commits: {e}")
            return []
    
    def find_modules(self) -> List[Path]:
        """Find all modules in the workspace."""
        modules_dir = self.workspace_root / "modules"
        if not modules_dir.exists():
            return []
        
        modules = []
        for item in modules_dir.iterdir():
            if item.is_dir() and (item / "pyproject.toml").exists():
                modules.append(item)
        
        return sorted(modules)
    
    def calculate_version_bumps(self, commits: List[ConventionalCommit]) -> Dict[str, str]:
        """Calculate version bumps for workspace and all modules."""
        # Initialize results
        results = {"workspace": VersionBump.NONE}
        modules = self.find_modules()
        
        for module_path in modules:
            results[module_path.name] = VersionBump.NONE
        
        # Analyze each commit
        for commit in commits:
            commit_bump = commit.get_version_bump()
            
            if commit_bump == VersionBump.NONE:
                continue
            
            # Check if commit affects workspace
            workspace_affected = not any(
                commit.affects_module(module.name) for module in modules
            )
            
            if workspace_affected:
                results["workspace"] = max_bump(results["workspace"], commit_bump)
            
            # Check which modules are affected
            for module_path in modules:
                if commit.affects_module(module_path.name):
                    current_bump = results[module_path.name]
                    results[module_path.name] = max_bump(current_bump, commit_bump)
        
        return results


def max_bump(bump1: str, bump2: str) -> str:
    """Return the higher priority version bump."""
    priority = {
        VersionBump.NONE: 0,
        VersionBump.PATCH: 1,
        VersionBump.MINOR: 2,
        VersionBump.MAJOR: 3
    }
    
    if priority[bump1] >= priority[bump2]:
        return bump1
    else:
        return bump2


def main():
    """Main CLI interface."""
    parser = argparse.ArgumentParser(description="Semantic versioning automation")
    parser.add_argument("--workspace", type=Path, default=Path.cwd(),
                       help="Workspace root directory")
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Analyze command
    analyze_parser = subparsers.add_parser("analyze", help="Analyze commits for version bumps")
    analyze_parser.add_argument("--since-tag", help="Analyze commits since specific tag")
    analyze_parser.add_argument("--format", choices=["json", "table"], default="table",
                               help="Output format")
    
    # Bump command
    bump_parser = subparsers.add_parser("bump", help="Bump versions based on commits")
    bump_parser.add_argument("--dry-run", action="store_true",
                            help="Show what would be done without making changes")
    bump_parser.add_argument("--since-tag", help="Analyze commits since specific tag")
    
    # Version command
    version_parser = subparsers.add_parser("version", help="Show current versions")
    version_parser.add_argument("--module", help="Show version for specific module")
    
    args = parser.parse_args()
    
    version_manager = VersionManager(args.workspace)
    
    if args.command == "analyze":
        commits = version_manager.get_commits_since_tag(args.since_tag)
        version_bumps = version_manager.calculate_version_bumps(commits)
        
        if args.format == "json":
            print(json.dumps(version_bumps, indent=2))
        else:
            print("Version bump analysis:")
            print("-" * 40)
            for component, bump_type in version_bumps.items():
                if bump_type != VersionBump.NONE:
                    print(f"{component:20} → {bump_type}")
                else:
                    print(f"{component:20} → no change")
    
    elif args.command == "bump":
        commits = version_manager.get_commits_since_tag(args.since_tag)
        version_bumps = version_manager.calculate_version_bumps(commits)
        
        print("Updating versions:")
        print("-" * 40)
        
        # Update workspace version
        if version_bumps["workspace"] != VersionBump.NONE:
            current_version = version_manager.get_current_version()
            new_version = current_version.bump(version_bumps["workspace"])
            
            print(f"Workspace: {current_version} → {new_version}")
            
            if not args.dry_run:
                version_manager.update_version(new_version)
        
        # Update module versions
        modules = version_manager.find_modules()
        for module_path in modules:
            module_name = module_path.name
            bump_type = version_bumps.get(module_name, VersionBump.NONE)
            
            if bump_type != VersionBump.NONE:
                current_version = version_manager.get_current_version(module_path)
                new_version = current_version.bump(bump_type)
                
                print(f"{module_name}: {current_version} → {new_version}")
                
                if not args.dry_run:
                    version_manager.update_version(new_version, module_path)
    
    elif args.command == "version":
        if args.module:
            modules = version_manager.find_modules()
            module_path = next((m for m in modules if m.name == args.module), None)
            if module_path:
                version = version_manager.get_current_version(module_path)
                print(f"{args.module}: {version}")
            else:
                print(f"Module '{args.module}' not found")
                sys.exit(1)
        else:
            # Show all versions
            workspace_version = version_manager.get_current_version()
            print(f"Workspace: {workspace_version}")
            
            modules = version_manager.find_modules()
            for module_path in modules:
                version = version_manager.get_current_version(module_path)
                print(f"{module_path.name}: {version}")
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()