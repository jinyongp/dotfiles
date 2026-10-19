#!/usr/bin/env python3
"""Run all Python checks; a skipped required test fails the verification."""

from pathlib import Path
import signal
import sys
import unittest


def interrupted(signum, frame):
    # Exit through Python so the native fixture's process cleanup can run.
    raise KeyboardInterrupt


signal.signal(signal.SIGTERM, interrupted)
root = Path(__file__).resolve().parents[2]
suite = unittest.defaultTestLoader.discover(str(root / "cmd/kill-port/tests"))
result = unittest.TextTestRunner(verbosity=2, failfast=True).run(suite)
if result.skipped:
    print("Required tests were skipped:", file=sys.stderr)
    for test, reason in result.skipped:
        print("  " + str(test) + ": " + reason, file=sys.stderr)
raise SystemExit(0 if result.wasSuccessful() and not result.skipped else 1)
