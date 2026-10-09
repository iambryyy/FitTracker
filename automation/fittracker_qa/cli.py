"""Command-line entry point.

    python3 automation/qa.py run --suite all --min-coverage 80
    python3 automation/qa.py report path/to/Run.xcresult
    python3 automation/qa.py simulators

Exit codes: 0 all green, 1 test failures, 2 coverage below the minimum,
3 the run itself could not be completed (build error, no simulator, ...).
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Sequence

from . import xcode
from .coverage import CoverageReport, parse_coverage
from .report import to_junit_xml, to_markdown
from .results import RunResult, parse_test_results
from .simulators import NoSimulatorError, choose_simulator, parse_devices, parse_version

EXIT_OK = 0
EXIT_TEST_FAILURES = 1
EXIT_COVERAGE = 2
EXIT_INFRASTRUCTURE = 3

REPO_ROOT = Path(__file__).resolve().parents[2]
APP_TARGET = "FitTracker.app"


def exit_code(run: RunResult, coverage: Optional[CoverageReport], minimum_coverage: Optional[float]) -> int:
    """Test failures outrank a missed coverage gate."""
    if not run.succeeded:
        return EXIT_TEST_FAILURES
    if coverage is not None and not coverage.meets(minimum_coverage):
        return EXIT_COVERAGE
    return EXIT_OK


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="qa.py", description="Run and report on FitTracker's test suites.")
    commands = parser.add_subparsers(dest="command", required=True)

    def add_report_options(sub: argparse.ArgumentParser) -> None:
        sub.add_argument("--min-coverage", type=float, metavar="PCT",
                         help="fail (exit 2) if app line coverage is below this percentage")
        sub.add_argument("--coverage-exclude", action="append", default=[], metavar="GLOB",
                         help="leave matching source paths out of coverage, e.g. '*/Views/*' (repeatable)")
        sub.add_argument("--output", type=Path, metavar="DIR",
                         help="where to write junit.xml and report.md (default: automation/reports/<timestamp>)")

    run = commands.add_parser("run", help="run tests with xcodebuild, then report")
    run.add_argument("--suite", choices=sorted(xcode.SUITE_TARGETS), default="all")
    run.add_argument("--device", metavar="NAME", help="simulator name, e.g. 'iPhone 16 Pro' (default: newest iPhone)")
    run.add_argument("--os", metavar="VERSION", help="iOS version to test on, e.g. 18 or 18.3")
    run.add_argument("--retries", type=int, default=0, metavar="N", help="retry a failing test up to N times")
    run.add_argument("--project", type=Path, default=REPO_ROOT / "FitTracker.xcodeproj")
    run.add_argument("--scheme", default="FitTracker")
    add_report_options(run)

    report = commands.add_parser("report", help="report on an existing .xcresult bundle")
    report.add_argument("result_bundle", type=Path)
    add_report_options(report)

    commands.add_parser("simulators", help="list usable simulators and show which one would be chosen")
    return parser


def _write_reports(result_bundle: Path, output: Path, args: argparse.Namespace) -> int:
    run = parse_test_results(xcode.load_test_results(result_bundle))

    coverage: Optional[CoverageReport] = None
    try:
        coverage = parse_coverage(xcode.load_coverage(result_bundle), target=APP_TARGET)
        coverage = coverage.excluding(args.coverage_exclude)
    except xcode.ToolError as error:
        # A run that failed to build has no coverage data; that is not the headline error.
        print(f"warning: no coverage data ({error})", file=sys.stderr)

    root = str(REPO_ROOT)
    output.mkdir(parents=True, exist_ok=True)
    markdown = to_markdown(run, coverage, args.min_coverage, root=root)
    (output / "report.md").write_text(markdown)
    (output / "junit.xml").write_text(to_junit_xml(run, root=root))

    print(markdown)
    print(f"Reports written to {output}")
    return exit_code(run, coverage, args.min_coverage)


def _command_run(args: argparse.Namespace) -> int:
    simulator = choose_simulator(
        parse_devices(xcode.list_simulators()),
        name=args.device,
        os_version=parse_version(args.os) if args.os else None,
    )
    output = args.output or REPO_ROOT / "automation" / "reports" / datetime.now().strftime("%Y%m%d-%H%M%S")
    output.mkdir(parents=True, exist_ok=True)
    result_bundle = output / "TestResults.xcresult"
    log_path = output / "xcodebuild.log"

    command = xcode.build_test_command(
        project=args.project,
        scheme=args.scheme,
        destination=simulator.destination,
        result_bundle=result_bundle,
        suite=args.suite,
        retries=args.retries,
    )
    print(f"Running {args.suite} tests on {simulator.name} (iOS {simulator.os_text})")
    print(f"Log: {log_path}")
    status = xcode.run_tests(command, log_path)

    if not result_bundle.exists():
        print(f"error: xcodebuild exited {status} without producing results. Last log lines:", file=sys.stderr)
        for line in log_path.read_text(errors="replace").splitlines()[-25:]:
            print(f"  {line}", file=sys.stderr)
        return EXIT_INFRASTRUCTURE

    code = _write_reports(result_bundle, output, args)
    if code == EXIT_OK and status != 0:
        # xcodebuild failed for a reason the test results do not explain.
        print(f"error: xcodebuild exited {status}; see {log_path}", file=sys.stderr)
        return EXIT_INFRASTRUCTURE
    return code


def _command_report(args: argparse.Namespace) -> int:
    if not args.result_bundle.exists():
        print(f"error: {args.result_bundle} does not exist", file=sys.stderr)
        return EXIT_INFRASTRUCTURE
    output = args.output or args.result_bundle.parent
    return _write_reports(args.result_bundle, output, args)


def _command_simulators(_: argparse.Namespace) -> int:
    simulators = parse_devices(xcode.list_simulators())
    chosen = choose_simulator(simulators)
    for simulator in sorted(simulators, key=lambda s: (s.os_version, s.name), reverse=True):
        marker = "*" if simulator == chosen else " "
        booted = " (booted)" if simulator.is_booted else ""
        print(f"{marker} {simulator.name:<32} iOS {simulator.os_text:<8} {simulator.udid}{booted}")
    print("\n* would be used by default")
    return EXIT_OK


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    handlers = {"run": _command_run, "report": _command_report, "simulators": _command_simulators}
    try:
        return handlers[args.command](args)
    except (xcode.ToolError, NoSimulatorError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return EXIT_INFRASTRUCTURE
