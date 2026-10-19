"""Native HTTP checks, including proxy coexistence and management routes."""

import json
import unittest

from native_proxy import NativeProxyTestCase, request


def service(port):
    return {"loadBalancer": {"servers": [{"url": "http://127.0.0.1:" + str(port)}]}}


def router(host, service_name="app", entrypoint="web", path=""):
    return {"rule": "Host(`" + host + "`)" + path, "service": service_name, "entryPoints": [entrypoint]}


class NativeHTTP(NativeProxyTestCase):
    def basic(self, kind):
        backend, other = self.backend("selected"), self.backend("unrelated")
        host = kind + ".kp.localhost"
        if kind == "caddy":
            proxy, port = self.caddy(host, "reverse_proxy 127.0.0.1:" + str(backend[1]))
        elif kind == "nginx":
            proxy, port = self.nginx(host, "location / { proxy_pass http://127.0.0.1:" + str(backend[1]) + "; }")
        else:
            proxy, port = self.traefik(host, backend[1])
        self.assert_response(port, host, "selected")
        self.cli(host, backend)
        self.assert_response(other[1], "localhost", "unrelated")

    def test_caddy_domain(self):
        self.basic("caddy")

    def test_nginx_domain(self):
        self.basic("nginx")

    def test_traefik_domain(self):
        self.basic("traefik")

    def paths(self, kind):
        backend, other = self.backend("selected"), self.backend("fallback")
        host = kind + ".kp.localhost"
        if kind == "caddy":
            proxy, port = self.caddy(host, "handle /api/* {\nreverse_proxy 127.0.0.1:" + str(backend[1]) +
                                    "\n}\nhandle {\nreverse_proxy 127.0.0.1:" + str(other[1]) + "\n}")
        elif kind == "nginx":
            proxy, port = self.nginx(host, "location /api/ { proxy_pass http://127.0.0.1:" + str(backend[1]) +
                                    "/; } location / { proxy_pass http://127.0.0.1:" + str(other[1]) + "; }")
        else:
            proxy, port = self.traefik(host, backend[1], other[1])
        self.assert_response(port, host, "selected", "/api/item")
        self.assert_response(port, host, "fallback")
        self.cli(host, reject="requires a full URL" if kind == "nginx" else "multiple targets")
        self.cli("http://" + host + ":" + str(port) + "/api/item", backend, force=True)
        self.assert_response(port, host, "fallback")

    def test_caddy_paths(self):
        self.paths("caddy")

    def test_nginx_paths(self):
        self.paths("nginx")

    def test_traefik_paths(self):
        self.paths("traefik")

    def test_three_proxy_chain_preserves_host_and_rewrites_path(self):
        backend, other = self.backend("selected"), self.backend("fallback")
        inner, outer = "inner.kp.localhost", "outer.kp.localhost"
        t, tp = self.traefik_config({"routers": {"app": router(inner, path=" && Path(`/item`)"),
                                                "fallback": router(inner, "other")},
                                     "services": {"app": service(backend[1]), "other": service(other[1])}})
        n, np = self.nginx(inner, "location /api/ { proxy_set_header Host $host; proxy_pass http://127.0.0.1:" + str(tp) + "/; }")
        c, cp = self.caddy(outer, "reverse_proxy 127.0.0.1:" + str(np) + " {\nheader_up Host " + inner + "\n}")
        data = self.assert_response(cp, outer, "selected", "/api/item")
        self.assertEqual((data["host"], data["path"]), (inner, "/item"))
        self.cli("http://" + outer + ":" + str(cp) + "/api/item", backend)
        self.assert_response(tp, inner, "fallback", "/other")

    def test_disabled_caddy_api_refuses_to_signal(self):
        backend = self.backend("selected")
        host = "noapi.kp.localhost"
        proxy, port = self.caddy(host, "reverse_proxy 127.0.0.1:" + str(backend[1]), api=False)
        self.assert_response(port, host, "selected")
        self.cli("http://" + host + ":" + str(port) + "/", reject="no readable admin API")
        self.assert_response(port, host, "selected")

    def test_traefik_middleware_refuses_to_signal(self):
        backend = self.backend("selected")
        host = "middleware.kp.localhost"
        app = router(host)
        app["middlewares"] = ["strip"]
        proxy, port = self.traefik_config({"routers": {"app": app}, "services": {"app": service(backend[1])},
                                         "middlewares": {"strip": {"stripPrefix": {"prefixes": ["/api"]}}}})
        self.assertEqual(self.assert_response(port, host, "selected", "/api/item")["path"], "/item")
        self.cli("http://" + host + ":" + str(port) + "/api/item", reject="middleware")
        self.assert_response(port, host, "selected", "/api/item")

    def test_nginx_unreloaded_config_refuses_to_signal(self):
        backend = self.backend("selected")
        host = "stale.kp.localhost"
        proxy, port = self.nginx(host, "location / { proxy_pass http://127.0.0.1:" + str(backend[1]) + "; }")
        self.assert_response(port, host, "selected")
        config = self.conf / "nginx/nginx.conf"
        config.write_text(config.read_text() + "\n# Changed without a reload\n")
        self.cli("http://" + host + ":" + str(port) + "/", reject="changed since workers started")
        self.assert_response(port, host, "selected")

    def test_traefik_admin_does_not_obscure_caddy_domain(self):
        backend, other = self.backend("selected"), self.backend("traefik-service")
        t, tp = self.traefik("traefik.kp.localhost", other[1])
        c, cp = self.caddy("caddy.kp.localhost", "reverse_proxy 127.0.0.1:" + str(backend[1]))
        self.assert_response(cp, "caddy.kp.localhost", "selected")
        self.cli("caddy.kp.localhost", backend)
        self.assert_response(tp, "traefik.kp.localhost", "traefik-service")

    def test_explicit_management_port_refuses_to_signal(self):
        backend = self.backend("selected")
        host = "admin.kp.localhost"
        t, tp = self.traefik(host, backend[1])
        self.assertEqual(request(self.traefik_admin, "localhost", "/api/http/routers")[0], 200)
        self.cli("http://" + host + ":" + str(self.traefik_admin) + "/api/http/routers", reject="unsupported Traefik service")
        self.assert_response(tp, host, "selected")

    def test_shared_management_port_refuses_to_signal(self):
        backend = self.backend("selected")
        host = "shared.kp.localhost"
        t, tp = self.traefik_config({"routers": {"app": router(host, entrypoint="traefik")},
                                     "services": {"app": service(backend[1])}})
        status, body = request(self.traefik_admin, host, "/api/http/routers")
        self.assertEqual(status, 200)
        self.assertTrue(any(item.get("name") == "app@file" and item.get("status") == "enabled"
                            for item in json.loads(body)))
        self.cli(host, reject="unsupported Traefik service")
        self.cli("http://" + host + ":" + str(self.traefik_admin) + "/api/http/routers", reject="unsupported Traefik service")
        self.assert_response(backend[1], host, "selected")


if __name__ == "__main__":
    unittest.main()
