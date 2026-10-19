from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from discover import Listener, Snapshot, parse_listeners
from model import Request, TraceError, parse_target
from nginx import parse_config, resolve_config
from proxies import Caddy, Traefik, caddy_path, caddy_routes, traefik_rule
import trace as tracer


def proxy_route(host, port, path=None):
    match = {"host": [host]}
    if path:
        match["path"] = [path]
    return {"match": [match], "handle": [{"handler": "reverse_proxy", "upstreams": [{"dial": "127.0.0.1:" + str(port)}]}]}


class InputsAndSockets(unittest.TestCase):
    def test_host_and_url_have_distinct_path_meanings(self):
        self.assertEqual(parse_target("APP.test."), Request("app.test"))
        self.assertEqual(parse_target("https://app.test/api"), Request("app.test", 443, "/api", "https"))
        self.assertEqual(parse_target("localhost:3000").port, 3000)
        self.assertEqual(parse_target("http://[::1]:3000").host, "::1")

    def test_reject_inputs_that_cannot_be_routed_statically(self):
        for value in ("ftp://app.test", "https://u:p@app.test", "app.test:0", "app.test:65536",
                      "https://app.test/api?user=x", "https://app.test/a/../b", "https://app.test/a%2fb"):
            with self.subTest(value=value), self.assertRaises(TraceError):
                parse_target(value)

    def test_lsof_retains_ipv6_and_socket_ownership(self):
        sockets = parse_listeners("p42\ncnode\nf3\ntIPv6\nn[::1]:3000\nf4\ntIPv4\nn127.0.0.1:3000\n")
        self.assertEqual({(item.pid, item.address, item.port) for item in sockets},
                         {(42, "::1", 3000), (42, "127.0.0.1", 3000)})

    def test_remote_upstream_and_wrong_address_family_are_rejected(self):
        snapshot = Snapshot.__new__(Snapshot)
        snapshot.listeners = [Listener(42, "node", "::", 3000, "IPv6")]
        snapshot.local = {"127.0.0.1", "::1"}
        self.assertEqual(snapshot.owners(Request("127.0.0.1", 3000)), [])
        self.assertEqual(len(snapshot.owners(Request("::1", 3000))), 1)
        with self.assertRaisesRegex(TraceError, "remote"):
            snapshot.owners(Request("192.0.2.1", 3000))


class CaddyRoutes(unittest.TestCase):
    def test_cross_route_rewrite_and_static_subroute_never_select_fallback(self):
        routes = [{"handle": [{"handler": "rewrite", "strip_path_prefix": "/api"}]},
                  proxy_route("app.test", 3000)]
        with self.assertRaisesRegex(TraceError, "across routes"):
            caddy_routes(routes, parse_target("https://app.test/api/users"))
        routes = [{"handle": [{"handler": "subroute", "routes": [
            {"handle": [{"handler": "static_response", "status_code": 404}]}]}]}, proxy_route("app.test", 3000)]
        with self.assertRaisesRegex(TraceError, "subroute"):
            caddy_routes(routes, Request("app.test"))

    def test_unconditional_static_route_does_not_select_unreachable_service(self):
        routes = [{"match": [{"host": ["app.test"]}],
                   "handle": [{"handler": "static_response", "status_code": 404}]}, proxy_route("app.test", 3000)]
        self.assertEqual(caddy_routes(routes, Request("app.test")), [])

    def test_path_case_and_middle_wildcard_follow_caddy_semantics(self):
        self.assertTrue(caddy_path("/api/*", "/API/users/me"))
        self.assertTrue(caddy_path("/accounts/*/info", "/accounts/user/info"))
        self.assertFalse(caddy_path("/accounts/*/info", "/accounts/user/private/info"))

    def test_https_upstream_without_explicit_host_is_not_guessed(self):
        route = proxy_route("app.test", 8443)
        route["handle"][0]["transport"] = {"protocol": "http", "tls": {}}
        with self.assertRaisesRegex(TraceError, "explicit Host"):
            caddy_routes([route], Request("app.test"))

    def test_path_selection_and_bare_domain_ambiguity(self):
        routes = [proxy_route("app.test", 3001, "/api*"), proxy_route("app.test", 3000)]
        caddy = Caddy.__new__(Caddy)
        caddy.servers = {"web": {"listen": [":443"], "routes": routes}}
        self.assertEqual(caddy.resolve(parse_target("https://app.test/api/users")).port, 3001)
        self.assertEqual(caddy.resolve(parse_target("https://app.test/")).port, 3000)
        with self.assertRaisesRegex(TraceError, "multiple"):
            caddy.resolve(parse_target("app.test"))
        self.assertIsNone(caddy.resolve(parse_target("https://other.test/")))

    def test_nested_routes_and_prefix_stripping(self):
        routes = [{"match": [{"host": ["*.test"]}], "handle": [{"handler": "subroute", "routes": [
            {"match": [{"path": ["/api/*"]}], "handle": [
                {"handler": "rewrite", "strip_path_prefix": "/api"},
                {"handler": "reverse_proxy", "upstreams": [{"dial": "[::1]:3000"}]}]}]}]}]
        target = caddy_routes(routes, parse_target("https://app.test/api/users"))[0]
        self.assertEqual((target.address, target.port, target.path, target.host), ("::1", 3000, "/users", "app.test"))

    def test_multiple_upstreams_and_unknown_matching_conditions_fail(self):
        route = proxy_route("app.test", 3000)
        route["handle"][0]["upstreams"].append({"dial": "127.0.0.1:3001"})
        with self.assertRaisesRegex(TraceError, "multiple"):
            caddy_routes([route], Request("app.test"))
        route["match"][0]["header"] = {"User": ["a"]}
        with self.assertRaisesRegex(TraceError, "matchers"):
            caddy_routes([route], Request("app.test"))
        self.assertEqual(caddy_routes([route], Request("other.test")), [])


