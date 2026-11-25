"""The module graph as each Project.swift declares it, read by repo:verify-modules and ios:test-affected."""
import pathlib
import re
import subprocess

TIERS = {"Foundation": 0, "Models": 1, "Services": 2, "UI": 3, "Features": 4, "App": 5}
PROJECT = re.compile(r'\.project\(target:\s*"([A-Za-z0-9_]+)"')
EXTERNAL = re.compile(r'\.external\(name:\s*"([A-Za-z0-9_]+)"')


def tracked_files():
    return subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"], capture_output=True, text=True, check=True
    ).stdout.split()


def read_modules(root):
    modules = {}
    for manifest in sorted(p for p in tracked_files() if p.endswith("/Project.swift")):
        directory = pathlib.Path(manifest).parent
        parts = directory.parts
        tier = parts[1] if parts[0] == "Core" else ("Features" if parts[0] == "Features" else "App")
        # Test dependencies come after `testDependencies`; everything before it is the module's own target.
        main, _, tests = (root / manifest).read_text().partition("testDependencies")
        modules[directory.name] = {
            "directory": directory,
            "tier": tier,
            "projects": PROJECT.findall(main),
            "externals": EXTERNAL.findall(main),
            "test_projects": PROJECT.findall(tests),
            "has_tests": re.search(r"hasTests:\s*true", main) is not None,
            "sources": directory / "Sources",
        }
    return modules
