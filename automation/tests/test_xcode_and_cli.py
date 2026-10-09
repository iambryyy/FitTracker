import io
import subprocess
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from fittracker_qa import cli, xcode
from fittracker_qa.coverage import CoverageReport, FileCoverage
from fittracker_qa.results import FAILED, PASSED, CaseResult, Failure, RunResult

from .helpers import load_fixture


def _run(*results):
    return RunResult(cases=tuple(
        CaseResult(bundle="B", suite="S", name=f"t{i}", identifier=f"t{i}", result=result, duration=0.1)
        for i, result in enumerate(results)
    ))


def _coverage(percent):
    return CoverageReport((FileCoverage("a.swift", percent, 100),))


class BuildTestCommandTests(unittest.TestCase):
    def _command(self, **overrides):
        arguments = dict(
            project=Path("/repo/FitTracker.xcodeproj"),
            scheme="FitTracker",
            destination="platform=iOS Simulator,id=ABC",
            result_bundle=Path("/out/R.xcresult"),
        )
        arguments.update(overrides)
        return xcode.build_test_command(**arguments)

    def test_default_command(self):
        self.assertEqual(self._command(), [
            "xcodebuild", "test",
            "-project", "/repo/FitTracker.xcodeproj",
            "-scheme", "FitTracker",
            "-destination", "platform=iOS Simulator,id=ABC",
            "-resultBundlePath", "/out/R.xcresult",
            "-enableCodeCoverage", "YES",
            "-collect-test-diagnostics", "never",
            "-only-testing:FitTrackerTests",
            "-only-testing:FitTrackerUITests",
        ])

    def test_suite_selects_targets(self):
        unit = self._command(suite="unit")
        self.assertIn("-only-testing:FitTrackerTests", unit)
        self.assertNotIn("-only-testing:FitTrackerUITests", unit)
        ui = self._command(suite="ui")
        self.assertEqual([a for a in ui if a.startswith("-only-testing")], ["-only-testing:FitTrackerUITests"])

    def test_unknown_suite_is_rejected(self):
        with self.assertRaises(ValueError):
            self._command(suite="smoke")

    def test_retries_become_iterations(self):
        command = self._command(retries=2)
        index = command.index("-test-iterations")
        self.assertEqual(command[index + 1], "3")
        self.assertIn("-retry-tests-on-failure", command)
        self.assertNotIn("-retry-tests-on-failure", self._command(retries=0))

    def test_negative_retries_are_rejected(self):
        with self.assertRaises(ValueError):
            self._command(retries=-1)

    def test_derived_data_is_optional(self):
        self.assertNotIn("-derivedDataPath", self._command())
        command = self._command(derived_data=Path("/dd"))
        self.assertEqual(command[command.index("-derivedDataPath") + 1], "/dd")

    def test_paths_with_spaces_stay_single_arguments(self):
        command = self._command(project=Path("/My Projects/FitTracker 2/FitTracker.xcodeproj"))
        self.assertIn("/My Projects/FitTracker 2/FitTracker.xcodeproj", command)


class ToolWrapperTests(unittest.TestCase):
    def _completed(self, stdout="", stderr="", returncode=0):
        return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=stderr)

    def test_json_output_is_parsed(self):
        with mock.patch("subprocess.run", return_value=self._completed('{"devices": {}}')) as run:
            self.assertEqual(xcode.list_simulators(), {"devices": {}})
        self.assertEqual(run.call_args.args[0], ["xcrun", "simctl", "list", "devices", "--json"])

    def test_non_zero_exit_raises_with_stderr(self):
        with mock.patch("subprocess.run", return_value=self._completed(stderr="no such bundle", returncode=1)):
            with self.assertRaises(xcode.ToolError) as raised:
                xcode.load_test_results(Path("/missing.xcresult"))
        self.assertIn("no such bundle", str(raised.exception))

    def test_invalid_json_raises(self):
        with mock.patch("subprocess.run", return_value=self._completed("not json")):
            with self.assertRaises(xcode.ToolError):
                xcode.load_coverage(Path("/r.xcresult"))

    def test_missing_tool_raises_a_helpful_error(self):
        with mock.patch("subprocess.run", side_effect=FileNotFoundError()):
            with self.assertRaises(xcode.ToolError) as raised:
                xcode.list_simulators()
        self.assertIn("Install Xcode", str(raised.exception))


