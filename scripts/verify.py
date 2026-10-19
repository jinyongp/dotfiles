#!/usr/bin/env python3
"""Run the same complete verification locally and in GitHub Actions."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]


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
    results = []

    def run(name, command, timeout=300):
        started = time.monotonic()
        log = logs / (name + ".log")
        print("Checking " + name, flush=True)
        try:
            with log.open("w") as output:
                child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT,
                                         start_new_session=True)
                try:
                    code = child.wait(timeout=timeout)
                except (subprocess.TimeoutExpired, KeyboardInterrupt):
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=45)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait()
                    output.write("\nCheck timed out or was interrupted\n")
                    code = 124
        except (OSError, subprocess.TimeoutExpired) as exc:
            with log.open("a") as output:
                output.write("\n" + str(exc) + "\n")
            code = 1
        results.append({"check": name, "exit_code": code, "seconds": round(time.monotonic() - started, 2)})
        (logs / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
        print(("PASS " if code == 0 else "FAIL ") + name, flush=True)
        if code:
            print(log.read_text()[-12000:], file=sys.stderr)
        return code == 0

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
    for shell, paths in shells.items():
        if not run(shell + "-syntax", [shell, "-c", 'for checked_file in "$@"; do ' + shell + ' -n "$checked_file" || exit; done', shell, *paths]):
            return 1
    if not run("shellcheck", ["shellcheck", "--shell=bash", "--severity=error", *shells["bash"]]):
        return 1
    if not run("cli-shellcheck", ["shellcheck", "--severity=warning", str(ROOT / "cmd/kill-port/main.sh"), str(ROOT / "cmd/task/main.sh")]):
        return 1
    if not run("workflows", ["actionlint"]):
        return 1
    for test in sorted((ROOT / "scripts/tests").iterdir()):
        if test.suffix in (".sh", ".zsh"):
            if not run(test.stem, ["zsh" if str(test) in shells["zsh"] else "bash", str(test)]):
                return 1
    if not run("python", [sys.executable, "-B", str(ROOT / "scripts/ci/python-tests.py")]):
        return 1
    print("All verification passed: " + str(logs), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
