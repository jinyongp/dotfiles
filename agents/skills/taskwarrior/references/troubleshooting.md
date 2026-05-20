# Troubleshooting

Use for install/env/filter/sync/quoting/data warnings/bug reports.

## Preflight

```bash
command -v task
task --version
task diagnostics
```

Missing `task`: don't guess install command unless OS known.

## Missing Tasks

Check context/status/wait/scheduled/report filters:

```bash
task context show
task all
task +WAITING waiting
task +PENDING count
task show default.command
```

Common: active context, waiting hidden, completed/deleted, future scheduled, custom report filter.

## ID Mismatch

IDs are display-scoped. Wrong task/disappeared ID => refresh + use UUID:

```bash
task <filter> uuids
task <uuid> information
```

## Quoting

Quote `or`, regex, parens, spaces, symbols:

```bash
task '( project:Work or +ops )' list
task '/supplier invoice/' list
```

## Sync Fail

```bash
task diagnostics
task show sync
```

Redact certs, keys, credential URLs, private paths.

## Data Warning

No repair-like command unless documented + explicit. First export:

```bash
out_dir="$([ -d .codex ] && printf '%s' '.codex/taskwarrior' || printf '%s' '.taskwarrior/agent')"
mkdir -p "$out_dir"
task export > "$out_dir/before-troubleshooting.json"
task diagnostics > "$out_dir/diagnostics.txt"
```

Then inspect diagnostics + representative `information`.

## Bug Report

Collect: version, OS/shell, exact command, redacted diagnostics, minimal repro/export with sensitive text removed. Store artifacts under `.codex/taskwarrior/` or `.taskwarrior/agent/`.