class ExitCodeTests(unittest.TestCase):
    def test_green(self):
        self.assertEqual(cli.exit_code(_run(PASSED), _coverage(90), 80), cli.EXIT_OK)
        self.assertEqual(cli.exit_code(_run(PASSED), None, None), cli.EXIT_OK)

    def test_test_failures(self):
        self.assertEqual(cli.exit_code(_run(PASSED, FAILED), _coverage(90), 80), cli.EXIT_TEST_FAILURES)

    def test_no_tests_is_a_failure(self):
        self.assertEqual(cli.exit_code(_run(), _coverage(90), None), cli.EXIT_TEST_FAILURES)

    def test_coverage_gate(self):
        self.assertEqual(cli.exit_code(_run(PASSED), _coverage(79), 80), cli.EXIT_COVERAGE)
        self.assertEqual(cli.exit_code(_run(PASSED), _coverage(80), 80), cli.EXIT_OK)

    def test_test_failures_outrank_coverage(self):
        self.assertEqual(cli.exit_code(_run(FAILED), _coverage(10), 80), cli.EXIT_TEST_FAILURES)

    def test_gate_is_skipped_when_coverage_is_unavailable(self):
        self.assertEqual(cli.exit_code(_run(PASSED), None, 80), cli.EXIT_OK)

    def test_failure_outside_a_test_case(self):
        run = RunResult(cases=_run(PASSED).cases, orphan_failures=(Failure("crash"),))
        self.assertEqual(cli.exit_code(run, None, None), cli.EXIT_TEST_FAILURES)


