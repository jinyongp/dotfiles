"""Read nginx's static configuration, retaining block and include boundaries."""

from dataclasses import dataclass, replace
from datetime import datetime
import glob
import ipaddress
import os
from pathlib import Path
import re
import shlex
import socket
import subprocess
import sys
from urllib.parse import urlsplit

from discover import command, executable, resolve_addresses
from model import TraceError, canonical_ip, forwarded_host, split_address, unique, upstream, validate_path


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


def check_config_time(path, loaded_at, label):
    if Path(path).stat().st_mtime >= loaded_at:
        raise TraceError("nginx " + label + " changed since workers started; reload nginx before tracing: " + str(path))


def parse_config(path, prefix, loaded_at, stack=()):
    source = Path(path).absolute()
    for entry in (source, *source.parents):
        if entry.is_symlink():
            check_config_time(entry.parent, loaded_at, "symlink directory")
            if entry.lstat().st_mtime >= loaded_at:
                raise TraceError("nginx config symlink changed since workers started: " + str(entry))
    path = source.resolve()
    if path in stack or len(stack) >= 16:
        raise TraceError("cyclic/deep nginx include: " + str(path))
    check_config_time(path, loaded_at, "config")
    check_config_time(source.parent, loaded_at, "config directory")
    check_config_time(path.parent, loaded_at, "config directory")
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
                    # Deleting/renaming a glob include need not touch the main
                    # config or surviving files. Check directory metadata too.
                    fixed = Path(pattern)
                    while glob.has_magic(str(fixed)) or not fixed.exists():
                        fixed = fixed.parent
                    check_config_time(fixed if fixed.is_dir() else fixed.parent, loaded_at, "include directory")
                    for directory in glob.glob(str(Path(pattern).parent)):
                        check_config_time(directory, loaded_at, "include directory")
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
    if any(location.args and location.args[0].startswith("$") for location in locations):
        raise TraceError("nginx predicate/dynamic locations are not supported")
    if any(location.args and location.args[0].startswith("@") for location in locations):
        raise TraceError("nginx named/internal locations are not supported")
    if request.path is None:
        if any(location.args and location.args[0] in ("~", "~*") for location in locations):
            raise TraceError("nginx regex locations require unsupported PCRE matching")
        return locations or [Directive("location", ["/"], [])]
    # nginx uses case-insensitive filename comparison on macOS. It only folds
    # ASCII bytes, so Unicode lower()/casefold() would select different routes.
    fold = str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")
    def compare(value):
        return value.translate(fold) if sys.platform == "darwin" else value
    for location in locations:
        if location.args[:1] == ["="] and location.args[1:] and compare(location.args[1]) == compare(request.path):
            return [location]
    prefixes = [location for location in locations if location.args and
                location.args[0] not in ("=", "~", "~*", "@") and
                compare(request.path).startswith(compare(location.args[-1]))]
    best = max(prefixes, key=lambda location: len(location.args[-1]), default=None)
    if best and best.args[0] == "^~":
        return [best]
    if any(location.args and location.args[0] in ("~", "~*") for location in locations):
        raise TraceError("nginx regex locations require unsupported PCRE matching")
    return [best] if best else [Directive("location", ["/"], [])]


def listen_addresses(value):
    if value.startswith("unix:"):
        return []
    if value.isdigit():
        host, port = "0.0.0.0", int(value)
    else:
        try:
            host, port = str(ipaddress.ip_address(value.strip("[]"))), 80
        except ValueError:
            host, port = split_address(value) if ":" in value else (value, 80)
    if host == "*":
        host = "0.0.0.0"
    if not 1 <= port <= 65535:
        raise TraceError("invalid nginx listen port")
    try:
        return [(canonical_ip(item[4][0]), port) for item in socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)]
    except OSError as exc:
        raise TraceError("cannot resolve nginx listen address: " + host) from exc


def server_name_rank(server, host):
    rank = (0, 0)
    for directive in named(server.children, "server_name"):
        for pattern in directive.args:
            pattern = pattern.lower().rstrip(".")
            if pattern.startswith("~") or "$" in pattern:
                raise TraceError("nginx regex/dynamic server_name cannot be resolved")
            if pattern == host:
                rank = max(rank, (3, len(pattern)))
            elif pattern.startswith(".") and (host == pattern[1:] or host.endswith(pattern)):
                rank = max(rank, (2, len(pattern)))
            elif pattern.startswith("*.") and host.endswith(pattern[1:]):
                rank = max(rank, (2, len(pattern) - 1))
            elif pattern.endswith(".*") and host.startswith(pattern[:-1]):
                rank = max(rank, (1, len(pattern) - 1))
    return rank


