"""Runtime route readers. Only static host/path rules are resolved."""

from dataclasses import replace
import re
import shlex
from urllib.parse import urlsplit

from discover import read_json
from model import TraceError, forwarded_host, host_matches, split_address, unique, upstream


def admin_addresses(listeners):
    # Probe only sockets owned by the detected proxy, never arbitrary network ports.
    return sorted({("127.0.0.1" if item.address in ("*", "0.0.0.0") else
                    "::1" if item.address == "::" else item.address, item.port)
                   for item in listeners}, key=lambda value: (value[1] not in (2019, 8080), value))[:16]


def discover_api(listeners, path, validate):
    for address in admin_addresses(listeners):
        try:
            data = read_json(address, path)
            if validate(data):
                return address, data
        except TraceError:
            pass
    raise TraceError("no readable admin API on this proxy's listening sockets")


class Gate:
    def __init__(self, args, listeners):
        words = shlex.split(args)
        try:
            index = words.index("--socket")
            self.socket = words[index + 1]
        except (ValueError, IndexError) as exc:
            raise TraceError("gate daemon socket is missing from its process arguments") from exc
        self.routes = read_json(self.socket, "/routes")["routes"]

    def resolve(self, request, port=None):
        matches = [route for route in self.routes if request.host == route["domain"].lower().rstrip(".")]
        if not matches:
            return None
        if any(route.get("exposed") for route in matches):
            raise TraceError("gate exposed route does not publish its forwarded Host; use its local domain")
        return unique([upstream(route["upstream"], request) for route in matches], "gate route")


def caddy_path(pattern, path):
    if any(char in pattern for char in "%?[]\\{}"):
        raise TraceError("unsupported Caddy path pattern: " + pattern)
    pattern, path = pattern.lower(), path.lower()
    if pattern == "*":
        return True
    if pattern.startswith("*") and pattern.endswith("*") and pattern.count("*") == 2:
        return pattern[1:-1] in path
    if pattern.endswith("*") and pattern.count("*") == 1:
        return path.startswith(pattern[:-1])
    if pattern.startswith("*") and pattern.count("*") == 1:
        return path.endswith(pattern[1:])
    return re.fullmatch(re.escape(pattern).replace(r"\*", "[^/]*"), path) is not None


def caddy_match(matchers, request):
    if not matchers:
        return True
    for match in matchers:
        # Check known mismatches before rejecting an unsupported condition.
        if "host" in match and not any(host_matches(request.host, host) for host in match["host"]):
            continue
        if "path" in match and request.path is not None and not any(
                caddy_path(path, request.path) for path in match["path"]):
            continue
        if set(match) - {"host", "path"}:
            raise TraceError("Caddy route uses matchers beyond host/path")
        return True
    return False


def caddy_routes(routes, request):
    targets = []
    for route in routes:
        if not caddy_match(route.get("match"), request):
            continue
        current = request
        resolved = []
        handlers = route.get("handle", [])
        for index, handler in enumerate(handlers):
            kind = handler.get("handler")
            if kind == "subroute":
                if len(handlers) != 1:
                    raise TraceError("Caddy mixed subroute handler pipelines are not supported")
                children = caddy_routes(handler.get("routes", []), current)
                if not children:
                    raise TraceError("Caddy subroute does not resolve to an upstream service")
                resolved.extend(children)
            elif kind == "reverse_proxy":
                if handler.get("dynamic_upstreams") or handler.get("rewrite") or handler.get("handle_response"):
                    raise TraceError("Caddy dynamic upstream/rewrite/response routing is not statically resolvable")
                headers = handler.get("headers", {}).get("request", {})
                if "tls" in handler.get("transport", {}) and not any(
                        key.lower() == "host" for key in headers.get("set", {})):
                    raise TraceError("Caddy HTTPS upstream requires an explicit Host header for tracing")
                if headers.get("delete") or headers.get("replace") or headers.get("add"):
                    raise TraceError("Caddy upstream request headers require unsupported transformations")
                host = current.host
                for key, values in headers.get("set", {}).items():
                    if key.lower() == "host":
                        value = unique(values, "Caddy upstream Host")
                        if value not in ("{http.request.host}", "{http.request.hostport}"):
                            if "{" in value:
                                raise TraceError("Caddy upstream Host is dynamic")
                            host = forwarded_host(value)
                destinations = handler.get("upstreams", [])
                if not destinations or any(set(item) - {"dial", "max_requests"} for item in destinations):
                    raise TraceError("unsupported Caddy upstream definition")
                values = [upstream(item["dial"], current, host=host) for item in destinations]
                if "tls" in handler.get("transport", {}):
                    values = [replace(value, scheme="https") for value in values]
                resolved.append(unique(values, "Caddy upstream"))
            elif kind == "rewrite":
                allowed = {"handler", "strip_path_prefix"}
                if set(handler) - allowed or current.path is None:
                    raise TraceError("Caddy rewrite requires a concrete supported path")
                if not any(item.get("handler") == "reverse_proxy" for item in handlers[index + 1:]):
                    raise TraceError("Caddy rewrites across routes are not supported")
                prefix = handler.get("strip_path_prefix", "")
                path = current.path[len(prefix):] if current.path.startswith(prefix) else current.path
                current = replace(current, path=path or "/")
            elif kind in ("headers", "encode"):
                continue
            elif kind == "static_response":
                # Redirects/static responses are not upstream services.
                path_conditional = any("path" in match for match in route.get("match", []))
                if request.path is not None or not path_conditional:
                    return targets
            else:
                raise TraceError("unsupported Caddy handler: " + str(kind))
        targets.extend(resolved)
        if not resolved and (route.get("group") or route.get("terminal")):
            raise TraceError("Caddy grouped/terminal route has no determinable upstream service")
        # A reverse proxy handles a concrete request. With no path, inspect all
        # routes so a path-specific service cannot be silently overlooked.
        if request.path is not None and (resolved or route.get("terminal")):
            break
    return targets


