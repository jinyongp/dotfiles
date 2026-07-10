# Safety And Files

Use before destructive ops, bulk mutation, import, sync, undo, config, context delete, hooks, aliases, execute.

Project-local active? Use shim bare `task`, or env prefix if shim missing.

## Aux Dir

Agent-created files:

```bash
out_dir=".tasks/aux"
mkdir -p "$out_dir"
```

Use for exports/backups/diagnostics/report dumps/scratch/JSON/notes. No root-level `tasks.json`, `backup.json`.

## Snapshot

Before destructive/broad/import/config/sync, prefer JSON export unless user declined:

```bash
out_dir=".tasks/aux"
mkdir -p "$out_dir"
task export > "$out_dir/tasks-export-before-change.json"
```

Multiple files? Use specific name, e.g. `before-purge-YYYYMMDD-HHMMSS.json`.

## Bulk Checklist

Before mutating >1 task:
1. Show filter.
2. `task <filter> count`.
3. `task <filter> list` or `uuids` if small.
4. Avoid stale numeric IDs.
5. Snapshot if hard to reverse/many tasks.
6. Execute.
7. Verify read.

## Delete / Purge

`delete` marks deleted. `purge` permanently removes deleted data. Purge irreversible.

```bash
task <filter> count
task <filter> list
task export > "$out_dir/before-delete-or-purge.json"
task <filter> delete
# only if permanent explicitly intended:
task <filter> purge
```

Vague cleanup != purge.

## Import

Before import: inspect path/provenance; prefer generated files under
`.tasks/aux/`; export current data; avoid untrusted JSON; verify with
`count|uuids|reports`.

## Sync

`sync|synchronize` uploads/downloads local changes. Data-affecting.

```bash
task diagnostics
task sync
```

No credential/cert config unless requested. No secret output.

## Undo

Only after confirming latest change and no other process changed data.

## Config / Context / Hooks / Aliases / Execute

- `config`: persistent behavior. Show key old/new.
- `context`: can hide tasks + write defaults. Show `task context show`.
- Hooks/aliases: code/behavior risk. Security-sensitive.
- `execute`: external command. Show exact shell; safely quote user text.
