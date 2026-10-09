import unittest

from fittracker_qa.simulators import (
    NoSimulatorError,
    Simulator,
    choose_simulator,
    parse_devices,
    parse_runtime_version,
    parse_version,
)

from .helpers import load_fixture

IOS_18_3 = "com.apple.CoreSimulator.SimRuntime.iOS-18-3"


class ParseRuntimeVersionTests(unittest.TestCase):
    def test_ios_runtimes(self):
        cases = {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-3": (18, 3),
            "com.apple.CoreSimulator.SimRuntime.iOS-17-0": (17, 0),
            "com.apple.CoreSimulator.SimRuntime.iOS-17-0-1": (17, 0, 1),
        }
        for runtime, expected in cases.items():
            with self.subTest(runtime=runtime):
                self.assertEqual(parse_runtime_version(runtime), expected)

    def test_other_platforms_are_not_ios(self):
        for runtime in ("com.apple.CoreSimulator.SimRuntime.watchOS-11-0",
                        "com.apple.CoreSimulator.SimRuntime.tvOS-18-0",
                        "com.apple.CoreSimulator.SimRuntime.xrOS-2-0",
                        "garbage"):
            with self.subTest(runtime=runtime):
                self.assertIsNone(parse_runtime_version(runtime))


class ParseVersionTests(unittest.TestCase):
    def test_parses_dotted_versions(self):
        self.assertEqual(parse_version("18"), (18,))
        self.assertEqual(parse_version("18.3.1"), (18, 3, 1))

    def test_rejects_non_numeric(self):
        for text in ("", "latest", "18.x"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_version(text)


class ParseDevicesTests(unittest.TestCase):
    def setUp(self):
        self.simctl = load_fixture("simctl_devices.json")

    def test_only_iphones_on_ios_are_returned(self):
        simulators = parse_devices(self.simctl)
        self.assertEqual(len(simulators), 12)
        self.assertTrue(all(s.name.startswith("iPhone") for s in simulators))
        self.assertEqual({s.os_version for s in simulators}, {(18, 3), (17, 5), (17, 0)})

    def test_unavailable_devices_are_skipped(self):
        self.simctl["devices"][IOS_18_3][0]["isAvailable"] = False
        names = [s.name for s in parse_devices(self.simctl) if s.os_version == (18, 3)]
        self.assertNotIn("iPhone 16 Pro", names)
        self.assertEqual(len(names), 3)

    def test_booted_state_is_read(self):
        self.simctl["devices"][IOS_18_3][1]["state"] = "Booted"
        booted = [s.name for s in parse_devices(self.simctl) if s.is_booted]
        self.assertEqual(booted, ["iPhone 16 Pro Max"])

    def test_empty_listing(self):
        self.assertEqual(parse_devices({}), [])
        self.assertEqual(parse_devices({"devices": {}}), [])


class ChooseSimulatorTests(unittest.TestCase):
    def setUp(self):
        self.simctl = load_fixture("simctl_devices.json")
        self.simulators = parse_devices(self.simctl)

    def test_default_is_newest_os_then_first_name(self):
        chosen = choose_simulator(self.simulators)
        self.assertEqual((chosen.name, chosen.os_version), ("iPhone 16", (18, 3)))

    def test_choice_does_not_depend_on_listing_order(self):
        self.assertEqual(choose_simulator(list(reversed(self.simulators))), choose_simulator(self.simulators))

    def test_booted_device_wins_within_the_newest_os(self):
        self.simctl["devices"][IOS_18_3][1]["state"] = "Booted"
        chosen = choose_simulator(parse_devices(self.simctl))
        self.assertEqual(chosen.name, "iPhone 16 Pro Max")

    def test_booted_device_on_an_older_os_does_not_win(self):
        self.simctl["devices"]["com.apple.CoreSimulator.SimRuntime.iOS-17-5"][0]["state"] = "Booted"
        chosen = choose_simulator(parse_devices(self.simctl))
        self.assertEqual(chosen.os_version, (18, 3))

    def test_filter_by_name(self):
        chosen = choose_simulator(self.simulators, name="iPhone 15 Pro")
        self.assertEqual((chosen.name, chosen.os_version), ("iPhone 15 Pro", (17, 5)))

    def test_filter_by_os_prefix(self):
        self.assertEqual(choose_simulator(self.simulators, os_version=(17,)).os_version, (17, 5))
        self.assertEqual(choose_simulator(self.simulators, os_version=(17, 0)).os_version, (17, 0))

    def test_minimum_os_excludes_older_runtimes(self):
        chosen = choose_simulator(self.simulators, name="iPhone 15", minimum_os=(17, 5))
        self.assertEqual(chosen.os_version, (17, 5))
        with self.assertRaises(NoSimulatorError):
            choose_simulator(self.simulators, minimum_os=(19, 0))

    def test_no_match_lists_what_is_available(self):
        with self.assertRaises(NoSimulatorError) as raised:
            choose_simulator(self.simulators, name="iPhone 4")
        message = str(raised.exception)
        self.assertIn("iPhone 4", message)
        self.assertIn("iPhone 16 Pro (iOS 18.3)", message)

    def test_no_simulators_at_all(self):
        with self.assertRaises(NoSimulatorError) as raised:
            choose_simulator([])
        self.assertIn("Available: none", str(raised.exception))

    def test_destination_uses_the_udid(self):
        simulator = Simulator(udid="ABC-123", name="iPhone 16", os_version=(18, 3), is_booted=False)
        self.assertEqual(simulator.destination, "platform=iOS Simulator,id=ABC-123")
        self.assertEqual(simulator.os_text, "18.3")


if __name__ == "__main__":
    unittest.main()
