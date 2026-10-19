# Verification

GitHub Actions and local checks share one command:

```sh
python3 -B scripts/verify.py
```

It runs Bash/zsh syntax checks, ShellCheck, actionlint, every shell test under
`scripts/tests`, and every Python test under `cmd/kill-port/tests`. ShellCheck
checks errors across Bash sources and warnings in the `kill-port` and `task`
entrypoints, preserving the existing focused warning checks.

Within each OS job, three groups run concurrently: static checks (including the
verification runner's regression tests), shell tests, and the Python suite. Checks
inside each group run sequentially. Native HTTP and TLS tests share process/socket
discovery, so they stay sequential within the Python group.

The Python suite includes real Caddy, nginx, and Traefik HTTP/TLS integration.
It verifies routing, signals, proxy survival, path/Host/SNI forwarding, protocol
mismatches, management routes, and refusal of unsupported or stale configurations.
Native processes and temporary certificates are isolated per test and cleaned up.

## Local tools

Use Python 3.12 or newer for tool preparation. Install Bash, zsh, Git, Perl,
OpenSSL, lsof, ShellCheck, a C compiler, make, and OpenSSL development headers.
On macOS, install Xcode Command Line Tools and Homebrew's `openssl@3` and
`shellcheck`. On Ubuntu, the workflow lists the required apt packages.

Prepare the same versioned tools that CI uses, outside the checkout:

```sh
DOTFILES_VERIFY_TOOLS="${TMPDIR:-/tmp}/dotfiles-verify-tools"
python3 -B scripts/ci/setup-tools.py --dir "$DOTFILES_VERIFY_TOOLS"
PATH="$DOTFILES_VERIFY_TOOLS/bin:$PATH" python3 -B scripts/verify.py
```

On macOS, also put `$(brew --prefix openssl@3)/bin` on PATH to use Homebrew's
OpenSSL CLI. The setup script supports Linux x64/ARM64 and macOS ARM64,
verifies release archive SHA-256 digests, and builds nginx with its HTTP
SSL module. Tool versions/digests are recorded in `scripts/ci/tool-versions.json`.
It reuses an existing matching installation after checking versions and SSL support.

Existing tools can also be used: place `actionlint`, `caddy`, `nginx`, and
`traefik` on PATH. `KILL_PORT_NATIVE_CADDY`, `KILL_PORT_NATIVE_NGINX`, and
`KILL_PORT_NATIVE_TRAEFIK` can override the individual native proxy paths.

Every full verification requires native tools, and any skipped Python test fails
the run. For an optional development run without native binaries, use ordinary
unittest discovery; that command may skip the native integration classes:

```sh
python3 -B -m unittest discover -s cmd/kill-port/tests -v
```

Logs are written to a new temporary run directory. Use
`python3 -B scripts/verify.py --log-dir /tmp/dotfiles-verification` to choose their
parent. Each run records a check summary, individual command logs, and native
proxy logs. The summary records each check's group, exit code, and duration. A
failure stops its group; independent groups finish and preserve their logs. Any
failed group fails the full run. The Python suite stops at its first failing test
so the failure details are reported before the group timeout. Timed-out checks terminate their process group
and allow the native fixture to clean up its proxy groups. Ctrl-C and SIGTERM stop
all groups and clean up active checks before returning a nonzero exit status.

## GitHub Actions

`.github/workflows/verify.yml` runs the same full command on standard
`ubuntu-26.04` x64 and `macos-26` ARM64 runners for pull requests, main pushes,
and manual dispatch. Jobs have a 15-minute limit. Newer runs cancel older runs
of the same workflow/ref. Jobs use read-only repository permissions.

The tool cache contains only native binaries and the install manifest. Its key
includes OS, architecture, tool versions, and setup logic. Failed runs retain only
verification logs for one day; temporary certificate keys are not uploaded.
Standard hosted runner execution is free while this repository is public.
Artifact/cache storage still uses GitHub's separate included allowances.

The additional runner label in `.github/actionlint.yaml` extends actionlint
v1.7.12's known labels for the official Ubuntu 26.04 image. It changes validation
only; both workflow runners are standard GitHub-hosted images.

## Action updates

Use `actions-up` to refresh workflow action references to current release SHAs:

```sh
actions-up --dir .github --min-age 0
python3 -B scripts/verify.py
```

Review the generated version comments and SHA changes before committing.
Runner labels and native tool versions are explicit so changes can be validated
alongside their platform-specific tests.
