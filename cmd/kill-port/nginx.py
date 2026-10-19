"""Read nginx's static configuration, retaining block and include boundaries."""

from dataclasses import dataclass, replace
from datetime import datetime
import glob
import os
from pathlib import Path
import re
import shlex
import socket
import subprocess
from urllib.parse import urlsplit

from discover import command, executable
from model import TraceError, forwarded_host, host_matches, split_address, unique, upstream


@dataclass
class Directive:
    name: str
    args: list
    children: list = None


def tokenize(text):
    # nginx quotes can contain spaces, semicolons, braces, and comment markers.
    tokens = []
    word, quote, escaped, comment = "", None, False, False
    active = False
    for char in text:
        if comment:
            if char == "\n":
                comment = False
            continue
        if escaped:
            word += char
            escaped = False
            active = True
        elif char == "\\":
            escaped = True
        elif quote:
            if char == quote:
                quote = None
            else:
                word += char
        elif char in "\"'":
            quote, active = char, True
        elif char == "#":
            if active:
                tokens.append(word)
                word, active = "", False
            comment = True
        elif char.isspace() or char in "{};":
            if active:
                tokens.append(word)
                word, active = "", False
            if char in "{};":
                tokens.append(char)
        else:
            word += char
            active = True
    if quote or escaped:
        raise TraceError("unterminated nginx quote/escape")
    if active:
        tokens.append(word)
    return tokens


def parse_config(path, prefix, loaded_at, stack=()):
    path = Path(path).resolve()
    if path in stack or len(stack) >= 16:
        raise TraceError("cyclic/deep nginx include: " + str(path))
    if path.stat().st_mtime >= loaded_at:
        raise TraceError("nginx config changed since workers started; reload nginx before tracing: " + str(path))
    tokens = iter(tokenize(path.read_text()))

    def block(nested=False):
        result, words = [], []
        for token in tokens:
            if token in (";", "{"):
                if not words:
                    raise TraceError("invalid nginx directive")
                name, args = words[0], words[1:]
                words = []
                if name == "include" and token == ";":
                    if len(args) != 1 or "$" in args[0]:
                        raise TraceError("dynamic nginx include")
                    pattern = args[0] if os.path.isabs(args[0]) else str(Path(prefix) / args[0])
                    matches = sorted(glob.glob(pattern))
                    if not matches and not glob.has_magic(pattern):
                        raise TraceError("missing nginx include: " + pattern)
                    for included in matches:
                        result.extend(parse_config(included, prefix, loaded_at, stack + (path,)))
                else:
                    result.append(Directive(name, args, block(True) if token == "{" else None))
            elif token == "}":
                if not nested or words:
                    raise TraceError("invalid nginx block ending")
                return result
            else:
                words.append(token)
        if nested or words:
            raise TraceError("incomplete nginx config")
        return result

    return block()


def named(nodes, name):
    return [node for node in nodes if node.name == name]


def select_location(nodes, request):
    locations = named(nodes, "location")
    if any(location.args and location.args[0].startswith("@") for location in locations):
        raise TraceError("nginx named/internal locations are not supported")
    if request.path is None:
        if any(location.args and location.args[0] in ("~", "~*") for location in locations):
            raise TraceError("nginx regex locations require unsupported PCRE matching")
        return locations or [Directive("location", ["/"], [])]
    for location in locations:
        if location.args[:1] == ["="] and location.args[1:] == [request.path]:
            return [location]
    prefixes = [location for location in locations if location.args and
                location.args[0] not in ("=", "~", "~*", "@") and
                request.path.startswith(location.args[-1])]
    best = max(prefixes, key=lambda location: len(location.args[-1]), default=None)
    if best and best.args[0] == "^~":
        return [best]
    if any(location.args and location.args[0] in ("~", "~*") for location in locations):
        raise TraceError("nginx regex locations require unsupported PCRE matching")
    return [best] if best else [Directive("location", ["/"], [])]


