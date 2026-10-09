import unittest

from fittracker_qa.results import FAILED, PASSED, SKIPPED, CaseResult, RunResult, parse_test_results

from .helpers import load_fixture


class ParseFailingRunTests(unittest.TestCase):
    """A real UI test run in which two tests failed."""

    def setUp(self):
        self.run = parse_test_results(load_fixture("ui_run_with_failures.json"))

    def test_counts(self):
        self.assertEqual(self.run.total, 6)
        self.assertEqual(len(self.run.failed), 2)
        self.assertEqual(len(self.run.passed), 4)
        self.assertEqual(self.run.skipped, [])
        self.assertFalse(self.run.succeeded)

    def test_device(self):
        self.assertEqual(self.run.device, "iPhone 16 Pro")
        self.assertEqual(self.run.os_version, "18.3.1")

    def test_cases_know_their_bundle_and_suite(self):
        case = self.run.failed[0]
        self.assertEqual(case.bundle, "FitTrackerUITests")
        self.assertEqual(case.suite, "FoodLoggingUITests")
        self.assertEqual(case.name, "testServingsStepperScalesCaloriesBeforeAndAfterAdding()")
        self.assertEqual(case.full_name, "FoodLoggingUITests/testServingsStepperScalesCaloriesBeforeAndAfterAdding()")

    def test_failure_message_and_location(self):
        failure = self.run.failed[0].failures[0]
        self.assertEqual(failure.message, 'XCTAssertEqual failed: ("Calories, 89 kcal") is not equal to ("89 kcal")')
        self.assertEqual(failure.location, "/repo/FitTrackerUITests/FoodLoggingUITests.swift:54")

    def test_passed_cases_have_no_failures(self):
        for case in self.run.passed:
            self.assertEqual(case.failures, ())

    def test_configuration_runs_are_one_case_not_many(self):
        launch = next(case for case in self.run.cases if case.name == "testLaunch()")
        self.assertEqual(launch.runs, 4)
        self.assertEqual(launch.result, PASSED)

    def test_duration_is_the_sum_of_case_durations(self):
        self.assertAlmostEqual(self.run.duration, sum(case.duration for case in self.run.cases))
        self.assertGreater(self.run.duration, 60)

    def test_slowest_is_ordered_and_limited(self):
        slowest = self.run.slowest(2)
        self.assertEqual(len(slowest), 2)
        self.assertEqual(slowest[0].name, "testSameFoodCanBeLoggedTwiceAndRemovedIndependently()")
        self.assertGreaterEqual(slowest[0].duration, slowest[1].duration)

    def test_suites_group_in_first_seen_order(self):
        self.assertEqual(
            [suite for _, suite in self.run.suites()],
            ["FitTrackerUITestsLaunchTests", "FoodLoggingUITests", "ProfileUITests"],
        )


class ParsePassingRunTests(unittest.TestCase):
    """A real Swift Testing run, including parameterised tests."""

    def setUp(self):
        self.run = parse_test_results(load_fixture("unit_run_passing.json"))

    def test_all_passed(self):
        self.assertEqual(self.run.total, 6)
        self.assertEqual(self.run.failed, [])
        self.assertTrue(self.run.succeeded)

    def test_suite_uses_the_display_name(self):
        self.assertEqual({case.suite for case in self.run.cases}, {"UnitConversion", "MealType"})
        self.assertEqual({case.bundle for case in self.run.cases}, {"FitTrackerTests"})

    def test_parameterised_test_counts_its_argument_runs(self):
        meal = next(case for case in self.run.cases if case.suite == "MealType")
        self.assertEqual(meal.name, "Suggested meal follows the time of day")
        self.assertEqual(meal.runs, 11)
        plain = next(case for case in self.run.cases if case.name == "poundsToKilograms()")
        self.assertEqual(plain.runs, 1)


