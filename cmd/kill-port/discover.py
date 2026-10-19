"""Read local socket ownership and process identity without shell evaluation."""

from dataclasses import dataclass
import http.client
import ipaddress
import json
import os
import socket
import subprocess

from model import TraceError, canonical_ip, split_address


def command(args, empty_ok=False):
    try:
        result = subprocess.run(args, text=True, capture_output=True, timeout=5,
                                env=dict(os.environ, LC_ALL="C"))
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise TraceError("cannot inspect " + args[0] + ": " + str(exc)) from exc
    if result.returncode and not (empty_ok and result.returncode == 1 and not result.stdout):
        raise TraceError("cannot inspect " + args[0] + ": " + (result.stderr.strip() or "command failed"))
    return result.stdout


@dataclass(frozen=True)
class Listener:
    pid: int
    command: str
    address: str
    port: int
    family: str = ""


def parse_listeners(output):
    listeners = set()
    pid, name, family = None, "", ""
    for line in output.splitlines():
        if line.startswith("p"):
            pid, name = int(line[1:]), ""
        elif line.startswith("c"):
            name = line[1:]
        elif line.startswith("f"):
            family = ""
        elif line.startswith("t"):
            family = line[1:]
        elif line.startswith("n") and pid:
            address, port = split_address(line[1:])
            listeners.add(Listener(pid, name, canonical_ip(address), port, family))
    return sorted(listeners, key=lambda item: (item.pid, item.address, item.port))


def identity(pid):
    value = command(["ps", "-p", str(pid), "-o", "lstart=", "-o", "args="]).strip()
    if not value:
        raise TraceError("process disappeared: " + str(pid))
    return value


class Snapshot:
    def __init__(self):
        self.listeners = parse_listeners(command(
            ["lsof", "-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcnt"], empty_ok=True))
        self.local = {item.address for item in self.listeners if item.address not in ("*", "0.0.0.0", "::")}
        self.local.update(("127.0.0.1", "::1"))

    def owners(self, request):
        host = request.address or request.host
        if host == "localhost" or host.endswith(".localhost"):
            addresses = {"127.0.0.1", "::1"}
        else:
            try:
                addresses = {canonical_ip(item[4][0]) for item in socket.getaddrinfo(host, request.port, type=socket.SOCK_STREAM)}
            except OSError as exc:
                raise TraceError("cannot resolve upstream " + host + ": " + str(exc)) from exc
        if not addresses or any(address not in self.local and not ipaddress.ip_address(address).is_loopback
                                for address in addresses):
            raise TraceError("upstream is remote or not a visible local address: " + host)
        def matches(item):
            if item.address in addresses:
                return True
            family = item.family or ("IPv6" if item.address == "::" else "IPv4")
            return item.address in ("*", "0.0.0.0", "::") and any(
                (":" in address) == (family == "IPv6") for address in addresses)
        return [item for item in self.listeners if item.port == request.port and matches(item)]


class UnixConnection(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__("localhost", timeout=1)
        self.path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.path)


def read_json(address, path):
    connection = UnixConnection(address) if isinstance(address, str) else http.client.HTTPConnection(*address, timeout=1)
    try:
        connection.request("GET", path, headers={"Connection": "close"})
        response = connection.getresponse()
        if response.status != 200:
            raise TraceError("admin API returned HTTP " + str(response.status))
        body = response.read(4 * 1024 * 1024 + 1)
        if len(body) > 4 * 1024 * 1024:
            raise TraceError("admin API response exceeds 4 MiB")
        return json.loads(body)
    except (OSError, ValueError, http.client.HTTPException) as exc:
        raise TraceError("admin API unavailable: " + str(exc)) from exc
    finally:
        connection.close()


def executable(pid):
    paths = command(["lsof", "-a", "-p", str(pid), "-d", "txt", "-Fn"])
    for line in paths.splitlines():
        if line.startswith("n") and os.access(line[1:], os.X_OK) and os.path.isfile(line[1:]):
            return line[1:]
    raise TraceError("cannot locate proxy executable for PID " + str(pid))
