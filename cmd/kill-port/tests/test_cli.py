import json
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ENTRY = HERE.parents[1] / "bin" / "kill-port"


class CommandIntegration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.children = []
        self.addCleanup(self.stop_children)

    def stop_children(self):
        for child in self.children:
            if child.poll() is None:
                child.terminate()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=3)
            child.stdout.close()
            child.stderr.close()

    def start(self, kind, *args):
        child = subprocess.Popen([sys.executable, "-B", str(HERE / "fixture.py"), kind, *args],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.children.append(child)
        if not select.select([child.stdout], [], [], 5)[0]:
            self.fail("fixture did not start: " + kind)
        line = child.stdout.readline()
        if not line:
            self.fail("fixture failed: " + child.stderr.read())
        return child, json.loads(line)

    def run_cli(self, *args, env=None):
        return subprocess.run([str(ENTRY), *args], capture_output=True, text=True, timeout=15, env=env)

    def test_live_admin_chain_only_signals_final_service(self):
        service, backend = self.start("service")
        gate, middle = self.start("gate", "--socket", str(self.root / "gate.sock"), "--upstream", str(backend["port"]))
        caddy, frontend = self.start("caddy", "--upstream", str(middle["port"]))
        # Admin APIs and service PIDs are real. Only process/socket inventory is
        # supplied so these Python fixtures can represent distinct proxy binaries.
        inventory = ""
        for child, name, ports in ((caddy, "caddy", [frontend["port"], frontend["admin"]]),
                                   (gate, "gate", [middle["port"]]), (service, "python3", [backend["port"]])):
            inventory += "p{}\nc{}\n".format(child.pid, name)
            for index, port in enumerate(ports):
                inventory += "f{}\ntIPv4\nn127.0.0.1:{}\n".format(index, port)
        script = self.root / "lsof"
        script.write_text("#!" + sys.executable + "\nimport sys\nsys.stdout.write(" + repr(inventory) + ")\n")
        script.chmod(0o755)
        env = dict(os.environ, PATH=str(self.root) + os.pathsep + os.environ["PATH"])
        dry = self.run_cli("--dry-run", "app.test", env=env)
        self.assertEqual(dry.returncode, 0, dry.stderr)
        self.assertIn("caddy (PID " + str(caddy.pid), dry.stdout)
        self.assertIn("gate (PID " + str(gate.pid), dry.stdout)
        self.assertIn("service 127.0.0.1:" + str(backend["port"]), dry.stdout)
        self.assertIsNone(service.poll())
        result = self.run_cli("app.test", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(service.wait(timeout=3), -signal.SIGTERM)
        self.assertIsNone(caddy.poll())
        self.assertIsNone(gate.poll())

    @unittest.skipUnless(shutil.which("lsof"), "lsof required for real socket ownership check")
    def test_numeric_port_uses_real_socket_ownership_and_force(self):
        service, data = self.start("service")
        dry = self.run_cli("--dry-run", str(data["port"]))
        self.assertEqual(dry.returncode, 0, dry.stderr)
        self.assertIn(str(service.pid), dry.stdout)
        self.assertIsNone(service.poll())
        result = self.run_cli("--force", str(data["port"]))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(service.wait(timeout=3), -signal.SIGKILL)

    def test_invalid_target_is_structured_and_large_ports_are_rejected(self):
        env = dict(os.environ, DOTFILES_INSTALL_UI_MODE="json")
        result = self.run_cli("ftp://app.test", env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIsInstance(json.loads(result.stderr), dict)
        for value in ("99999999999999999999999999", "0", "65536"):
            result = self.run_cli(value)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("between 1 and 65535", result.stderr)


if __name__ == "__main__":
    unittest.main()