class TraefikRoutes(unittest.TestCase):
    def make_reader(self):
        reader = Traefik.__new__(Traefik)
        reader.entrypoints = {"websecure": 443}
        reader.routers = [
            {"name": "web@file", "rule": "Host(`app.test`)", "service": "web@file",
             "entryPoints": ["websecure"], "status": "enabled", "tls": {}},
            {"name": "api@file", "rule": "Host(`app.test`) && PathPrefix(`/api`)", "service": "api@file",
             "entryPoints": ["websecure"], "status": "enabled", "tls": {}}]
        reader.services = {name + "@file": {"type": "loadbalancer", "loadBalancer": {
            "servers": [{"url": "http://127.0.0.1:" + str(port)}]}}
            for name, port in (("web", 3000), ("api", 3001))}
        return reader

    def test_rule_priority_and_host_preservation(self):
        reader = self.make_reader()
        result = reader.resolve(parse_target("https://app.test/api/users"))
        self.assertEqual((result.port, result.host), (3001, "app.test"))
        with self.assertRaisesRegex(TraceError, "multiple"):
            reader.resolve(Request("app.test"))
        self.assertTrue(traefik_rule('Host(`a.test`)||Host(`app.test`)', Request("app.test")))

    def test_middleware_and_regex_fail_instead_of_guessing(self):
        reader = self.make_reader()
        reader.routers[1]["middlewares"] = ["strip@file"]
        with self.assertRaisesRegex(TraceError, "middleware"):
            reader.resolve(parse_target("https://app.test/api"))
        with self.assertRaisesRegex(TraceError, "unsupported"):
            traefik_rule("HostRegexp(`.*`)", Request("app.test"))


