"""Parse `xcrun xccov view --report --json` output and apply a coverage gate."""

from __future__ import annotations

from dataclasses import dataclass
from fnmatch import fnmatch
from typing import Any, Iterable, Optional


@dataclass(frozen=True)
class FileCoverage:
    path: str
    covered_lines: int
    executable_lines: int

    @property
    def name(self) -> str:
        return self.path.rsplit("/", 1)[-1]

    @property
    def percent(self) -> float:
        if self.executable_lines == 0:
            return 100.0
        return 100.0 * self.covered_lines / self.executable_lines


@dataclass(frozen=True)
class CoverageReport:
    files: tuple[FileCoverage, ...] = ()

    @property
    def covered_lines(self) -> int:
        return sum(f.covered_lines for f in self.files)

    @property
    def executable_lines(self) -> int:
        return sum(f.executable_lines for f in self.files)

    @property
    def percent(self) -> float:
        """Line coverage across all files, weighted by file size."""
        if self.executable_lines == 0:
            return 0.0
        return 100.0 * self.covered_lines / self.executable_lines

    def lowest(self, count: int = 10) -> list[FileCoverage]:
        return sorted(self.files, key=lambda f: (f.percent, f.path))[:count]

    def excluding(self, patterns: Iterable[str]) -> "CoverageReport":
        """A copy without files whose path matches any glob pattern."""
        patterns = list(patterns)
        return CoverageReport(
            tuple(f for f in self.files if not any(fnmatch(f.path, pattern) for pattern in patterns))
        )

    def meets(self, minimum_percent: Optional[float]) -> bool:
        return minimum_percent is None or self.percent >= minimum_percent


def parse_coverage(data: dict[str, Any], target: Optional[str] = None) -> CoverageReport:
    """Files from every target, or only from the target named `target`."""
    files = []
    for entry in data.get("targets", []):
        if target is not None and entry.get("name") != target:
            continue
        for file in entry.get("files", []):
            files.append(
                FileCoverage(
                    path=file.get("path") or file.get("name", ""),
                    covered_lines=int(file.get("coveredLines", 0)),
                    executable_lines=int(file.get("executableLines", 0)),
                )
            )
    return CoverageReport(tuple(files))
