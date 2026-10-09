import unittest
import xml.etree.ElementTree as ET

from fittracker_qa.coverage import CoverageReport, FileCoverage, parse_coverage
from fittracker_qa.report import first_line, format_duration, relative_path, to_junit_xml, to_markdown
from fittracker_qa.results import RunResult, parse_test_results

from .helpers import load_fixture


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.report = parse_coverage(load_fixture("xccov_report.json"), target="FitTracker.app")

    def test_files_are_parsed(self):
        self.assertEqual(len(self.report.files), 6)
        draft = next(f for f in self.report.files if f.name == "ProfileDraft.swift")
        self.assertEqual((draft.covered_lines, draft.executable_lines), (125, 128))
        self.assertEqual(draft.path, "/repo/FitTracker/Logic/ProfileDraft.swift")

    def test_overall_percent_is_weighted_by_lines_not_averaged_per_file(self):
        self.assertEqual((self.report.covered_lines, self.report.executable_lines), (275, 395))
        self.assertAlmostEqual(self.report.percent, 100 * 275 / 395)

    def test_lowest_orders_by_coverage_then_path(self):
        self.assertEqual(
            [f.name for f in self.report.lowest(3)],
            # The two 0% files tie, so the path decides: FitTracker/... sorts before Shared/...
            ["ProgressViews.swift", "UITestSupport.swift", "FitTrackerApp.swift"],
        )

    def test_unknown_target_has_no_files(self):
        self.assertEqual(parse_coverage(load_fixture("xccov_report.json"), target="Other.app").files, ())

    def test_no_target_filter_includes_everything(self):
        self.assertEqual(len(parse_coverage(load_fixture("xccov_report.json")).files), 6)

    def test_excluding_by_glob(self):
        trimmed = self.report.excluding(["*/Views/*", "*/Shared/*"])
        self.assertNotIn("ProgressViews.swift", [f.name for f in trimmed.files])
        self.assertNotIn("UITestSupport.swift", [f.name for f in trimmed.files])
        self.assertEqual(len(trimmed.files), 4)
        self.assertGreater(trimmed.percent, self.report.percent)

    def test_gate_boundaries(self):
        report = CoverageReport((FileCoverage("a.swift", 80, 100),))
        self.assertTrue(report.meets(None))
        self.assertTrue(report.meets(79.9))
        self.assertTrue(report.meets(80.0))
        self.assertFalse(report.meets(80.1))

    def test_empty_report_is_zero_percent_and_fails_any_gate(self):
        empty = CoverageReport()
        self.assertEqual(empty.percent, 0.0)
        self.assertFalse(empty.meets(1))
        self.assertTrue(empty.meets(None))

    def test_file_with_no_executable_lines_is_fully_covered(self):
        self.assertEqual(FileCoverage("empty.swift", 0, 0).percent, 100.0)


class FormattingTests(unittest.TestCase):
    def test_format_duration(self):
        cases = {0.0: "0ms", 0.0042: "4ms", 0.999: "999ms", 1.0: "1.0s", 12.34: "12.3s",
                 59.94: "59.9s", 60.0: "1m 00s", 272.9: "4m 33s", 3600: "60m 00s"}
        for seconds, expected in cases.items():
            with self.subTest(seconds=seconds):
                self.assertEqual(format_duration(seconds), expected)

    def test_first_line(self):
        self.assertEqual(first_line("headline\nElement subtree:\n →TextField"), "headline")
        self.assertEqual(first_line("\n  padded  \n"), "padded")
        self.assertEqual(first_line(""), "")
        self.assertEqual(first_line("x" * 300), "x" * 300)
        shortened = first_line("x" * 301)
        self.assertEqual(len(shortened), 300)
        self.assertTrue(shortened.endswith("…"))

    def test_relative_path(self):
        self.assertEqual(relative_path("/repo/A/b.swift", "/repo"), "A/b.swift")
        self.assertEqual(relative_path("/repo/A/b.swift", "/repo/"), "A/b.swift")
        self.assertEqual(relative_path("/repository/b.swift", "/repo"), "/repository/b.swift")
        self.assertEqual(relative_path("/elsewhere/b.swift", "/repo"), "/elsewhere/b.swift")
        self.assertEqual(relative_path("/repo/b.swift", None), "/repo/b.swift")


