"""Values shared by local proxy discovery and route readers."""

from dataclasses import dataclass, replace
import ipaddress
import re
from urllib.parse import urlsplit


class TraceError(Exception):
    pass


@dataclass(frozen=True)
class Request:
    host: str
    port: int = None
    path: str = None
    scheme: str = None
    address: str = None


def parse_target(value):
    try:
        url = urlsplit(value if "://" in value else "//" + value)
        if url.scheme and url.scheme not in ("http", "https"):
            raise ValueError("expected http or https")
        if not url.hostname or url.username or url.password or url.fragment:
            raise ValueError("expected a hostname or HTTP(S) URL without credentials or fragment")
        host = url.hostname.rstrip(".").lower().encode("idna").decode("ascii")
        if not re.fullmatch(r"[a-z0-9_.:-]+", host):
            raise ValueError("invalid hostname")
        port = url.port
        if port is not None and not 1 <= port <= 65535:
            raise ValueError("port must be between 1 and 65535")
        if url.scheme and port is None:
            port = 443 if url.scheme == "https" else 80
        # A bare host means all paths. An explicit URL means its request path.
        path = (url.path or "/") if url.scheme or url.path else None
        if path and ("%" in path or "//" in path or any(part in (".", "..") for part in path.split("/"))):
            raise ValueError("encoded or unnormalized paths are not supported")
        if url.query:
            raise ValueError("query-dependent routing is not supported; use a path-only URL")
        return Request(host, port, path, url.scheme or None)
    except (ValueError, UnicodeError) as exc:
        raise TraceError("invalid target: " + str(exc)) from exc


def split_address(value):
    host, sep, port = value.rpartition(":")
    if not sep or not port.isdigit() or not 1 <= int(port) <= 65535:
        raise TraceError("unsupported TCP address: " + value)
    return host.strip("[]") or "*", int(port)


def upstream(value, request, host=None, path=None):
    if any(mark in value for mark in ("{", "}", "$")):
        raise TraceError("dynamic upstream cannot be resolved: " + value)
    target = parse_target(value if "://" in value else "http://" + value)
    return replace(request, address=target.host, port=target.port,
                   scheme=target.scheme, host=host or request.host,
                   path=request.path if path is None else path)


def unique(values, description):
    values = list(dict.fromkeys(values))
    if len(values) != 1:
        raise TraceError(description + (": no target" if not values else ": multiple targets; supply a more specific URL"))
    return values[0]


def host_matches(host, pattern):
    pattern = pattern.lower().rstrip(".")
    if pattern.startswith("*."):
        return host.endswith(pattern[1:]) and host.count(".") == pattern.count(".")
    return host == pattern


def forwarded_host(value):
    try:
        return str(ipaddress.ip_address(value))
    except ValueError:
        parsed = parse_target(value)
        return parsed.host


def canonical_ip(value):
    try:
        address = ipaddress.ip_address(value.split("%")[0])
        return str(getattr(address, "ipv4_mapped", None) or address)
    except ValueError:
        return value
