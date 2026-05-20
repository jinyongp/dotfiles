# Command Router

Use only to choose branch.

## Read

Read/report/export/search/count/inspect => `read-and-report.md`.

Reports/commands: `next`, `ready`, `list`, `ls`, `long`, `minimal`, `active`, `waiting`, `overdue`, `blocked`, `blocking`, `unblocked`, `recurring`, `completed`, `all`, `count`, `summary`, `stats`, `projects`, `tags`, `timesheet`, `calendar`, `history.*`, `ghistory.*`, `burndown.*`, `information`, `reports`, `columns`, `commands`, `show`, `udas`, `ids`, `uuids`, `colors`, `diagnostics`, `export`, `version`, `news`.

## Mutate Task

Normal task changes => `mutate-tasks.md`: `add`, `log`, `annotate`, `denotate`, `append`, `prepend`, `modify`, `edit`, `start`, `stop`, `done`, `duplicate`.

## Safety First

Read `safety-and-files.md` before:
- broad/bulk `modify|done|delete|purge|denotate|start|stop|duplicate|edit`
- `import`, `sync|synchronize`, `undo`, `config`, context delete, hook/alias, `execute`
- command from JSON/shell substitution/script/user file

## Data/Config/Sync

`data-config-and-sync.md`: `export`, `import`, `sync|synchronize`, `undo`, `config`, `show`, `context`, UDAs, aliases, hooks, extensions, `execute`.

## Filter

Use `selectors-and-filters.md` when task set not obvious. Common bugs: wrong filter, stale numeric ID, active context, shell quoting.

## Debug

Use `troubleshooting.md` for missing binary, wrong version, data warnings, duplicate UUIDs, context surprises, script vs interactive mismatch, diagnostics.

## Inventory

Use `assets/command-groups.json` only for coverage/obscure command lookup.
