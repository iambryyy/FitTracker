"""Parse `xcrun xcresulttool get test-results tests` output into plain objects."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

PASSED = "Passed"
FAILED = "Failed"
SKIPPED = "Skipped"
EXPECTED_FAILURE = "Expected Failure"

_BUNDLE_TYPES = {"Unit test bundle", "UI test bundle"}


@dataclass(frozen=True)
class Failure:
    message: str
    file_path: Optional[str] = None
    line: Optional[int] = None

    @property
    def location(self) -> str:
        if not self.file_path:
            return ""
        return f"{self.file_path}:{self.line}" if self.line else self.file_path


@dataclass(frozen=True)
class CaseResult:
    bundle: str
    suite: str
    name: str
    identifier: str
    result: str
    duration: float
    failures: tuple[Failure, ...] = ()
    #: Number of parameterised runs (1 for an ordinary test).
    runs: int = 1

    @property
    def full_name(self) -> str:
        return f"{self.suite}/{self.name}"


@dataclass(frozen=True)
class RunResult:
    cases: tuple[CaseResult, ...] = ()
    device: str = ""
    os_version: str = ""
    #: Failures reported outside any test case, e.g. a crash during setup.
    orphan_failures: tuple[Failure, ...] = field(default_factory=tuple)

    def with_result(self, result: str) -> list[CaseResult]:
        return [case for case in self.cases if case.result == result]

    @property
    def total(self) -> int:
        return len(self.cases)

    @property
    def failed(self) -> list[CaseResult]:
        return self.with_result(FAILED)

    @property
    def skipped(self) -> list[CaseResult]:
        return self.with_result(SKIPPED)

    @property
    def passed(self) -> list[CaseResult]:
        return [case for case in self.cases if case.result in (PASSED, EXPECTED_FAILURE)]

    @property
    def duration(self) -> float:
        return sum(case.duration for case in self.cases)

    @property
    def succeeded(self) -> bool:
        """True only if at least one test ran and nothing failed.

        An empty run is a failure: it almost always means the tests did not
        build or were filtered out, which must not be reported as green.
        """
        return self.total > 0 and not self.failed and not self.orphan_failures

    def slowest(self, count: int = 5) -> list[CaseResult]:
        return sorted(self.cases, key=lambda case: (-case.duration, case.full_name))[:count]

    def suites(self) -> dict[tuple[str, str], list[CaseResult]]:
        """Cases grouped by (bundle, suite), in first-seen order."""
        grouped: dict[tuple[str, str], list[CaseResult]] = {}
        for case in self.cases:
            grouped.setdefault((case.bundle, case.suite), []).append(case)
        return grouped


def _failures_in(node: dict[str, Any]) -> list[Failure]:
    """Failure messages anywhere beneath `node` (they nest under argument runs)."""
    found = []
    for child in node.get("children", []):
        if child.get("nodeType") == "Failure Message":
            location = child.get("sourceLocation") or {}
            found.append(
                Failure(
                    message=child.get("name", ""),
                    file_path=location.get("filePath"),
                    line=location.get("lineNumber"),
                )
            )
        else:
            found.extend(_failures_in(child))
    return found


def parse_test_results(data: dict[str, Any]) -> RunResult:
    cases: list[CaseResult] = []
    orphans: list[Failure] = []

    def visit(node: dict[str, Any], bundle: str, suite: str) -> None:
        node_type = node.get("nodeType")
        name = node.get("name", "")

        if node_type == "Test Case":
            argument_runs = [c for c in node.get("children", []) if c.get("nodeType") == "Arguments"]
            cases.append(
                CaseResult(
                    bundle=bundle,
                    suite=suite,
                    name=name,
                    identifier=node.get("nodeIdentifier", name),
                    result=node.get("result", FAILED),
                    duration=float(node.get("durationInSeconds", 0.0)),
                    failures=tuple(_failures_in(node)),
                    runs=max(1, len(argument_runs)),
                )
            )
            return
        if node_type == "Failure Message":
            location = node.get("sourceLocation") or {}
            orphans.append(Failure(name, location.get("filePath"), location.get("lineNumber")))
            return

        if node_type in _BUNDLE_TYPES:
            bundle = name
        elif node_type == "Test Suite":
            # Nested suites read as "Outer/Inner".
            suite = f"{suite}/{name}" if suite else name
        for child in node.get("children", []):
            visit(child, bundle, suite)

    for root in data.get("testNodes", []):
        visit(root, "", "")

    device = (data.get("devices") or [{}])[0]
    return RunResult(
        cases=tuple(cases),
        device=device.get("deviceName", ""),
        os_version=device.get("osVersion", ""),
        orphan_failures=tuple(orphans),
    )
