"""Resolve a local reverse-proxy chain before signalling its final service."""

from dataclasses import dataclass
import os
import signal
import sys

from discover import Snapshot, command, identity
from model import TraceError, parse_target, unique, validate_path
from nginx import Nginx
from proxies import Caddy, Gate, Traefik


READERS = {"caddy": Caddy, "nginx": Nginx, "traefik": Traefik, "gate": Gate}
BLOCKED = ("haproxy", "envoy", "httpd", "apache2", "docker-proxy", "orbstack", "ssh", "socat")
INSPECTION_ERRORS = (TraceError, OSError, ValueError, KeyError, TypeError, AttributeError, IndexError)


def proxy_kind(name):
    name = name.lower()
    return next((kind for kind in READERS if name == kind), None)


def blocked(name):
    return any(name.lower().startswith(value) for value in BLOCKED)


@dataclass
class Proxy:
    kind: str
    pids: tuple
    listeners: list
    reader: object


class Resolver:
    def __init__(self, snapshot=None):
        self.snapshot = snapshot or Snapshot()
        groups, self.failures, self.proxies = {}, {}, []
        for listener in self.snapshot.listeners:
            kind = proxy_kind(listener.command)
            if not kind:
                continue
            key = (kind, listener.pid)
            try:
                args = command(["ps", "-p", str(listener.pid), "-o", "args="]).strip()
                if kind == "nginx" and args.startswith("nginx: worker process"):
                    key = (kind, int(command(["ps", "-p", str(listener.pid), "-o", "ppid="]).strip()))
                group = groups.setdefault(key, [args, []])
                group[1].append(listener)
            except TraceError as exc:
                self.failures[listener.pid] = str(exc)
        for (kind, pid), (args, listeners) in groups.items():
            try:
                reader = READERS[kind](args, listeners)
                self.proxies.append(Proxy(kind, tuple(sorted({item.pid for item in listeners})), listeners, reader))
            except INSPECTION_ERRORS as exc:
                for listener in listeners:
                    self.failures[listener.pid] = kind + ": " + str(exc)

    def trace(self, request):
        candidates, errors = [], []
        for proxy in self.proxies:
            if request.port is not None and not any(item.port == request.port for item in proxy.listeners):
                continue
            try:
                target = proxy.reader.resolve(request)
                if target is not None:
                    candidates.append((proxy, target))
            except INSPECTION_ERRORS as exc:
                errors.append(proxy.kind + ": " + str(exc))
        relevant_failures = [message for pid, message in self.failures.items() if any(
            item.pid == pid and (request.port is None or item.port == request.port)
            for item in self.snapshot.listeners)]
        errors.extend(relevant_failures)
        if errors:
            raise TraceError("cannot establish an unambiguous route: " + "; ".join(sorted(set(errors))))
        if len(candidates) > 1 and request.port is None:
            # Inner proxies often preserve the same Host. Remove candidates
            # reached by another matching proxy so discovery starts at ingress.
            incoming = set()
            for proxy, target in candidates:
                owners = {item.pid for item in self.snapshot.owners(target)}
                for other, _ in candidates:
                    if set(other.pids) & owners:
                        incoming.update(other.pids)
            candidates = [(proxy, target) for proxy, target in candidates if not set(proxy.pids) & incoming]
            if not candidates:
                raise TraceError("reverse-proxy routing cycle detected while finding ingress")
        if len(candidates) > 1:
            raise TraceError("domain matches multiple proxy routes; supply a URL with its listener port and path")
        steps, protected = [], set()
        if candidates:
            proxy, current = candidates[0]
            protected.update(proxy.pids)
            steps.append((proxy.kind, proxy.pids, request, current))
        elif request.port not in (None, 80, 443):
            current = request
        else:
            raise TraceError("no matching route in a supported running local proxy (Caddy, nginx, Traefik, gate)")

        seen = set()
        for _ in range(16):
            validate_path(current.path)
            if current in seen:
                raise TraceError("reverse-proxy routing cycle detected")
            seen.add(current)
            owners = self.snapshot.owners(current)
            if not owners:
                raise TraceError("no visible local service listening on upstream port " + str(current.port))
            pids = {item.pid for item in owners}
            failures = [self.failures[pid] for pid in pids if pid in self.failures]
            if failures:
                raise TraceError("cannot inspect upstream proxy: " + "; ".join(failures))
            proxies = [proxy for proxy in self.proxies if set(proxy.pids) & pids]
            if proxies:
                if len(proxies) != 1 or not pids <= set(proxies[0].pids):
                    raise TraceError("upstream socket has ambiguous proxy ownership")
                proxy = proxies[0]
                target = proxy.reader.resolve(current, current.port)
                if target is None:
                    raise TraceError("upstream proxy has no matching route: " + proxy.kind)
                protected.update(proxy.pids)
                steps.append((proxy.kind, proxy.pids, current, target))
                current = target
                continue
            if protected & pids or any(proxy_kind(item.command) or blocked(item.command) for item in owners):
                raise TraceError("upstream is a proxy or container forwarder without a resolvable route")
            pid = unique(sorted(pids), "final service socket ownership")
            fingerprints = tuple((item, identity(item)) for item in sorted(protected | {pid}))
            return Plan(request, current, pid, tuple(steps), fingerprints)
        raise TraceError("reverse-proxy chain exceeds 16 hops")


@dataclass(frozen=True)
class Plan:
    request: object
    service: object
    pid: int
    steps: tuple
    fingerprints: tuple

    def describe(self):
        lines = ["kill-port: tracing " + self.request.host]
        for kind, pids, source, target in self.steps:
            lines.append("  {} (PID {}) -> {}:{}".format(kind, ",".join(map(str, pids)), target.address, target.port))
        lines.append("kill-port: service {}:{} (PID {})".format(
            self.service.address or self.service.host, self.service.port, self.pid))
        return "\n".join(lines)


def execute(value, signal_name="TERM", dry_run=False):
    request = parse_target(value)
    plan = Resolver().trace(request)
    if dry_run:
        return plan.describe() + "\nkill-port: dry run; no signal sent"
    # Re-read live routes, socket ownership, and process start times immediately
    # before signalling. A changed route/PID requires a fresh invocation.
    if Resolver().trace(request) != plan or identity(plan.pid) != dict(plan.fingerprints)[plan.pid]:
        raise TraceError("routing or process identity changed during tracing; retry")
    os.kill(plan.pid, getattr(signal, "SIG" + signal_name))
    return plan.describe() + "\nkill-port: sent {} to service PID {}".format(signal_name, plan.pid)


def main():
    try:
        print(execute(sys.argv[1], sys.argv[2], sys.argv[3] == "1"))
    except INSPECTION_ERRORS as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
