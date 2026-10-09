"""Thin wrappers around the Xcode command-line tools. Everything that shells
out lives here so the rest of the package stays pure and unit-testable."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any, Optional, Sequence

SUITE_TARGETS = {
    "unit": ["FitTrackerTests"],
    "ui": ["FitTrackerUITests"],
    "all": ["FitTrackerTests", "FitTrackerUITests"],
}


class ToolError(RuntimeError):
    """An Xcode command-line tool failed or produced unreadable output."""


def build_test_command(
    project: Path,
    scheme: str,
    destination: str,
    result_bundle: Path,
    suite: str = "all",
    derived_data: Optional[Path] = None,
    retries: int = 0,
) -> list[str]:
    """The xcodebuild invocation for one test run."""
    if suite not in SUITE_TARGETS:
        raise ValueError(f"Unknown suite {suite!r}; expected one of {sorted(SUITE_TARGETS)}")
    if retries < 0:
        raise ValueError("retries cannot be negative")

    command = [
        "xcodebuild",
        "test",
        "-project", str(project),
        "-scheme", scheme,
        "-destination", destination,
        "-resultBundlePath", str(result_bundle),
        "-enableCodeCoverage", "YES",
        # xcodebuild can otherwise block for up to ten minutes gathering a
        # simulator sysdiagnose. The result bundle already has what we report.
        "-collect-test-diagnostics", "never",
    ]
    if derived_data is not None:
        command += ["-derivedDataPath", str(derived_data)]
    for target in SUITE_TARGETS[suite]:
        command.append(f"-only-testing:{target}")
    if retries:
        # A test that passes on retry is reported as passed; the retry itself
        # is still recorded in the result bundle.
        command += ["-retry-tests-on-failure", "-test-iterations", str(retries + 1)]
    return command


def _run_json(command: Sequence[str]) -> dict[str, Any]:
    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
    except FileNotFoundError as error:
        raise ToolError(f"{command[0]} is not installed. Install Xcode and its command-line tools.") from error
    if completed.returncode != 0:
        raise ToolError(f"{' '.join(command[:4])} failed: {completed.stderr.strip() or completed.stdout.strip()}")
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise ToolError(f"{' '.join(command[:4])} did not return JSON") from error


def list_simulators() -> dict[str, Any]:
    return _run_json(["xcrun", "simctl", "list", "devices", "--json"])


def load_test_results(result_bundle: Path) -> dict[str, Any]:
    return _run_json(["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(result_bundle)])


def load_coverage(result_bundle: Path) -> dict[str, Any]:
    return _run_json(["xcrun", "xccov", "view", "--report", "--json", str(result_bundle)])


def run_tests(command: Sequence[str], log_path: Path) -> int:
    """Run xcodebuild, sending its full output to `log_path`. Returns the exit code."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w") as log:
        try:
            return subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=False).returncode
        except FileNotFoundError as error:
            raise ToolError("xcodebuild is not installed. Install Xcode and its command-line tools.") from error
