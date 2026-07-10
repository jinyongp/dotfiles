# Data / Config / Sync

Use for `export`, `import`, `sync|synchronize`, `undo`, `config`, `context`, UDAs, aliases, hooks, extensions, `execute`.

Mutates data/config/remote? Read `safety-and-files.md` first.

Project-local active? Use shim bare `task`, or env prefix if shim missing.

## Export

Read-only, but writes generated file:

```bash
out_dir=".tasks/aux"
mkdir -p "$out_dir"
task export > "$out_dir/tasks-export.json"
task project:Work export > "$out_dir/work-export.json"
```

Machines: JSON > table parse.

## Import

Mutates local data. Safe flow:

```bash
out_dir=".tasks/aux"
mkdir -p "$out_dir"
task export > "$out_dir/before-import.json"
task import "$out_dir/incoming.json"
task count
```

Untrusted/non-export JSON: inspect/validate first.

## Sync

Official: `synchronize`; common: `sync`.

```bash
task show sync
task diagnostics
task sync
```

Do not print certs/keys/secrets. Redact private paths/tokens.

## Undo

`undo` only latest change. Confirm what latest change is; not general rollback.

```bash
task undo
```

## Config

Inspect:

```bash
task show
task show report.next
task show context
task columns
task reports
```

Change one key:

```bash
task config report.next.columns id,priority,project,due,description,urgency
task config default.command next
```

Remove/reset: show current value first; require clear intent.

## Context

Context filters reads + can apply write defaults. Inspect first:

```bash
task context show
task context list
```

Create/switch/delete: state read + write effects. Delete safety-sensitive.

## UDA

Before add/edit: `task udas`, `task show uda`. Define type/label/values/report use. Avoid built-in/existing name conflicts.

## Hooks / Aliases / Extensions

Security-sensitive. Read config/files first. No executable hook unless user explicitly wants hook behavior + understands effect.

## Execute

Only when user explicitly asks Taskwarrior to run external command. Show exact command; quote user text; avoid destructive shell patterns.
