"""Find an iOS simulator to test on, from `xcrun simctl list devices --json`."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Optional

_RUNTIME_PATTERN = re.compile(r"SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?$")


class NoSimulatorError(RuntimeError):
    """No installed simulator satisfies the request."""


@dataclass(frozen=True)
class Simulator:
    udid: str
    name: str
    os_version: tuple[int, ...]
    is_booted: bool

    @property
    def os_text(self) -> str:
        return ".".join(str(part) for part in self.os_version)

    @property
    def destination(self) -> str:
        """Value for xcodebuild's -destination flag."""
        return f"platform=iOS Simulator,id={self.udid}"


def parse_runtime_version(runtime_id: str) -> Optional[tuple[int, ...]]:
    """`com.apple.CoreSimulator.SimRuntime.iOS-18-3` -> `(18, 3)`; None if not iOS."""
    match = _RUNTIME_PATTERN.search(runtime_id)
    if not match:
        return None
    return tuple(int(part) for part in match.groups() if part is not None)


def parse_version(text: str) -> tuple[int, ...]:
    """`"18.3"` -> `(18, 3)`."""
    try:
        return tuple(int(part) for part in text.split("."))
    except ValueError as error:
        raise ValueError(f"Not a version number: {text!r}") from error


def parse_devices(simctl: dict[str, Any]) -> list[Simulator]:
    """Every available iPhone simulator in a simctl device listing."""
    simulators = []
    for runtime_id, devices in simctl.get("devices", {}).items():
        version = parse_runtime_version(runtime_id)
        if version is None:
            continue
        for device in devices:
            if not device.get("isAvailable", False):
                continue
            if not device.get("name", "").startswith("iPhone"):
                continue
            simulators.append(
                Simulator(
                    udid=device["udid"],
                    name=device["name"],
                    os_version=version,
                    is_booted=device.get("state") == "Booted",
                )
            )
    return simulators


def choose_simulator(
    simulators: list[Simulator],
    name: Optional[str] = None,
    os_version: Optional[tuple[int, ...]] = None,
    minimum_os: tuple[int, ...] = (17, 0),
) -> Simulator:
    """Pick one simulator, deterministically.

    Filters by exact `name` and by `os_version` prefix when given, then prefers
    the newest OS, then an already-booted device (saves a boot), then the name
    that sorts first so repeated runs choose the same device.
    """
    candidates = [s for s in simulators if s.os_version >= minimum_os]
    if name is not None:
        candidates = [s for s in candidates if s.name == name]
    if os_version is not None:
        candidates = [s for s in candidates if s.os_version[: len(os_version)] == os_version]

    if not candidates:
        wanted = " ".join(
            part
            for part in (name or "any iPhone", f"on iOS {'.'.join(map(str, os_version))}" if os_version else "")
            if part
        )
        available = sorted({f"{s.name} (iOS {s.os_text})" for s in simulators})
        raise NoSimulatorError(
            f"No simulator matches {wanted} (minimum iOS {'.'.join(map(str, minimum_os))}). "
            f"Available: {', '.join(available) or 'none'}"
        )

    newest = max(s.os_version for s in candidates)
    newest_candidates = [s for s in candidates if s.os_version == newest]
    return sorted(newest_candidates, key=lambda s: (not s.is_booted, s.name, s.udid))[0]
