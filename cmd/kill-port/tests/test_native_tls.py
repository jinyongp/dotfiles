"""Native TLS integration checks; see native_proxy for binary prerequisites."""

import json
import ssl
import unittest

from native_proxy import BINARIES, NativeProxyTestCase, free_port, request


class NativeTLS(NativeProxyTestCase):
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
    unittest.main()
