# kill-port

Stop processes by numeric port, or trace a local reverse proxy's domain/URL to
its final local service and stop that service. Domain lookup reads running proxy
instances; no project registration or particular proxy tool is required.

```sh
kill-port 3000
kill-port --dry-run app.test
kill-port https://app.test/api
kill-port --force app.test
```

Numeric input retains the TCP-listener/UDP port behavior. Address input requires
Python 3.9+, `lsof`, and `ps` on macOS or Linux. Python uses only its standard
library. `--dry-run` performs discovery without sending a signal. `--force`
selects KILL instead of TERM; it uses the same route validation.

## Automatic discovery

The command identifies running proxies from local TCP socket owners, then reads
their routes. A bare domain considers all paths and listener ports. A URL selects
its scheme's port (or an explicit port) and path. If multiple paths lead to
different services, supply a full URL. A domain matching both outer and inner
proxies starts at the outermost matching proxy.

| Proxy | Route source | Supported routing |
| --- | --- | --- |
| Caddy | Live `GET /config/` on a TCP admin socket owned by the process | Host/path matchers, nested subroutes, static TCP upstreams, path-prefix stripping before a proxy in the same handler chain |
| nginx | Process-selected config and included files | Static server names, prefix/exact locations, `proxy_pass`, single-server upstream groups, static/preserved upstream Host |
| Traefik | Live routers, services, and entrypoints from its TCP API | Host/Path/PathPrefix rules, router priority, single-server load balancers |
| gate | Live `GET /routes` on the daemon's process-selected Unix socket | Local domain routes with static upstreams |

TCP admin discovery is limited to the detected proxy's own listening sockets
(at most 16, one-second timeout per request). It does not enable admin APIs,
reload configurations, or send requests to the supplied application URL. An
unavailable API or unreadable configuration produces an error.

nginx config includes resolve relative to the main configuration directory.
Configuration files newer than visible worker start times are rejected: reload
nginx before tracing. This is a freshness check on disk configuration, not an
export of nginx's in-memory configuration. Preserve normal file timestamps.

## Target selection and limits

Each upstream is checked against visible local TCP listeners. Tracing retains
the forwarded Host and supported path changes, follows at most 16 hops, and
rejects cycles. Before signalling, the command repeats discovery and compares
the full route, socket owner, and process identity/start time. It prints the
proxy chain, final service port, and PID.

Ambiguous upstreams, remote upstreams, container forwarders, unavailable services,
and unsupported routing conditions stop tracing without sending a signal.
Domain mode does not fall back to killing an unresolved HTTP/HTTPS listener.
An explicit local address with a non-80/443 port can select a direct service.

Unsupported conditions include dynamic upstreams, regex/conditional routing,
query-dependent or encoded/unnormalized paths, Traefik middleware, nginx internal
locations/rewrites, gate exposed aliases, Caddy cross-route rewrites/mixed subroute
pipelines, Caddy Unix admin sockets, and Caddy TLS
upstreams without an explicit forwarded Host (its default varies by version). Use a
supported local route or an explicit numeric service port where appropriate.

Only the listed proxy binaries are recognized automatically. Forwarding hidden
inside an ordinary application process cannot be inferred from socket ownership.
Domain mode requires one final service PID; shared service sockets are rejected.
It never elevates permissions or stops containers. System process inspection and
local API access must be allowed by the environment.

## Validation

```sh
python3 -B -m unittest discover -s cmd/kill-port/tests -v
bash scripts/tests/cli-ui.sh
```

Route tests cover host/path matching, ambiguous targets, includes and freshness,
cycles, local address families, and route changes before signalling. CLI tests
exercise real admin API servers and disposable service processes with supplied
socket inventory, plus numeric termination with real `lsof` socket ownership.

API references: [Caddy](https://caddyserver.com/docs/api),
[nginx proxy_pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass),
[Traefik](https://doc.traefik.io/traefik/reference/install-configuration/api-dashboard/).
