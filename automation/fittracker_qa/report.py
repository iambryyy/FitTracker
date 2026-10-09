"""Render a test run as JUnit XML (for CI) and Markdown (for people)."""

from __future__ import annotations

import os
import xml.etree.ElementTree as ET
from typing import Optional

from .coverage import CoverageReport
from .results import FAILED, SKIPPED, RunResult


def format_duration(seconds: float) -> str:
    """`0.004` -> `4ms`, `12.34` -> `12.3s`, `272.9` -> `4m 33s`."""
    if seconds < 1:
        return f"{seconds * 1000:.0f}ms"
    if seconds < 60:
        return f"{seconds:.1f}s"
    minutes, remainder = divmod(int(round(seconds)), 60)
    return f"{minutes}m {remainder:02d}s"


def relative_path(path: str, root: Optional[str]) -> str:
    """`path` relative to `root` when it is inside it, otherwise unchanged."""
    if root and path.startswith(root.rstrip("/") + "/"):
        return os.path.relpath(path, root)
    return path


def to_junit_xml(run: RunResult, root: Optional[str] = None) -> str:
    """JUnit XML with one <testsuite> per (bundle, suite)."""
    suites_element = ET.Element(
        "testsuites",
        name="FitTracker",
        tests=str(run.total),
        failures=str(len(run.failed)),
        skipped=str(len(run.skipped)),
        time=f"{run.duration:.3f}",
    )
    for (bundle, suite), cases in run.suites().items():
        suite_element = ET.SubElement(
            suites_element,
            "testsuite",
            name=f"{bundle}.{suite}" if bundle else suite,
            tests=str(len(cases)),
            failures=str(sum(1 for case in cases if case.result == FAILED)),
            skipped=str(sum(1 for case in cases if case.result == SKIPPED)),
            time=f"{sum(case.duration for case in cases):.3f}",
        )
        for case in cases:
            case_element = ET.SubElement(
                suite_element, "testcase", classname=suite, name=case.name, time=f"{case.duration:.3f}"
            )
            if case.result == SKIPPED:
                ET.SubElement(case_element, "skipped")
            elif case.result == FAILED:
                failures = case.failures or ()
                message = failures[0].message if failures else "Test failed"
                failure_element = ET.SubElement(case_element, "failure", message=message)
                failure_element.text = "\n".join(
                    f"{relative_path(f.file_path, root)}:{f.line}: {f.message}" if f.file_path else f.message
                    for f in failures
                )
    ET.indent(suites_element)
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(suites_element, encoding="unicode") + "\n"


def first_line(text: str, limit: int = 300) -> str:
    """The first line of a message, shortened to `limit` characters.

    XCUITest failures can carry a full element-tree dump; the summary only
    needs the headline. The JUnit file keeps the whole message.
    """
    line = text.strip().splitlines()[0] if text.strip() else ""
    return line if len(line) <= limit else line[: limit - 1] + "…"


def _escape_cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def to_markdown(
    run: RunResult,
    coverage: Optional[CoverageReport] = None,
    minimum_coverage: Optional[float] = None,
    root: Optional[str] = None,
) -> str:
    lines = ["# FitTracker test report", ""]

    if run.total == 0:
        verdict = "FAILED: no tests ran"
    elif run.succeeded:
        verdict = "PASSED"
    else:
        verdict = "FAILED"
    lines.append(
        f"**{verdict}** | {run.total} tests, {len(run.failed)} failed, "
        f"{len(run.skipped)} skipped | {format_duration(run.duration)}"
    )
    if run.device:
        lines.append(f"\nDevice: {run.device} (iOS {run.os_version})")
    lines.append("")

    if run.failed or run.orphan_failures:
        lines += ["## Failures", ""]
        for case in run.failed:
            lines.append(f"- **{case.full_name}**")
            for failure in case.failures:
                location = relative_path(failure.location, root)
                suffix = f" (`{location}`)" if location else ""
                lines.append(f"  - {first_line(failure.message)}{suffix}")
        for failure in run.orphan_failures:
            lines.append(f"- {first_line(failure.message)}")
        lines.append("")

    if run.cases:
        lines += ["## Suites", "", "| Bundle | Suite | Tests | Failed | Time |", "|---|---|---:|---:|---:|"]
        for (bundle, suite), cases in run.suites().items():
            failed = sum(1 for case in cases if case.result == FAILED)
            duration = format_duration(sum(case.duration for case in cases))
            lines.append(f"| {bundle} | {_escape_cell(suite)} | {len(cases)} | {failed} | {duration} |")
        lines.append("")

        lines += ["## Slowest tests", ""]
        for case in run.slowest(5):
            lines.append(f"- {format_duration(case.duration)}: {case.full_name}")
        lines.append("")

    if coverage is not None:
        lines += ["## Coverage", ""]
        gate = ""
        if minimum_coverage is not None:
            status = "met" if coverage.meets(minimum_coverage) else "NOT met"
            gate = f" (minimum {minimum_coverage:.0f}%: {status})"
        lines.append(
            f"Line coverage: **{coverage.percent:.1f}%** "
            f"({coverage.covered_lines} of {coverage.executable_lines} lines){gate}"
        )
        lines += ["", "Least covered files:", "", "| File | Coverage | Lines |", "|---|---:|---:|"]
        for file in coverage.lowest(10):
            lines.append(f"| {file.name} | {file.percent:.1f}% | {file.covered_lines}/{file.executable_lines} |")
        lines.append("")

    return "\n".join(lines)