class JUnitTests(unittest.TestCase):
    def setUp(self):
        self.run = parse_test_results(load_fixture("ui_run_with_failures.json"))
        self.root = ET.fromstring(to_junit_xml(self.run, root="/repo"))

    def test_totals(self):
        self.assertEqual(self.root.tag, "testsuites")
        self.assertEqual(self.root.get("tests"), "6")
        self.assertEqual(self.root.get("failures"), "2")
        self.assertEqual(self.root.get("skipped"), "0")

    def test_one_suite_element_per_suite(self):
        suites = self.root.findall("testsuite")
        self.assertEqual(
            [suite.get("name") for suite in suites],
            ["FitTrackerUITests.FitTrackerUITestsLaunchTests",
             "FitTrackerUITests.FoodLoggingUITests",
             "FitTrackerUITests.ProfileUITests"],
        )
        self.assertEqual([suite.get("tests") for suite in suites], ["1", "3", "2"])
        self.assertEqual([suite.get("failures") for suite in suites], ["0", "1", "1"])

    def test_failure_element_has_message_and_relative_location(self):
        failures = self.root.findall(".//testcase/failure")
        self.assertEqual(len(failures), 2)
        self.assertIn("Calories, 89 kcal", failures[0].get("message"))
        self.assertTrue(failures[0].text.startswith("FitTrackerUITests/FoodLoggingUITests.swift:54: "))

    def test_passing_cases_have_no_children(self):
        passing = [case for case in self.root.iter("testcase") if case.find("failure") is None]
        self.assertEqual(len(passing), 4)
        self.assertTrue(all(len(case) == 0 for case in passing))

    def test_special_characters_are_escaped(self):
        data = {"testNodes": [{"nodeType": "Test Suite", "name": "A & B <suite>", "children": [
            {"nodeType": "Test Case", "name": 'says "hi" & <bye>', "result": "Failed", "children": [
                {"nodeType": "Failure Message", "name": 'a < b && "c"'}]},
            {"nodeType": "Test Case", "name": "skipped()", "result": "Skipped"}]}]}
        root = ET.fromstring(to_junit_xml(parse_test_results(data)))
        case = root.find(".//testcase")
        self.assertEqual(case.get("name"), 'says "hi" & <bye>')
        self.assertEqual(case.find("failure").get("message"), 'a < b && "c"')
        self.assertIsNotNone(root.findall(".//testcase")[1].find("skipped"))
        self.assertEqual(root.get("skipped"), "1")

    def test_empty_run_is_valid_xml(self):
        root = ET.fromstring(to_junit_xml(RunResult()))
        self.assertEqual(root.get("tests"), "0")


class MarkdownTests(unittest.TestCase):
    def setUp(self):
        self.failing = parse_test_results(load_fixture("ui_run_with_failures.json"))
        self.passing = parse_test_results(load_fixture("unit_run_passing.json"))
        self.coverage = parse_coverage(load_fixture("xccov_report.json"))

    def test_failing_run(self):
        text = to_markdown(self.failing, root="/repo")
        self.assertIn("**FAILED** | 6 tests, 2 failed, 0 skipped", text)
        self.assertIn("Device: iPhone 16 Pro (iOS 18.3.1)", text)
        self.assertIn("## Failures", text)
        self.assertIn("(`FitTrackerUITests/FoodLoggingUITests.swift:54`)", text)
        self.assertNotIn("/repo/", text)

    def test_multi_line_failure_messages_are_reduced_to_their_headline(self):
        data = {"testNodes": [{"nodeType": "Test Suite", "name": "S", "children": [
            {"nodeType": "Test Case", "name": "t()", "result": "Failed", "children": [
                {"nodeType": "Failure Message", "name": "Failed to tap button\nElement subtree:\n →Button"}]}]}]}
        text = to_markdown(parse_test_results(data))
        self.assertIn("  - Failed to tap button", text)
        self.assertNotIn("Element subtree", text)
        self.assertIn("Element subtree", to_junit_xml(parse_test_results(data)))

    def test_passing_run_has_no_failures_section(self):
        text = to_markdown(self.passing)
        self.assertIn("**PASSED** | 6 tests, 0 failed, 0 skipped", text)
        self.assertNotIn("## Failures", text)
        self.assertIn("| FitTrackerTests | MealType | 1 | 0 |", text)

    def test_empty_run_is_reported_as_a_failure(self):
        text = to_markdown(RunResult())
        self.assertIn("FAILED: no tests ran", text)
        self.assertNotIn("PASSED", text)

    def test_coverage_section_and_gate(self):
        met = to_markdown(self.passing, self.coverage, minimum_coverage=60)
        self.assertIn("Line coverage: **69.6%** (275 of 395 lines) (minimum 60%: met)", met)
        missed = to_markdown(self.passing, self.coverage, minimum_coverage=90)
        self.assertIn("(minimum 90%: NOT met)", missed)
        ungated = to_markdown(self.passing, self.coverage)
        self.assertNotIn("minimum", ungated)
        self.assertIn("| ProgressViews.swift | 0.0% | 0/105 |", ungated)

    def test_no_coverage_section_without_coverage(self):
        self.assertNotIn("## Coverage", to_markdown(self.passing))

    def test_pipes_in_suite_names_do_not_break_the_table(self):
        data = {"testNodes": [{"nodeType": "Test Suite", "name": "a | b", "children": [
            {"nodeType": "Test Case", "name": "t()", "result": "Passed"}]}]}
        self.assertIn("| a \\| b | 1 | 0 |", to_markdown(parse_test_results(data)))


if __name__ == "__main__":
    unittest.main()