class CommandLineTests(unittest.TestCase):
    """End-to-end through `main`, with only the Xcode tools replaced."""

    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.output = Path(self.directory.name)
        self.bundle = self.output / "R.xcresult"
        self.bundle.mkdir()

    def _main(self, *arguments, results="unit_run_passing.json"):
        stdout, stderr = io.StringIO(), io.StringIO()
        with mock.patch.object(xcode, "load_test_results", return_value=load_fixture(results)), \
             mock.patch.object(xcode, "load_coverage", return_value=load_fixture("xccov_report.json")), \
             redirect_stdout(stdout), redirect_stderr(stderr):
            code = cli.main(list(arguments))
        return code, stdout.getvalue(), stderr.getvalue()

    def test_report_writes_both_files(self):
        code, stdout, _ = self._main("report", str(self.bundle), "--output", str(self.output / "out"))
        self.assertEqual(code, cli.EXIT_OK)
        self.assertIn("**PASSED**", stdout)
        self.assertIn("**PASSED**", (self.output / "out" / "report.md").read_text())
        self.assertIn("<testsuites", (self.output / "out" / "junit.xml").read_text())

    def test_report_defaults_to_the_bundle_directory(self):
        self._main("report", str(self.bundle))
        self.assertTrue((self.output / "report.md").exists())

    def test_failing_results_exit_1(self):
        code, stdout, _ = self._main("report", str(self.bundle), results="ui_run_with_failures.json")
        self.assertEqual(code, cli.EXIT_TEST_FAILURES)
        self.assertIn("## Failures", stdout)

    def test_missed_coverage_gate_exits_2(self):
        code, stdout, _ = self._main("report", str(self.bundle), "--min-coverage", "90")
        self.assertEqual(code, cli.EXIT_COVERAGE)
        self.assertIn("NOT met", stdout)

    def test_coverage_exclude_can_lift_a_run_over_the_gate(self):
        code, _, _ = self._main("report", str(self.bundle), "--min-coverage", "90",
                                "--coverage-exclude", "*/Views/*", "--coverage-exclude", "*/Shared/*")
        self.assertEqual(code, cli.EXIT_OK)

    def test_missing_bundle_exits_3(self):
        code, _, stderr = self._main("report", str(self.output / "nope.xcresult"))
        self.assertEqual(code, cli.EXIT_INFRASTRUCTURE)
        self.assertIn("does not exist", stderr)

    def test_unreadable_results_exit_3(self):
        with mock.patch.object(xcode, "load_test_results", side_effect=xcode.ToolError("bad bundle")), \
             redirect_stderr(io.StringIO()) as stderr:
            code = cli.main(["report", str(self.bundle)])
        self.assertEqual(code, cli.EXIT_INFRASTRUCTURE)
        self.assertIn("bad bundle", stderr.getvalue())

    def test_missing_coverage_is_a_warning_not_an_error(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with mock.patch.object(xcode, "load_test_results", return_value=load_fixture("unit_run_passing.json")), \
             mock.patch.object(xcode, "load_coverage", side_effect=xcode.ToolError("no coverage")), \
             redirect_stdout(stdout), redirect_stderr(stderr):
            code = cli.main(["report", str(self.bundle), "--min-coverage", "80"])
        self.assertEqual(code, cli.EXIT_OK)
        self.assertIn("warning: no coverage data", stderr.getvalue())
        self.assertNotIn("## Coverage", stdout.getvalue())

    def _run_command(self, xcodebuild_status, make_bundle, results="unit_run_passing.json"):
        out = self.output / "run"

        def fake_run_tests(command, log_path):
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_path.write_text("line one\nerror: Build input file cannot be found\n")
            if make_bundle:
                (out / "TestResults.xcresult").mkdir()
            self.command = command
            return xcodebuild_status

        with mock.patch.object(xcode, "list_simulators", return_value=load_fixture("simctl_devices.json")), \
             mock.patch.object(xcode, "run_tests", side_effect=fake_run_tests):
            return self._main("run", "--suite", "unit", "--output", str(out), results=results)

    def test_run_targets_the_chosen_simulator(self):
        code, stdout, _ = self._run_command(xcodebuild_status=0, make_bundle=True)
        self.assertEqual(code, cli.EXIT_OK)
        self.assertIn("Running unit tests on iPhone 16 (iOS 18.3)", stdout)
        destination = self.command[self.command.index("-destination") + 1]
        self.assertEqual(destination, "platform=iOS Simulator,id=EE38F128-25C2-4FC1-93B4-378677D95D49")
        self.assertIn("-only-testing:FitTrackerTests", self.command)

    def test_run_without_a_result_bundle_exits_3_and_shows_the_log(self):
        code, _, stderr = self._run_command(xcodebuild_status=65, make_bundle=False)
        self.assertEqual(code, cli.EXIT_INFRASTRUCTURE)
        self.assertIn("Build input file cannot be found", stderr)

    def test_run_with_failing_tests_exits_1(self):
        code, _, _ = self._run_command(xcodebuild_status=65, make_bundle=True, results="ui_run_with_failures.json")
        self.assertEqual(code, cli.EXIT_TEST_FAILURES)

    def test_xcodebuild_failure_is_never_reported_green(self):
        # Results look fine but xcodebuild itself failed: do not trust the green.
        code, _, stderr = self._run_command(xcodebuild_status=70, make_bundle=True)
        self.assertEqual(code, cli.EXIT_INFRASTRUCTURE)
        self.assertIn("xcodebuild exited 70", stderr)

    def test_unknown_device_exits_3(self):
        with mock.patch.object(xcode, "list_simulators", return_value=load_fixture("simctl_devices.json")):
            code, _, stderr = self._main("run", "--device", "iPhone 4")
        self.assertEqual(code, cli.EXIT_INFRASTRUCTURE)
        self.assertIn("No simulator matches iPhone 4", stderr)

    def test_simulators_marks_the_default(self):
        with mock.patch.object(xcode, "list_simulators", return_value=load_fixture("simctl_devices.json")):
            code, stdout, _ = self._main("simulators")
        self.assertEqual(code, cli.EXIT_OK)
        marked = [line for line in stdout.splitlines() if line.startswith("*") and "iPhone" in line]
        self.assertEqual(len(marked), 1)
        self.assertIn("iPhone 16 ", marked[0])


if __name__ == "__main__":
    unittest.main()
