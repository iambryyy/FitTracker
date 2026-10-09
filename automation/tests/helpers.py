"""Shared helpers for the automation tests.

The JSON fixtures are trimmed copies of real output from xcresulttool, xccov
and simctl, with the checkout path replaced by /repo.
"""

import json
from pathlib import Path
from typing import Any

FIXTURES = Path(__file__).parent / "fixtures"


def load_fixture(name: str) -> Any:
    return json.loads((FIXTURES / name).read_text())
