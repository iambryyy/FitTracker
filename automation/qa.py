#!/usr/bin/env python3
"""Run FitTracker's test automation. See `python3 automation/qa.py --help`."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fittracker_qa.cli import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
