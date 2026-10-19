"""Exercise scheduling and cleanup with real, isolated child processes."""

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


VERIFY = Path(__file__).resolve().parents[1] / "verify.py"
spec = importlib.util.spec_from_file_location("verification", VERIFY)
verification = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verification)

CHILD = """
from pathlib import Path
import signal
import sys
import time

mode, name, code = sys.argv[1:]
def stop(signum, frame):
    Path('cleaned-' + name).touch()
    raise SystemExit(0)
signal.signal(signal.SIGTERM, stop)
if mode in ('barrier', 'wait'):
    Path('ready-' + name).touch()
if mode == 'barrier':
    deadline = time.monotonic() + 10
    while not all(Path('ready-' + str(i)).exists() for i in range(3)):
        if time.monotonic() >= deadline:
            raise SystemExit('groups did not start concurrently')
        time.sleep(.02)
    Path('finished-' + name).touch()
elif mode == 'after':
    assert Path('finished-' + name).exists(), 'group order changed'
    Path('after-' + name).touch()
elif mode == 'wait':
    while True:
        time.sleep(.05)
raise SystemExit(int(code))
"""


class VerificationGroups(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="verify-runner-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.logs = self.root / "logs"
        self.logs.mkdir()
        self.child_script = self.root / "check.py"
        self.child_script.write_text(CHILD)

    def command(self, mode, name, code=0):
        return [sys.executable, "-B", str(self.child_script), mode, str(name), str(code)]

    def execute(self, groups, timeout=20):
        with patch.object(verification, "ROOT", self.root), redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return verification.run_groups(groups, self.logs, dict(os.environ), timeout=timeout)

    def barrier_groups(self, failed=False):
        return {str(i): [("first-" + str(i), self.command("barrier", i, 7 if failed and i == 0 else 0)),
                         ("after-" + str(i), self.command("after", i))] for i in range(3)}

    def test_three_groups_overlap_and_keep_their_internal_order(self):
        self.assertEqual(self.execute(self.barrier_groups()), 0)
        for i in range(3):
            self.assertTrue((self.root / ("after-" + str(i))).is_file())
        records = json.loads((self.logs / "summary.json").read_text())
        self.assertEqual(len(records), 6)
        self.assertEqual({record["group"] for record in records}, {"0", "1", "2"})
        self.assertTrue(all(record["exit_code"] == 0 for record in records))

    def test_failure_stops_its_group_and_collects_other_group_results(self):
        self.assertEqual(self.execute(self.barrier_groups(failed=True)), 1)
        self.assertFalse((self.root / "after-0").exists())
        self.assertTrue((self.root / "after-1").is_file())
        self.assertTrue((self.root / "after-2").is_file())
        records = json.loads((self.logs / "summary.json").read_text())
        self.assertEqual(len(records), 5)
        self.assertEqual([record["exit_code"] for record in records if record["check"] == "first-0"], [7])
        self.assertTrue((self.logs / "first-0.log").is_file())

    def test_timeout_terminates_the_check_and_stops_its_group(self):
        groups = {"waiting": [("wait", self.command("wait", 0)), ("after", self.command("after", 0))],
                  "other": [("other", self.command("pass", 1))]}
        self.assertEqual(self.execute(groups, timeout=2), 1)
        self.assertTrue((self.root / "cleaned-0").is_file())
        self.assertFalse((self.logs / "after.log").exists())
        records = json.loads((self.logs / "summary.json").read_text())
        self.assertEqual({record["check"]: record["exit_code"] for record in records}, {"wait": 124, "other": 0})

    def test_sigterm_cleans_up_every_active_group(self):
        groups = {str(i): [("wait-" + str(i), self.command("wait", i)),
                           ("after-" + str(i), self.command("after", i))] for i in range(3)}
        wrapper = """
import json, os, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import verify
verify.ROOT = Path(sys.argv[2])
raise SystemExit(verify.run_groups(json.loads(sys.argv[3]), verify.ROOT / 'logs', dict(os.environ)))
"""
        child = subprocess.Popen([sys.executable, "-B", "-c", wrapper, str(VERIFY.parent), str(self.root), json.dumps(groups)],
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        try:
            deadline = time.monotonic() + 10
            while not all((self.root / ("ready-" + str(i))).exists() for i in range(3)):
                if child.poll() is not None or time.monotonic() >= deadline:
                    self.fail("interrupt fixtures did not start")
                time.sleep(.02)
            child.send_signal(signal.SIGTERM)
            output = child.communicate(timeout=15)[0]
            self.assertEqual(child.returncode, 130, output)
            for i in range(3):
                self.assertTrue((self.root / ("cleaned-" + str(i))).is_file(), output)
                self.assertFalse((self.logs / ("after-" + str(i) + ".log")).exists())
            records = json.loads((self.logs / "summary.json").read_text())
            self.assertEqual(len(records), 3)
            self.assertTrue(all(record["exit_code"] == 124 for record in records))
        finally:
            if child.poll() is None:
                child.send_signal(signal.SIGTERM)
                try:
                    child.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
            child.stdout.close()


if __name__ == "__main__":
    unittest.main()