def select_servers(http, request, port):
    groups, tls_endpoints = {}, set()
    for server in named(http, "server"):
        listeners = named(server.children, "listen")
        for listener in listeners or [Directive("listen", ["80"])]:
            for endpoint in listen_addresses(listener.args[0]):
                if (port or request.port) is not None and endpoint[1] != (port or request.port):
                    continue
                if "ssl" in listener.args:
                    tls_endpoints.add(endpoint)
                entries = groups.setdefault(endpoint, [])
                if not any(item[0] is server for item in entries):
                    entries.append((server, "default_server" in listener.args))
    endpoints = list(groups)
    if port is not None:
        addresses = resolve_addresses(request.address or request.host, port)
        endpoints = []
        for address in sorted(addresses):
            exact = (address, port)
            wildcard = ("::" if ":" in address else "0.0.0.0", port)
            endpoint = exact if exact in groups else wildcard
            if endpoint in groups and endpoint not in endpoints:
                endpoints.append(endpoint)
    selected = []
    for endpoint in endpoints:
        if request.scheme is not None and (request.scheme == "https") != (endpoint in tls_endpoints):
            continue
        entries = groups[endpoint]
        ranks = [(server_name_rank(server, request.host), server) for server, _ in entries]
        best = max((rank for rank, _ in ranks), default=(0, 0))
        if best != (0, 0):
            # nginx keeps the first declaration on duplicate server names.
            server = next(server for rank, server in ranks if rank == best)
        elif port is not None:
            if request.scheme == "https":
                raise TraceError("nginx TLS default virtual host cannot be inferred without its SNI context")
            defaults = [server for server, default in entries if default]
            if len(defaults) > 1:
                raise TraceError("ambiguous nginx default server")
            server = defaults[0] if defaults else entries[0][0]
        else:
            continue
        if not any(item is server for item in selected):
            selected.append(server)
    return selected


def resolve_config(http, request, port=None):
    servers = select_servers(http, request, port)
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
                selected_upstream = unique(destinations, "nginx upstream")
                value = replace(value, address=selected_upstream.address, port=selected_upstream.port)
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
            validate_path(path)
            targets.append(replace(value, host=forwarded_host(host), path=path))
    return unique(targets, "nginx route") if targets else None


def start_options(args):
    words = shlex.split(args.removeprefix("nginx: master process "))
    if not words:
        raise TraceError("nginx process arguments are not visible")
    options = {}
    index = 1
    while index < len(words):
        word = words[index]
        if word == "-q":
            index += 1
            continue
        flag = word[:2]
        if flag not in ("-c", "-p", "-e", "-g"):
            raise TraceError("ambiguous/unsupported nginx process arguments; use absolute paths without spaces")
        value = word[2:]
        if not value:
            index += 1
            if index >= len(words):
                raise TraceError("nginx process option is missing its argument: " + flag)
            value = words[index]
        if flag == "-g":
            if value == "daemon" and index + 1 < len(words):
                index += 1
                value += " " + words[index]
            if not re.fullmatch(r"daemon\s+(on|off);", value):
                raise TraceError("nginx global runtime directives beyond daemon on/off are not supported")
        options[flag] = value
        index += 1
    return options


class Nginx:
    def __init__(self, args, listeners):
        pid = listeners[0].pid
        if args.startswith("nginx: worker process"):
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
        build_words = shlex.split(result.stderr.split("configure arguments:", 1)[-1])
        settings = dict(word[2:].split("=", 1) for word in build_words if word.startswith(("--prefix=", "--conf-path=")))
        options = start_options(args)
        prefix = options.get("-p", settings.get("prefix", "/usr/local/nginx"))
        if not os.path.isabs(prefix):
            raise TraceError("nginx relative prefixes cannot be recovered from a daemon; use an absolute -p path")
        path = options.get("-c", settings.get("conf-path", "conf/nginx.conf"))
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