class NginxRoutes(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def config(self, text):
        path = self.root / "nginx.conf"
        path.write_text(text)
        return parse_config(path, self.root, time.time() + 1)[0].children

    def test_include_upstream_and_longest_location(self):
        (self.root / "api.conf").write_text('location /api/ { proxy_set_header Host $host; proxy_pass http://api/v1/; }')
        http = self.config('''http {
            upstream api { server 127.0.0.1:3001; }
            server { listen 443 ssl; server_name app.test;
                include api.conf;
                location / { proxy_pass http://127.0.0.1:3000; }
            }
        }''')
        result = resolve_config(http, parse_target("https://app.test/api/users"))
        self.assertEqual((result.address, result.port, result.path, result.host), ("127.0.0.1", 3001, "/v1/users", "app.test"))
        result = resolve_config(http, parse_target("https://app.test/"))
        self.assertEqual((result.port, result.host), (3000, "127.0.0.1"))

    def test_reject_stale_config_and_recursive_include(self):
        path = self.root / "nginx.conf"
        path.write_text("include nginx.conf;")
        with self.assertRaisesRegex(TraceError, "changed"):
            parse_config(path, self.root, 0)
        with self.assertRaisesRegex(TraceError, "cyclic"):
            parse_config(path, self.root, time.time() + 1)

    def test_downstream_default_server_is_only_used_after_socket_resolution(self):
        http = self.config('''http { server { listen 8080 default_server; server_name _;
            location / { proxy_pass http://127.0.0.1:3000; }
        } }''')
        request = Request("app.test", 8080, "/api", "http", "127.0.0.1")
        self.assertIsNone(resolve_config(http, request))
        self.assertEqual(resolve_config(http, request, port=8080).port, 3000)

    def test_regex_dynamic_and_ambiguous_upstreams_fail(self):
        for body in (
                'location ~ /api { proxy_pass http://127.0.0.1:3000; }',
                'location / { proxy_pass http://$backend; }',
                'location / { if ($x) { return 403; } proxy_pass http://127.0.0.1:3000; }'):
            http = self.config('http { server { listen 443; server_name app.test; ' + body + ' } }')
            with self.subTest(body=body), self.assertRaises(TraceError):
                resolve_config(http, parse_target("https://app.test/api"))


class ChainResolution(unittest.TestCase):
    def resolver(self, destinations, final_command="node"):
        snapshot = Snapshot.__new__(Snapshot)
        snapshot.listeners = [Listener(10, "caddy", "127.0.0.1", 443),
                              Listener(20, "gate", "127.0.0.1", 8080),
                              Listener(30, final_command, "127.0.0.1", 3000)]
        snapshot.local = {"127.0.0.1", "::1"}
        resolver = tracer.Resolver.__new__(tracer.Resolver)
        resolver.snapshot, resolver.failures = snapshot, {}
        def reader(address):
            class Reader:
                def resolve(self, request, port=None):
                    return destinations[address](request)
            return Reader()
        resolver.proxies = [tracer.Proxy("caddy", (10,), snapshot.listeners[:1], reader(443)),
                            tracer.Proxy("gate", (20,), snapshot.listeners[1:2], reader(8080))]
        return resolver

    def test_chain_preserves_host_and_finishes_on_service_pid(self):
        from model import upstream
        resolver = self.resolver({443: lambda request: upstream("127.0.0.1:8080", request),
                                 8080: lambda request: upstream("127.0.0.1:3000", request)})
        with patch.object(tracer, "identity", side_effect=lambda pid: str(pid)):
            plan = resolver.trace(Request("app.test"))
        self.assertEqual(plan.pid, 30)
        self.assertEqual([step[0] for step in plan.steps], ["caddy", "gate"])

    def test_cycle_container_and_no_proxy_do_not_select_frontend(self):
        from model import upstream
        for destination, final_command, error in (("127.0.0.1:8080", "node", "cycle"),
                                                   ("127.0.0.1:3000", "OrbStack Helper", "forwarder")):
            resolver = self.resolver({443: lambda request: upstream("127.0.0.1:8080", request),
                                     8080: lambda request: upstream(destination, request) if request.port == 8080 else None}, final_command)
            with self.subTest(error=error), self.assertRaisesRegex(TraceError, error):
                resolver.trace(Request("app.test"))
        resolver.proxies = []
        with self.assertRaisesRegex(TraceError, "no matching route"):
            resolver.trace(parse_target("https://app.test"))

    def test_route_change_recheck_sends_no_signal(self):
        first = tracer.Plan(Request("app.test"), Request("localhost", 3000), 30, (), ((30, "original"),))
        second = tracer.Plan(Request("app.test"), Request("localhost", 3001), 31, (), ((31, "new"),))
        with patch.object(tracer, "Resolver") as resolver, patch.object(tracer.os, "kill") as kill:
            resolver.return_value.trace.side_effect = [first, second]
            with self.assertRaisesRegex(TraceError, "changed"):
                tracer.execute("app.test")
            kill.assert_not_called()


if __name__ == "__main__":
    unittest.main()
