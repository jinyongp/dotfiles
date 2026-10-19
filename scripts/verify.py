#!/usr/bin/env python3
"""Run the same complete verification locally and in GitHub Actions."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time


ROOT = Path(__file__).resolve().parents[1]


def run_groups(groups, logs, env, timeout=300):
    """Run three independent groups, preserving order and fail-fast within each."""
    results = []
    lock = threading.Lock()
    stopped = threading.Event()

    def run(group, name, command):
        started = time.monotonic()
        log = logs / (name + ".log")
        with lock:
            print("Checking " + group + "/" + name, flush=True)
        try:
            with log.open("w") as output:
                child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT,
                                         start_new_session=True)
                while True:
                    try:
                        code = child.wait(timeout=.2)
                        break
                    except subprocess.TimeoutExpired:
                        if not stopped.is_set() and time.monotonic() - started < timeout:
                            continue
                        try:
                            os.killpg(child.pid, signal.SIGTERM)
                        except ProcessLookupError:
                            pass
                        try:
                            child.wait(timeout=45)
                        except subprocess.TimeoutExpired:
                            os.killpg(child.pid, signal.SIGKILL)
                            child.wait()
                        output.write("\nCheck timed out or was interrupted\n")
                        code = 124
                        break
        except (OSError, subprocess.TimeoutExpired) as exc:
            with log.open("a") as output:
                output.write("\n" + str(exc) + "\n")
            code = 1
        with lock:
            results.append({"group": group, "check": name, "exit_code": code,
                            "seconds": round(time.monotonic() - started, 2)})
            (logs / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
            print(("PASS " if code == 0 else "FAIL ") + group + "/" + name, flush=True)
            if code:
                print(log.read_text()[-12000:], file=sys.stderr)
        return code == 0

    def run_group(group, checks):
        for name, command in checks:
            if stopped.is_set() or not run(group, name, command):
                return False
        return True

    def interrupted(signum, frame):
        raise KeyboardInterrupt

    previous = signal.signal(signal.SIGTERM, interrupted)
    try:
        with ThreadPoolExecutor(max_workers=3) as executor:
            try:
                futures = [executor.submit(run_group, group, checks) for group, checks in groups.items()]
                passed = True
                for future in as_completed(futures):
                    passed = future.result() and passed
            except KeyboardInterrupt:
                stopped.set()
                print("Verification interrupted; cleaning up active checks", flush=True)
                return 130
        return 0 if passed else 1
    finally:
        signal.signal(signal.SIGTERM, previous)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-dir", type=Path, help="Parent directory for a fresh run's logs")
    args = parser.parse_args()
    if args.log_dir:
        args.log_dir.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix="verify-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-",
                                dir=args.log_dir))
    print("Verification logs: " + str(logs), flush=True)
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", KILL_PORT_NATIVE_LOG_DIR=str(logs / "native"))

    required = ("bash", "zsh", "git", "perl", "openssl", "lsof", "shellcheck", "actionlint")
    missing = [name for name in required if not shutil.which(name)]
    for name in ("caddy", "nginx", "traefik"):
        binary = env.get("KILL_PORT_NATIVE_" + name.upper()) or shutil.which(name)
        if not binary or not os.access(binary, os.X_OK):
            missing.append(name + " (PATH or KILL_PORT_NATIVE_" + name.upper() + ")")
    if missing:
        parser.error("missing required tools: " + ", ".join(missing))

    files = [ROOT / item for item in subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT).decode().split("\0") if item]
    shells = {"bash": [], "zsh": []}
    for path in sorted(set(files)):
        if not path.is_file() or path.is_symlink():
            continue
        with path.open("rb") as source:
            header = source.readline(100).rstrip(b"\n")
        if path.suffix == ".zsh" or path.name in (".zshenv", ".zshrc", ".zprofile", ".zlogin", ".zlogout") or header.endswith(b"zsh"):
            shells["zsh"].append(str(path))
        elif path.suffix in (".sh", ".bash") or header.endswith((b"bash", b"/sh")):
            shells["bash"].append(str(path))
    static = [(shell + "-syntax", [shell, "-c", 'for checked_file in "$@"; do ' + shell + ' -n "$checked_file" || exit; done', shell, *paths])
              for shell, paths in shells.items()]
    static += [
        ("shellcheck", ["shellcheck", "--shell=bash", "--severity=error", *shells["bash"]]),
        ("cli-shellcheck", ["shellcheck", "--severity=warning", str(ROOT / "cmd/kill-port/main.sh"), str(ROOT / "cmd/task/main.sh")]),
        ("workflows", ["actionlint"]),
        ("verification-runner", [sys.executable, "-B", "-m", "unittest", "discover", "-s", "scripts/ci", "-p", "test_verify.py", "-v"]),
    ]
    shell_tests = []
    for test in sorted((ROOT / "scripts/tests").iterdir()):
        if test.suffix in (".sh", ".zsh"):
            shell_tests.append((test.stem, ["zsh" if str(test) in shells["zsh"] else "bash", str(test)]))
    code = run_groups({"static": static, "shell": shell_tests,
                       "python": [("python", [sys.executable, "-B", str(ROOT / "scripts/ci/python-tests.py")])]}, logs, env)
    if code:
        return code
    print("All verification passed: " + str(logs), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
