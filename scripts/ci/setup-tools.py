#!/usr/bin/env python3
"""Install the CI's pinned native tools into an isolated, cacheable directory."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request


MANIFEST = Path(__file__).with_name("tool-versions.json")


def download(url, target, expected):
    print("Downloading " + url, flush=True)
    digest = hashlib.sha256()
    with urllib.request.urlopen(url, timeout=120) as source, target.open("wb") as output:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
            output.write(chunk)
    if digest.hexdigest() != expected:
        raise RuntimeError("SHA-256 mismatch: " + url)


def versions(directory, manifest):
    commands = {"caddy": ["version"], "traefik": ["version"], "nginx": ["-V"], "actionlint": ["-version"]}
    for name, args in commands.items():
        result = subprocess.run([str(directory / "bin" / name), *args], capture_output=True, text=True, timeout=15, check=True)
        output = result.stdout + result.stderr
        if manifest[name]["version"] not in output:
            raise RuntimeError("unexpected " + name + " version: " + output)
        if name == "nginx" and "--with-http_ssl_module" not in output:
            raise RuntimeError("nginx was built without HTTP SSL support")
        print(output.strip(), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", required=True, type=Path)
    args = parser.parse_args()
    destination = args.dir.resolve()
    manifest = json.loads(MANIFEST.read_text())
    system = platform.system().lower()
    arch = {"x86_64": "amd64", "aarch64": "arm64", "arm64": "arm64"}.get(platform.machine().lower())
    key = system + "_" + str(arch)
    if key not in manifest["caddy"]["sha256"]:
        parser.error("unsupported CI platform: " + key)
    marker = destination / "installed.json"
    if marker.is_file() and json.loads(marker.read_text()) == manifest:
        versions(destination, manifest)
        print("Using cached native tools: " + str(destination))
        return
    binaries = destination / "bin"
    binaries.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="dotfiles-ci-build-") as work:
        work = Path(work)
        for name, repo, archive in (
                ("caddy", "caddyserver/caddy", "caddy_{version}_" + ("mac" if system == "darwin" else system) + "_" + arch + ".tar.gz"),
                ("traefik", "traefik/traefik", "traefik_v{version}_" + key + ".tar.gz"),
                ("actionlint", "rhysd/actionlint", "actionlint_{version}_" + key + ".tar.gz")):
            version = manifest[name]["version"]
            filename = archive.format(version=version)
            archive = work / filename
            download("https://github.com/" + repo + "/releases/download/v" + version + "/" + filename,
                     archive, manifest[name]["sha256"][key])
            with tarfile.open(archive) as package:
                member = next(item for item in package.getmembers() if item.isfile() and item.name in (name, "./" + name))
                with package.extractfile(member) as source, (binaries / name).open("wb") as output:
                    shutil.copyfileobj(source, output)
            (binaries / name).chmod(0o755)
        version = manifest["nginx"]["version"]
        archive = work / "nginx.tar.gz"
        download("https://nginx.org/download/nginx-" + version + ".tar.gz", archive, manifest["nginx"]["sha256"])
        with tarfile.open(archive) as package:
            package.extractall(work, filter="data")
        source = work / ("nginx-" + version)
        configure = ["./configure", "--prefix=" + str(destination / "nginx"), "--with-http_ssl_module",
                     "--without-http_rewrite_module", "--without-http_gzip_module"]
        if system == "darwin":
            openssl = subprocess.check_output(["brew", "--prefix", "openssl@3"], text=True).strip()
            configure += ["--with-cc-opt=-I" + openssl + "/include", "--with-ld-opt=-L" + openssl + "/lib"]
        subprocess.run(configure, cwd=source, check=True, timeout=120)
        subprocess.run(["make", "-j" + str(min(os.cpu_count() or 2, 4))], cwd=source, check=True, timeout=300)
        shutil.copy2(source / "objs/nginx", binaries / "nginx")
    versions(destination, manifest)
    marker.write_text(json.dumps(manifest, indent=2) + "\n")
    print("Native tools ready: " + str(binaries), flush=True)


if __name__ == "__main__":
    main()
