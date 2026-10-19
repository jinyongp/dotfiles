"""Optional native integration: set KILL_PORT_NATIVE_{CADDY,NGINX,TRAEFIK}."""

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
from http.server import BaseHTTPRequestHandler, HTTPServer


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
class NativeTLS(unittest.TestCase):
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

    def caddy(self, host, body, tls=False, server_options=""):
        port, admin = free_port(), free_port()
        folder = self.conf / "caddy"
        folder.mkdir()
        config = folder / "Caddyfile"
        config.write_text("{\n admin 127.0.0.1:" + str(admin) +
                          "\n auto_https off\n persist_config off\n" +
                          ("servers {\n" + server_options + "\n}\n" if server_options else "") + "}\n" +
                          ("https" if tls else "http") + "://" + host + ":" + str(port) +
                          " {\n bind 127.0.0.1\n" +
                          ("tls " + str(self.cert) + " " + str(self.key) + "\n" if tls else "") + body + "\n}\n")
        child = self.start([BINARIES["caddy"], "run", "--config", config, "--adapter", "caddyfile"], "caddy")
        self.listening(port)
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
        time.sleep(1.2)  # Disk config must predate second-precision worker timestamps.
        child = self.start([BINARIES["nginx"], "-p", self.runtime, "-c", config], "nginx")
        self.listening(port)
        return child, port

    def traefik(self, host, selected, fallback=None, tls=False, upstream_tls=False, tls_options=False):
        port, admin = free_port(), free_port()
        folder = self.conf / "traefik"
        folder.mkdir()
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
        dynamic = folder / "dynamic.json"
        tls_config = {"certificates": [{"certFile": str(self.cert), "keyFile": str(self.key)}]}
        if tls_options:
            tls_config["options"] = {"guarded": {"minVersion": "VersionTLS12"}}
        dynamic.write_text(json.dumps({"http": http, "tls": tls_config}))
        config = folder / "traefik.json"
        config.write_text(json.dumps({"global": {"checkNewVersion": False, "sendAnonymousUsage": False},
                                      "entryPoints": {"web": {"address": "127.0.0.1:" + str(port)},
                                                      "traefik": {"address": "127.0.0.1:" + str(admin)}},
                                      "api": {"insecure": True}, "providers": {"file": {
                                          "filename": str(dynamic), "watch": False}}}))
        child = self.start([BINARIES["traefik"], "--configFile=" + str(config)], "traefik")
        self.listening(port)
        self.wait(lambda: any(router.get("name") == "app@file" for router in json.loads(
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

    def ingress(self, kind):
        backend, other = self.backend("selected"), self.backend("fallback")
        host = kind + ".kp.localhost"
        if kind == "caddy":
            proxy, port = self.caddy(host, "handle /api/* {\nreverse_proxy 127.0.0.1:" + str(backend[1]) +
                                    "\n}\nhandle {\nreverse_proxy 127.0.0.1:" + str(other[1]) + "\n}", tls=True)
        elif kind == "nginx":
            proxy, port = self.nginx(host, "location /api/ { proxy_pass http://127.0.0.1:" + str(backend[1]) +
                                    "/; } location / { proxy_pass http://127.0.0.1:" + str(other[1]) + "; }", tls=True)
        else:
            proxy, port = self.traefik(host, backend[1], other[1], tls=True)
        self.assert_response(port, host, "selected", "/api/item", tls=True)
        self.assert_response(port, host, "fallback", tls=True)
        self.cli("https://" + host + ":" + str(port) + "/api/item", backend, force=True)
        self.assert_response(port, host, "fallback", tls=True)

    def test_caddy_https_ingress(self):
        self.ingress("caddy")

    def test_nginx_https_ingress(self):
        self.ingress("nginx")

    def test_traefik_https_ingress(self):
        self.ingress("traefik")

    def protocol_mismatch(self, kind, tls):
        backend = self.backend("selected")
        host = "mismatch.kp.localhost"
        if kind == "caddy":
            proxy, port = self.caddy(host, "reverse_proxy 127.0.0.1:" + str(backend[1]), tls=tls)
        else:
            proxy, port = self.nginx(host, "location / { proxy_pass http://127.0.0.1:" + str(backend[1]) + "; }", tls=tls)
        self.assert_response(port, host, "selected", tls=tls)
        if tls:
            self.assertNotEqual(request(port, host)[0], 200)
        else:
            with self.assertRaises(ssl.SSLError):
                request(port, host, cert=self.cert)
        self.cli(("http" if tls else "https") + "://" + host + ":" + str(port) + "/", reject="cannot resolve")
        self.assert_response(port, host, "selected", tls=tls)

    def test_caddy_http_to_tls_is_rejected(self):
        self.protocol_mismatch("caddy", True)

    def test_caddy_implicit_automatic_https_policy(self):
        backend = self.backend("selected")
        host = "automatic.kp.localhost"
        port, admin = free_port(), free_port()
        config = self.conf / "caddy.json"
        config.write_text(json.dumps({"admin": {"listen": "127.0.0.1:" + str(admin), "config": {"persist": False}},
                                      "apps": {"tls": {"certificates": {"load_files": [
                                          {"certificate": str(self.cert), "key": str(self.key)}]}},
                                               "http": {"servers": {"web": {
                                                   "listen": ["127.0.0.1:" + str(port)],
                                                   "automatic_https": {"disable_redirects": True, "disable_certificates": True},
                                                   "routes": [{"match": [{"host": [host]}], "handle": [{
                                                       "handler": "reverse_proxy", "upstreams": [{
                                                           "dial": "127.0.0.1:" + str(backend[1])}]}]}]}}}}}))
        proxy = self.start([BINARIES["caddy"], "run", "--config", config], "caddy")
        self.listening(port)
        self.assert_response(port, host, "selected", tls=True)
        exported = json.loads(request(admin, "127.0.0.1:" + str(admin), "/config/")[1])
        self.assertNotIn("tls_connection_policies", exported["apps"]["http"]["servers"]["web"])
        self.cli("http://" + host + ":" + str(port) + "/", reject="cannot resolve")
        self.cli("https://" + host + ":" + str(port) + "/", backend)

    def test_caddy_https_to_plain_is_rejected(self):
        self.protocol_mismatch("caddy", False)

    def test_nginx_http_to_tls_is_rejected(self):
        self.protocol_mismatch("nginx", True)

    def test_nginx_https_to_plain_is_rejected(self):
        self.protocol_mismatch("nginx", False)

    def test_nginx_rejected_tls_handshake(self):
        backend = self.backend("selected")
        host = "reject.kp.localhost"
        proxy, port = self.nginx(host, "ssl_reject_handshake on; location / { proxy_pass http://127.0.0.1:" +
                                str(backend[1]) + "; }", tls=True)
        with self.assertRaises(ssl.SSLError):
            request(port, host, cert=self.cert)
        self.cli("https://" + host + ":" + str(port) + "/", reject="TLS")

    def test_nginx_tls_default_rejects_different_upstream_sni(self):
        backend = self.backend("selected")
        host, other, port = "inner.kp.localhost", "other.kp.localhost", free_port()
        default = "server { listen 127.0.0.1:" + str(port) + " ssl default_server; ssl_reject_handshake on; }"
        n, np = self.nginx(host, "location / { proxy_pass http://127.0.0.1:" + str(backend[1]) + "; }",
                           tls=True, http=default, port=port)
        self.assert_response(np, host, "selected", tls=True)
        c, cp = self.caddy(host, "reverse_proxy https://127.0.0.1:" + str(np) +
                           " {\nheader_up Host " + host + "\ntransport http {\ntls_server_name " + other +
                           "\ntls_trust_pool file " + str(self.cert) + "\n}\n}")
        self.assertEqual(request(cp, host)[0], 502)
        self.cli("http://" + host + ":" + str(cp) + "/", reject="TLS")
        self.cli("https://" + host + ":" + str(np) + "/", backend)

    def strict_caddy_upstream(self, mismatch):
        backend = self.backend("selected")
        host, other = "inner.kp.localhost", "other.kp.localhost"
        c, cp = self.caddy(host, "reverse_proxy 127.0.0.1:" + str(backend[1]), tls=True,
                           server_options="strict_sni_host on")
        self.assert_response(cp, host, "selected", tls=True)
        n, np = self.nginx(host, "location / { proxy_set_header Host " + host +
                           "; proxy_ssl_server_name on; proxy_ssl_name " + (other if mismatch else host) +
                           "; proxy_ssl_verify on; proxy_ssl_trusted_certificate " + str(self.cert) +
                           "; proxy_pass https://127.0.0.1:" + str(cp) + "; }")
        if mismatch:
            self.assertEqual(request(np, host)[0], 421)
            self.cli("http://" + host + ":" + str(np) + "/", reject="SNI")
            self.cli("https://" + host + ":" + str(cp) + "/", backend)
        else:
            self.assert_response(np, host, "selected")
            self.cli("http://" + host + ":" + str(np) + "/", backend)

    def test_caddy_strict_sni_rejects_different_upstream_host(self):
        self.strict_caddy_upstream(mismatch=True)

    def test_caddy_strict_sni_accepts_matching_upstream_sni(self):
        self.strict_caddy_upstream(mismatch=False)

    def test_nginx_rejected_default_does_not_obscure_another_proxy_domain(self):
        backend, other = self.backend("selected"), self.backend("nginx-service")
        host, port = "nginx.kp.localhost", free_port()
        default = "server { listen 127.0.0.1:" + str(port) + " ssl default_server; ssl_reject_handshake on; }"
        n, np = self.nginx(host, "location / { proxy_pass http://127.0.0.1:" + str(other[1]) + "; }",
                           tls=True, http=default, port=port)
        c, cp = self.caddy("caddy.kp.localhost", "reverse_proxy 127.0.0.1:" + str(backend[1]))
        self.assert_response(cp, "caddy.kp.localhost", "selected")
        self.cli("caddy.kp.localhost", backend)
        self.assert_response(np, host, "nginx-service", tls=True)

    def test_traefik_tls_options_reject_different_upstream_sni(self):
        backend = self.backend("selected")
        host, other = "inner.kp.localhost", "other.kp.localhost"
        t, tp = self.traefik(host, backend[1], tls=True, tls_options=True)
        self.assert_response(tp, host, "selected", tls=True)
        c, cp = self.caddy(host, "reverse_proxy https://127.0.0.1:" + str(tp) +
                           " {\nheader_up Host " + host + "\ntransport http {\ntls_server_name " + other +
                           "\ntls_trust_pool file " + str(self.cert) + "\n}\n}")
        self.assertEqual(request(cp, host)[0], 421)
        self.cli("http://" + host + ":" + str(cp) + "/", reject="SNI")
        self.cli("https://" + host + ":" + str(tp) + "/", backend)

    def upstream(self, kind):
        backend = self.backend("selected")
        host = "inner.kp.localhost"
        if kind == "caddy":
            inner, inner_port = self.nginx(host, "location / { proxy_set_header Host $host; " +
                                          "proxy_set_header X-Observed-SNI $ssl_server_name; " +
                                          "proxy_pass http://127.0.0.1:" + str(backend[1]) + "; }", tls=True)
            front, port = self.caddy(host, "reverse_proxy https://127.0.0.1:" + str(inner_port) +
                                    " {\nheader_up Host " + host + "\ntransport http {\ntls_server_name " + host +
                                    "\ntls_trust_pool file " + str(self.cert) + "\n}\n}")
        else:
            inner, inner_port = self.caddy(host, "reverse_proxy 127.0.0.1:" + str(backend[1]) +
                                          " {\nheader_up X-Observed-SNI {http.request.tls.server_name}\n}", tls=True)
            if kind == "nginx":
                front, port = self.nginx(host, "location / { proxy_set_header Host " + host +
                                        "; proxy_ssl_server_name on; proxy_ssl_name " + host +
                                        "; proxy_ssl_verify on; proxy_ssl_trusted_certificate " + str(self.cert) +
                                        "; proxy_pass https://127.0.0.1:" + str(inner_port) + "; }")
            else:
                front, port = self.traefik(host, inner_port, upstream_tls=True)
        data = self.assert_response(port, host, "selected", "/item")
        self.assertEqual((data["host"], data["path"], data["sni"]), (host, "/item", host))
        self.cli("http://" + host + ":" + str(port) + "/item", backend)

    def test_caddy_tls_upstream(self):
        self.upstream("caddy")

    def test_nginx_tls_upstream(self):
        self.upstream("nginx")

    def test_traefik_tls_upstream(self):
        self.upstream("traefik")

    def test_three_proxy_tls_chain(self):
        backend, other = self.backend("selected"), self.backend("unrelated")
        host = "chain.kp.localhost"
        t, tp = self.traefik(host, backend[1], tls=True)
        n, np = self.nginx(host, "location /api/ { proxy_set_header Host " + host +
                           "; proxy_ssl_server_name on; proxy_ssl_name " + host +
                           "; proxy_ssl_verify on; proxy_ssl_trusted_certificate " + str(self.cert) +
                           "; proxy_pass https://127.0.0.1:" + str(tp) + "/; }", tls=True)
        c, cp = self.caddy(host, "reverse_proxy https://127.0.0.1:" + str(np) +
                           " {\nheader_up Host " + host + "\ntransport http {\ntls_server_name " + host +
                           "\ntls_trust_pool file " + str(self.cert) + "\n}\n}", tls=True)
        data = self.assert_response(cp, host, "selected", "/api/item", tls=True)
        self.assertEqual((data["host"], data["path"]), (host, "/item"))
        self.cli("https://" + host + ":" + str(cp) + "/api/item", backend)
        self.assert_response(other[1], "localhost", "unrelated")


if __name__ == "__main__":
    if sys.argv[1:2] == ["--backend"]:
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

        server = HTTPServer(("127.0.0.1", 0), Handler)
        print(json.dumps({"port": server.server_port}), flush=True)
        server.serve_forever()
    else:
        unittest.main()