def resolve_config(http, request, port=None):
    servers, defaults = [], []
    addresses = None
    if port is not None:
        try:
            addresses = {item[4][0] for item in socket.getaddrinfo(request.address or request.host, port, type=socket.SOCK_STREAM)}
        except OSError as exc:
            raise TraceError("cannot resolve nginx listener address") from exc
    for server in named(http, "server"):
        listeners = named(server.children, "listen")
        ports = set()
        for listener in listeners:
            value = listener.args[0]
            if value.startswith("unix:"):
                continue
            address, listener_port = ("*", int(value)) if value.isdigit() else split_address(value)
            wildcard = addresses is not None and (
                (address in ("*", "0.0.0.0") and any(":" not in item for item in addresses)) or
                (address == "::" and any(":" in item for item in addresses)))
            if addresses is None or wildcard or address in addresses:
                ports.add(listener_port)
        if not listeners:
            ports = {80}
        if (port or request.port) is not None and (port or request.port) not in ports:
            continue
        if port is not None:
            explicit_default = any("default_server" in listener.args for listener in listeners)
            defaults.append((explicit_default, server))
        patterns = [value for node in named(server.children, "server_name") for value in node.args]
        if any(pattern.startswith("~") for pattern in patterns):
            raise TraceError("nginx regex server_name cannot be resolved")
        if any(host_matches(request.host, pattern) for pattern in patterns):
            rank = 2 if request.host in patterns else 1
            for listener_port in ports:
                servers.append((rank, server, listener_port))
    if not servers:
        if not defaults:
            return None
        # A downstream request already has proven local socket ownership. nginx
        # uses that listener's default server when its Host has no named match.
        selected = [server for explicit, server in defaults if explicit]
        if len(selected) > 1:
            raise TraceError("ambiguous nginx default server")
        servers = [(1, selected[0] if selected else defaults[0][1], port)]
    servers = [server for rank, server, listener_port in servers
               if rank == max(item[0] for item in servers if item[2] == listener_port)]
    targets = []
    for server in servers:
        inherited = http + server.children
        for location in select_location(server.children, request):
            nodes = inherited + location.children
            passes = named(location.children, "proxy_pass") or named(server.children, "proxy_pass")
            if not passes:
                if any(node.name.endswith("_pass") for node in nodes):
                    raise TraceError("nginx upstream protocol beyond HTTP proxy_pass is not supported")
                if request.path is None:
                    continue
                return None
            if any(node.name in ("rewrite", "if", "try_files", "error_page", "location", "return")
                   for node in http + [item for item in server.children if item.name != "location"] + location.children):
                raise TraceError("nginx routing uses rewrites, nested locations, or conditional handling")
            destination = unique([node.args[0] for node in passes], "nginx proxy_pass")
            value = upstream(destination, request)
            # An upstream group names one or more actual TCP servers.
            groups = [node for node in named(http, "upstream") if node.args == [value.address]]
            proxy_host = value.address
            if groups:
                if len(groups) != 1:
                    raise TraceError("multiple nginx upstream groups")
                group = groups[0]
                if any(node.name not in ("server", "keepalive", "zone") for node in group.children):
                    raise TraceError("unsupported nginx upstream balancing/dynamic routing")
                destinations = []
                for node in named(group.children, "server"):
                    if any(arg in ("down", "backup", "resolve") for arg in node.args[1:]):
                        raise TraceError("nginx upstream has conditional server selection")
                    address = node.args[0]
                    destinations.append(upstream(address if ":" in address else address + ":80", request))
                value = unique(destinations, "nginx upstream")
            host = proxy_host
            headers = named(location.children, "proxy_set_header") or named(server.children, "proxy_set_header") or named(http, "proxy_set_header")
            for header in headers:
                if header.args[0].lower() == "host":
                    host = header.args[1]
                    if host in ("$host", "$http_host"):
                        host = request.host
                    elif host == "$proxy_host":
                        host = proxy_host
                    elif "$" in host:
                        raise TraceError("nginx upstream Host is dynamic")
            path = request.path
            target_path = urlsplit(destination).path
            if target_path:
                if request.path is None:
                    raise TraceError("nginx proxy_pass path rewrite requires a full URL")
                prefix = location.args[-1]
                path = target_path + request.path[len(prefix):]
            targets.append(replace(value, host=forwarded_host(host), path=path))
    return unique(targets, "nginx route") if targets else None


class Nginx:
    def __init__(self, args, listeners):
        pid = listeners[0].pid
        if "worker process" in args:
            pid = int(command(["ps", "-p", str(pid), "-o", "ppid="]).strip())
            args = command(["ps", "-p", str(pid), "-o", "args="]).strip()
        self.key = pid
        binary = executable(pid)
        # nginx writes -V to stderr, unlike its routing data.
        try:
            result = subprocess.run([binary, "-V"], text=True, capture_output=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise TraceError("cannot inspect nginx build settings: " + str(exc)) from exc
        if result.returncode:
            raise TraceError("cannot read nginx build settings")
        settings = dict(re.findall(r"--(prefix|conf-path)=([^\s]+)", result.stderr))
        words = shlex.split(args.removeprefix("nginx: master process "))
        if "-g" in words:
            globals_text = " ".join(words[words.index("-g") + 1:])
            if not re.fullmatch(r"daemon\s+(on|off);", globals_text):
                raise TraceError("nginx global runtime directives beyond daemon on/off are not supported")
        def option(flag, default):
            if flag in words:
                return words[words.index(flag) + 1]
            return next((word[len(flag):] for word in words if word.startswith(flag) and len(word) > len(flag)), default)
        prefix = option("-p", settings.get("prefix", "/usr/local/nginx"))
        path = option("-c", settings.get("conf-path", "conf/nginx.conf"))
        if not os.path.isabs(path):
            path = str(Path(prefix) / path)
        starts = []
        for listener in listeners:
            if listener.pid == pid and len(listeners) > 1:
                continue
            stamp = command(["ps", "-p", str(listener.pid), "-o", "lstart="]).strip()
            starts.append(datetime.strptime(stamp, "%a %b %d %H:%M:%S %Y").timestamp())
        if not starts:
            raise TraceError("nginx worker start time is not visible")
        config = parse_config(path, str(Path(path).parent), min(starts))
        http = named(config, "http")
        if len(http) != 1:
            raise TraceError("nginx has no unique HTTP configuration")
        self.http = http[0].children

    def resolve(self, request, port=None):
        return resolve_config(self.http, request, port)
