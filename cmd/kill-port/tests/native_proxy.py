"""Optional native integration: set KILL_PORT_NATIVE_{CADDY,NGINX,TRAEFIK}."""

import atexit
import http.client
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import unittest
from http.server import BaseHTTPRequestHandler

from loopback_http import LoopbackHTTPServer


ENTRY = Path(__file__).resolve().parents[2] / "bin" / "kill-port"
BINARIES = {name: os.environ.get("KILL_PORT_NATIVE_" + name.upper()) or shutil.which(name)
            for name in ("caddy", "nginx", "traefik")}


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def request(port, host, path="/", cert=None, sni=None):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=3)
    try:
        conn.connect()
        if cert:
            context = ssl.create_default_context(cafile=str(cert))
            conn.sock = context.wrap_socket(conn.sock, server_hostname=sni or host)
        conn.request("GET", path, headers={"Host": host})
        response = conn.getresponse()
        body = response.read()
        return response.status, body
    finally:
        conn.close()


@unittest.skipUnless(all(BINARIES.values()) and shutil.which("openssl") and shutil.which("lsof"),
                     "native Caddy, nginx with SSL, Traefik, openssl and lsof required")
class NativeProxyTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.certs = tempfile.TemporaryDirectory(prefix="kill-port-tls-certs-")
        cls.cert = Path(cls.certs.name) / "cert.pem"
        cls.key = Path(cls.certs.name) / "key.pem"
        result = subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
            "-subj", "/CN=*.kp.localhost", "-addext", "subjectAltName=DNS:*.kp.localhost,IP:127.0.0.1",
            "-keyout", str(cls.key), "-out", str(cls.cert)], capture_output=True, text=True, timeout=15)
        if result.returncode:
            cls.certs.cleanup()
            raise RuntimeError(result.stderr)
        cls.addClassCleanup(cls.certs.cleanup)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="kill-port-native-tls-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.conf = self.root / "conf"
        self.runtime = self.root / "runtime"
        self.conf.mkdir()
        self.runtime.mkdir()
        self.children = []
        self.addCleanup(self.stop_children)
        atexit.register(self.stop_children)
        self.addCleanup(atexit.unregister, self.stop_children)

    def stop_children(self):
        for child, log in reversed(self.children):
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait(timeout=3)
            log.close()
        destination = os.environ.get("KILL_PORT_NATIVE_LOG_DIR")
        if destination:
            folder = Path(destination) / self.id()
            folder.mkdir(parents=True, exist_ok=True)
            for log in self.runtime.glob("*.log"):
                shutil.copyfile(log, folder / log.name)

    def start(self, args, label):
        log = open(self.runtime / (label + ".log"), "w")
        child = subprocess.Popen([str(value) for value in args], stdout=log, stderr=log,
                                 start_new_session=True)
        self.children.append((child, log))
        return child

    def wait(self, check):
        deadline = time.monotonic() + 12
        error = None
        while time.monotonic() < deadline:
            try:
                if check():
                    return
            except (OSError, ValueError, http.client.HTTPException) as exc:
                error = exc
            time.sleep(.1)
        logs = "\n".join(path.name + ": " + path.read_text()[-2500:]
                         for path in self.runtime.glob("*.log"))
        self.fail("readiness timeout: " + str(error) + "\n" + logs)

    def listening(self, port):
        def check():
            with socket.create_connection(("127.0.0.1", port), timeout=.2):
                return True
        self.wait(check)

    def backend(self, label):
        child = self.start([sys.executable, "-B", __file__, "--backend", label], label)
        log = self.runtime / (label + ".log")
        self.wait(lambda: log.stat().st_size > 0)
        return child, json.loads(log.read_text().splitlines()[0])["port"]

    def caddy(self, host, body, tls=False, server_options="", api=True):
        port, admin = free_port(), free_port()
        folder = self.conf / "caddy"
        folder.mkdir()
        config = folder / "Caddyfile"
        config.write_text("{\n admin " + ("127.0.0.1:" + str(admin) if api else "off") +
                          "\n auto_https off\n persist_config off\n" +
                          ("servers {\n" + server_options + "\n}\n" if server_options else "") + "}\n" +
                          ("https" if tls else "http") + "://" + host + ":" + str(port) +
                          " {\n bind 127.0.0.1\n" +
                          ("tls " + str(self.cert) + " " + str(self.key) + "\n" if tls else "") + body + "\n}\n")
        child = self.start([BINARIES["caddy"], "run", "--config", config, "--adapter", "caddyfile"], "caddy")
        self.listening(port)
        if api:
            self.wait(lambda: request(admin, "127.0.0.1:" + str(admin), "/config/")[0] == 200)
        return child, port

    def nginx(self, host, body, tls=False, http="", port=None):
        port = port or free_port()
        folder = self.conf / "nginx"
        folder.mkdir()
        config = folder / "nginx.conf"
        config.write_text("daemon off;\nworker_processes 1;\npid " + str(self.runtime / "nginx.pid") +
                          ";\nerror_log " + str(self.runtime / "nginx-error.log") +
                          ";\nevents {}\nhttp { access_log off;\n" + http +
                          "\nserver { listen 127.0.0.1:" + str(port) + (" ssl" if tls else "") +
                          "; server_name " + host + ";\n" +
                          ("ssl_certificate " + str(self.cert) + "; ssl_certificate_key " + str(self.key) + ";\n" if tls else "") +
                          body + "\n} }\n")
        # Both Linux boot time and ps start times can lose a fractional second.
        time.sleep(2.2)  # Keep fresh disk config strictly older than worker timestamps.
        child = self.start([BINARIES["nginx"], "-p", self.runtime, "-c", config], "nginx")
        self.listening(port)
        return child, port

    def traefik(self, host, selected, fallback=None, tls=False, upstream_tls=False, tls_options=False):
        router = {"rule": "Host(`" + host + "`)", "entryPoints": ["web"], "service": "app"}
        if tls:
            router["tls"] = {"options": "guarded"} if tls_options else {}
        routers = {"app": router}
        balancer = {"servers": [{"url": ("https" if upstream_tls else "http") + "://127.0.0.1:" + str(selected)}]}
        services = {"app": {"loadBalancer": balancer}}
        http = {"routers": routers, "services": services}
        if upstream_tls:
            balancer["serversTransport"] = "trusted"
            http["serversTransports"] = {"trusted": {"serverName": host, "rootCAs": [str(self.cert)]}}
        if fallback:
            routers["fallback"] = dict(router, service="fallback")
            router["rule"] += " && PathPrefix(`/api/`)"
            services["fallback"] = {"loadBalancer": {"servers": [{"url": "http://127.0.0.1:" + str(fallback)}]}}
        tls_config = {"certificates": [{"certFile": str(self.cert), "keyFile": str(self.key)}]}
        if tls_options:
            tls_config["options"] = {"guarded": {"minVersion": "VersionTLS12"}}
        return self.traefik_config(http, tls_config)

    def traefik_config(self, http, tls_config=None):
        port, self.traefik_admin = free_port(), free_port()
        admin = self.traefik_admin
        folder = self.conf / "traefik"
        folder.mkdir()
        dynamic = folder / "dynamic.json"
        data = {"http": http}
        if tls_config:
            data["tls"] = tls_config
        dynamic.write_text(json.dumps(data))
        config = folder / "traefik.json"
        config.write_text(json.dumps({"global": {"checkNewVersion": False, "sendAnonymousUsage": False},
                                      "entryPoints": {"web": {"address": "127.0.0.1:" + str(port)},
                                                      "traefik": {"address": "127.0.0.1:" + str(admin)}},
                                      "api": {"insecure": True}, "providers": {"file": {
                                          "filename": str(dynamic), "watch": False}}}))
        child = self.start([BINARIES["traefik"], "--configFile=" + str(config)], "traefik")
        self.listening(port)
        self.wait(lambda: any(router.get("name") == next(iter(http["routers"])) + "@file" and
                             router.get("status") == "enabled" for router in json.loads(
            request(admin, "localhost", "/api/http/routers")[1])))
        return child, port

    def assert_response(self, port, host, name, path="/", tls=False):
        status, body = request(port, host, path, self.cert if tls else None)
        self.assertEqual(status, 200, body)
        result = json.loads(body)
        self.assertEqual(result["name"], name, result)
        return result

    def cli(self, target, backend=None, reject=None, force=False):
        def run(args):
            result = subprocess.run([str(ENTRY), *args, target], capture_output=True, text=True, timeout=35)
            print("kill-port " + " ".join(args + [target]) + "\n" + result.stdout + result.stderr, flush=True)
            return result
        dry = run(["--dry-run"])
        if reject:
            self.assertNotEqual(dry.returncode, 0, dry.stdout)
            self.assertIn(reject, dry.stdout + dry.stderr)
        else:
            self.assertEqual(dry.returncode, 0, dry.stderr)
            self.assertIn("service 127.0.0.1:{} (PID {})".format(backend[1], backend[0].pid), dry.stdout)
        self.assertTrue(all(child.poll() is None for child, _ in self.children))
        result = run(["--force"] if force else [])
        if reject:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn(reject, result.stdout + result.stderr)
        else:
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(backend[0].wait(timeout=5), -signal.SIGKILL if force else -signal.SIGTERM)
        self.assertTrue(all(child.poll() is None for child, _ in self.children
                            if reject or child is not backend[0]))

if __name__ == "__main__" and sys.argv[1:2] == ["--backend"]:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            body = json.dumps({"name": sys.argv[2], "host": self.headers.get("Host"),
                               "path": self.path, "sni": self.headers.get("X-Observed-SNI")}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = LoopbackHTTPServer(("127.0.0.1", 0), Handler)
    print(json.dumps({"port": server.server_port}), flush=True)
    server.serve_forever()
