#!/usr/bin/env python3
"""
Dynamic dependency discovery for multi-module projects.
Parses pyproject.toml files to build dependency graph and determine build order.
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Set

try:
    import tomllib
except ImportError:
    # Fallback for Python < 3.11
    try:
        import tomli as tomllib
    except ImportError:
        print("Error: Neither tomllib (Python 3.11+) nor tomli is available.", file=sys.stderr)
        print("Install tomli: pip install tomli", file=sys.stderr)
        sys.exit(1)


def find_modules(workspace_root: Path) -> List[Path]:
    """Find all modules in the workspace."""
    modules_dir = workspace_root / "modules"
    if not modules_dir.exists():
        return []
    
    modules = []
    for item in modules_dir.iterdir():
        if item.is_dir() and (item / "pyproject.toml").exists():
            modules.append(item)
    
    return sorted(modules)


def parse_module_dependencies(module_path: Path) -> Dict[str, List[str]]:
    """Parse dependencies from a module's pyproject.toml."""
    pyproject_path = module_path / "pyproject.toml"
    
    try:
        with open(pyproject_path, "rb") as f:
            data = tomllib.load(f)
    except Exception as e:
        print(f"Error reading {pyproject_path}: {e}", file=sys.stderr)
        return {}
    
    module_name = data.get("project", {}).get("name", module_path.name)
    dependencies = data.get("project", {}).get("dependencies", [])
    
    # Extract only local workspace dependencies (assume they don't have version specifiers from PyPI)
    local_deps = []
    for dep in dependencies:
        # Simple heuristic: if it's a single word without version specifiers, it's likely a workspace dependency
        dep_name = dep.split()[0].split(">=")[0].split("==")[0].split("~=")[0].split("!=")[0]
        if dep_name and not any(char in dep for char in ">=~!<"):
            local_deps.append(dep_name)
    
    return {module_name: local_deps}


def build_dependency_graph(workspace_root: Path) -> Dict[str, List[str]]:
    """Build complete dependency graph for all modules."""
    modules = find_modules(workspace_root)
    dependency_graph = {}
    
    for module_path in modules:
        deps = parse_module_dependencies(module_path)
        dependency_graph.update(deps)
    
    return dependency_graph


def topological_sort(dependency_graph: Dict[str, List[str]]) -> List[str]:
    """Perform topological sort to determine build order (dependencies first)."""
    # Kahn's algorithm - but we want dependencies first, so we reverse the graph
    
    # Create reverse graph: node -> modules that depend on it
    reverse_graph = {node: [] for node in dependency_graph}
    in_degree = {node: 0 for node in dependency_graph}
    
    # Build reverse graph and calculate in-degrees
    for node, dependencies in dependency_graph.items():
        for dep in dependencies:
            if dep in reverse_graph:
                reverse_graph[dep].append(node)
                in_degree[node] += 1
    
    # Start with nodes that have no dependencies (in_degree = 0)
    queue = [node for node in in_degree if in_degree[node] == 0]
    result = []
    
    while queue:
        current = queue.pop(0)
        result.append(current)
        
        # Remove current node and update in-degrees of dependents
        for dependent in reverse_graph[current]:
            in_degree[dependent] -= 1
            if in_degree[dependent] == 0:
                queue.append(dependent)
    
    # Check for circular dependencies
    if len(result) != len(dependency_graph):
        remaining = set(dependency_graph.keys()) - set(result)
        raise ValueError(f"Circular dependency detected involving: {remaining}")
    
    return result


def get_dependents(dependency_graph: Dict[str, List[str]], target_module: str) -> Set[str]:
    """Get all modules that depend on the target module (transitively)."""
    dependents = set()
    
    def find_dependents(module: str):
        for node, deps in dependency_graph.items():
            if module in deps and node not in dependents:
                dependents.add(node)
                find_dependents(node)  # Recursive for transitive dependencies
    
    find_dependents(target_module)
    return dependents


def get_dependencies_up_to(dependency_graph: Dict[str, List[str]], target_module: str) -> List[str]:
    """Get build order up to and including the target module."""
    full_order = topological_sort(dependency_graph)
    
    try:
        target_index = full_order.index(target_module)
        return full_order[:target_index + 1]
    except ValueError:
        raise ValueError(f"Module '{target_module}' not found in dependency graph")


def main():
    """Main CLI interface."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Discover module dependencies")
    parser.add_argument("--workspace", type=Path, default=Path.cwd(), 
                       help="Workspace root directory")
    parser.add_argument("--format", choices=["json", "list"], default="list",
                       help="Output format")
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # List all modules command
    list_parser = subparsers.add_parser("list", help="List all modules in build order")
    
    # Dependencies command
    deps_parser = subparsers.add_parser("dependencies", help="Get dependencies for a module")
    deps_parser.add_argument("module", help="Target module name")
    
    # Dependents command
    dependents_parser = subparsers.add_parser("dependents", help="Get dependents of a module")
    dependents_parser.add_argument("module", help="Target module name")
    
    # Build order command
    build_parser = subparsers.add_parser("build-order", help="Get build order up to a module")
    build_parser.add_argument("module", help="Target module name")
    
    args = parser.parse_args()
    
    try:
        dependency_graph = build_dependency_graph(args.workspace)
        
        if args.command == "list":
            result = topological_sort(dependency_graph)
        elif args.command == "dependencies":
            result = dependency_graph.get(args.module, [])
        elif args.command == "dependents":
            result = list(get_dependents(dependency_graph, args.module))
        elif args.command == "build-order":
            result = get_dependencies_up_to(dependency_graph, args.module)
        else:
            parser.print_help()
            return
        
        if args.format == "json":
            print(json.dumps(result))
        else:
            if isinstance(result, list):
                for item in result:
                    print(item)
            else:
                print(result)
                
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()