class ParseEdgeCaseTests(unittest.TestCase):
    @staticmethod
    def _tree(*children):
        return {"testNodes": [{"nodeType": "Test Plan", "name": "Plan", "children": [
            {"nodeType": "Unit test bundle", "name": "Bundle", "children": list(children)}]}]}

    def test_empty_run_is_not_a_success(self):
        for data in ({}, {"testNodes": []}, self._tree()):
            with self.subTest(data=data):
                run = parse_test_results(data)
                self.assertEqual(run.total, 0)
                self.assertFalse(run.succeeded)

    def test_missing_device_is_tolerated(self):
        run = parse_test_results({"testNodes": [], "devices": []})
        self.assertEqual((run.device, run.os_version), ("", ""))

    def test_failure_nested_under_an_argument_run_is_collected(self):
        data = self._tree({"nodeType": "Test Suite", "name": "S", "children": [
            {"nodeType": "Test Case", "name": "t(x:)", "result": "Failed", "durationInSeconds": 0.5, "children": [
                {"nodeType": "Arguments", "name": "1", "result": "Passed"},
                {"nodeType": "Arguments", "name": "2", "result": "Failed", "children": [
                    {"nodeType": "Failure Message", "name": "Expectation failed: x == 3",
                     "sourceLocation": {"filePath": "/repo/T.swift", "lineNumber": 9}}]},
            ]}]})
        case = parse_test_results(data).failed[0]
        self.assertEqual(case.runs, 2)
        self.assertEqual([f.message for f in case.failures], ["Expectation failed: x == 3"])
        self.assertEqual(case.failures[0].location, "/repo/T.swift:9")

    def test_nested_suites_are_joined(self):
        data = self._tree({"nodeType": "Test Suite", "name": "Outer", "children": [
            {"nodeType": "Test Suite", "name": "Inner", "children": [
                {"nodeType": "Test Case", "name": "t()", "result": "Passed"}]}]})
        self.assertEqual(parse_test_results(data).cases[0].suite, "Outer/Inner")

    def test_skipped_and_expected_failures(self):
        data = self._tree({"nodeType": "Test Suite", "name": "S", "children": [
            {"nodeType": "Test Case", "name": "a()", "result": "Skipped"},
            {"nodeType": "Test Case", "name": "b()", "result": "Expected Failure"},
            {"nodeType": "Test Case", "name": "c()", "result": "Passed"}]})
        run = parse_test_results(data)
        self.assertEqual([case.name for case in run.skipped], ["a()"])
        self.assertEqual([case.name for case in run.passed], ["b()", "c()"])
        self.assertTrue(run.succeeded)

    def test_case_without_a_result_counts_as_failed(self):
        data = self._tree({"nodeType": "Test Suite", "name": "S", "children": [
            {"nodeType": "Test Case", "name": "crashed()"}]})
        run = parse_test_results(data)
        self.assertEqual(run.cases[0].result, FAILED)
        self.assertFalse(run.succeeded)

    def test_failure_outside_any_test_case_fails_the_run(self):
        data = self._tree(
            {"nodeType": "Failure Message", "name": "FitTracker crashed before tests started"},
            {"nodeType": "Test Suite", "name": "S", "children": [
                {"nodeType": "Test Case", "name": "ok()", "result": "Passed"}]},
        )
        run = parse_test_results(data)
        self.assertEqual([f.message for f in run.orphan_failures], ["FitTracker crashed before tests started"])
        self.assertEqual(run.failed, [])
        self.assertFalse(run.succeeded)

    def test_failure_without_a_location(self):
        data = self._tree({"nodeType": "Test Suite", "name": "S", "children": [
            {"nodeType": "Test Case", "name": "t()", "result": "Failed", "children": [
                {"nodeType": "Failure Message", "name": "boom"}]}]})
        self.assertEqual(parse_test_results(data).failed[0].failures[0].location, "")


class RunResultTests(unittest.TestCase):
    @staticmethod
    def _case(name, result=PASSED, duration=1.0):
        return CaseResult(bundle="B", suite="S", name=name, identifier=name, result=result, duration=duration)

    def test_slowest_breaks_ties_by_name(self):
        run = RunResult(cases=(self._case("b"), self._case("a"), self._case("c", duration=2.0)))
        self.assertEqual([case.name for case in run.slowest(3)], ["c", "a", "b"])

    def test_only_skipped_tests_still_counts_as_a_run(self):
        run = RunResult(cases=(self._case("a", result=SKIPPED),))
        self.assertTrue(run.succeeded)


if __name__ == "__main__":
    unittest.main()