class Caddy:
    def __init__(self, args, listeners):
        self.address, config = discover_api(listeners, "/config/", lambda value:
                                           isinstance(value, dict) and "apps" in value)
        self.servers = config.get("apps", {}).get("http", {}).get("servers", {})

    def resolve(self, request, port=None):
        targets = []
        for server in self.servers.values():
            ports = {split_address(value)[1] for value in server.get("listen", [])}
            if (port or request.port) is not None and (port or request.port) not in ports:
                continue
            targets.extend(caddy_routes(server.get("routes", []), request))
        return unique(targets, "Caddy route") if targets else None


def traefik_rule(rule, request):
    branches = re.split(r"\s*\|\|\s*", rule)
    matched = False
    for branch in branches:
        valid, unknown = True, False
        for term in re.split(r"\s*&&\s*", branch):
            match = re.fullmatch(r"\s*(Host|Path|PathPrefix)\((.*)\)\s*", term)
            if not match:
                unknown = True
                continue
            kind, arguments = match.groups()
            values = re.findall(r'`([^`]+)`|"([^"\\]+)"', arguments)
            if not values or re.sub(r'`[^`]+`|"[^"\\]+"|[,\s]', "", arguments):
                unknown = True
                continue
            values = [a or b for a, b in values]
            if kind == "Host":
                valid &= request.host in [value.lower().rstrip(".") for value in values]
            elif request.path is not None:
                valid &= any(request.path == value if kind == "Path" else request.path.startswith(value)
                             for value in values)
        if valid and unknown:
            raise TraceError("unsupported Traefik rule: " + rule)
        matched |= valid
    return matched


class Traefik:
    def __init__(self, args, listeners):
        self.address, self.routers = discover_api(listeners, "/api/http/routers", lambda value:
                                                isinstance(value, list) and all("rule" in item for item in value))
        self.services = {item["name"]: item for item in read_json(self.address, "/api/http/services")}
        self.entrypoints = {item["name"]: split_address(item["address"])[1]
                            for item in read_json(self.address, "/api/entrypoints")}

    def resolve(self, request, port=None):
        routers = []
        for router in self.routers:
            if router.get("status") != "enabled":
                continue
            if request.scheme is not None and (router.get("tls") is not None) != (request.scheme == "https"):
                continue
            ports = {self.entrypoints[name] for name in router.get("entryPoints", []) if name in self.entrypoints}
            if not ports:
                raise TraceError("Traefik router has no identifiable entrypoint")
            if (port or request.port) is not None and (port or request.port) not in ports:
                continue
            if traefik_rule(router["rule"], request):
                routers.append(router)
        if request.path is not None and routers:
            priority = max(router.get("priority") or len(router["rule"]) for router in routers)
            routers = [router for router in routers if (router.get("priority") or len(router["rule"])) == priority]
        targets = []
        for router in routers:
            if router.get("middlewares"):
                raise TraceError("Traefik middleware may change routing; cannot resolve safely")
            service_name = router["service"]
            if "@" not in service_name:
                service_name += "@" + router["provider"]
            service = self.services.get(service_name, {})
            if service.get("type") != "loadbalancer" or "loadBalancer" not in service:
                raise TraceError("unsupported Traefik service: " + service_name)
            balancer = service["loadBalancer"]
            destinations = balancer.get("servers", [])
            if not destinations:
                raise TraceError("Traefik service has no upstream servers")
            host = None if balancer.get("passHostHeader", True) else ""
            values = []
            for destination in destinations:
                if urlsplit(destination["url"]).path not in ("", "/"):
                    raise TraceError("Traefik upstream URL path rewriting is not supported")
                value = upstream(destination["url"], request)
                if host == "":
                    value = replace(value, host=value.address)
                values.append(value)
            targets.append(unique(values, "Traefik upstream"))
        return unique(targets, "Traefik route") if targets else None
