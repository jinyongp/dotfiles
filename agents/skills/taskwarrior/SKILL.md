---
name: taskwarrior
description: >
  Operate stable Taskwarrior `task` CLI: list/filter/report/add/modify/done/delete,
  projects, tags, due dates, recurrence, contexts, sync, import/export, config,
  UDAs, hooks, aliases, troubleshooting.
metadata:
  target-taskwarrior-version: "3.4.2 stable"
  generated-on: "2026-05-15"
---

# Taskwarrior

Use `task` safely. Target 3.4.2 stable. No legacy syntax unless user asks migration.

## Defaults

- Read first. Mutate only when target + side effect clear.
- If a higher-level skill such as `workstream` or `queue` says repo-local
  non-destructive task mutation is pre-approved, do not ask for another
  confirmation. Still require explicit approval for global task writes,
  destructive commands, broad bulk changes, sync/config changes, or unclear
  scope.
- Project/local/repo task request: never write global `~/.taskrc` or `~/.task`.
- `.tasks/taskrc` in cwd/parent => project-local.
- Dotfiles has `$DOTFILES/cmd/task` shim. Bootstrap puts it before real `task`.
- Bare `task` OK only when shim active; shim finds `.tasks/taskrc`, exports `TASKRC/TASKDATA`, delegates real Taskwarrior.
- If shim unavailable, prefix: `TASKRC="$PWD/.tasks/taskrc" TASKDATA="$PWD/.tasks/data" task ...`
- `task` may be another tool. Verify real Taskwarrior with `task diagnostics`.
- Numeric IDs volatile. Refresh report before use. UUIDs for scripts/multi-step/cross-session.
- Name store for mutation: project-local via shim, project-local via env, or global.

## Project-Local Setup

If user asks project-local and no `.tasks/taskrc`, propose + confirm
before files unless a higher-level workstream/queue instruction pre-approves
repo-local setup:

```bash
mkdir -p .tasks/data
printf 'data.location=%s\nconfirmation=1\n' "$PWD/.tasks/data" > .tasks/taskrc
```

Git repo: ensure the root `.gitignore` contains the exact `/.tasks/` rule once.
Do not use `.git/info/exclude`, a nested ignore file, or another repo-local state
root. Do not edit `.env`, `.envrc`, dotenv files, shell profiles, package scripts.

Global `task`: before mutation, state no project-local store found; ask/confirm.

## Lazy Refs

- Route: `references/command-router.md`
- Filters/IDs/dates/tags/attrs/quoting: `references/selectors-and-filters.md`
- Read/export/report: `references/read-and-report.md`
- Add/modify/done/start/annotate: `references/mutate-tasks.md`
- Destructive/bulk/import/sync/undo/config/hooks/aliases/execute: `references/safety-and-files.md` first
- Data/config/sync/contexts/UDAs: `references/data-config-and-sync.md`
- Debug: `references/troubleshooting.md`
- Inventory: `assets/command-groups.json`

## Aux Files

Agent files:

```bash
out_dir=".tasks/aux"
mkdir -p "$out_dir"
```

Use for exports/backups/diagnostics/scratch. `.tasks/` is the single local root,
not committed docs.

## Workflow

1. Classify: read, mutate, safety, data/config/sync, debug.
2. Resolve store: `.tasks/taskrc` or project-local request => project-local; else global only after disclosure.
3. Preflight: `command -v task`, `task diagnostics`, `task --version`.
4. Inspect narrow: `task next`, `task <filter> list`, `task <id> information`, `task context show`, `task reports`.
5. Shape: `task <filter> <command> [mods|args]`.
6. Mutation: read-only target first. Confirm only when no higher-level skill pre-approval applies. Safety-sensitive => safety ref first.
7. Execute only when unambiguous. Verify with read command.

Never broad write (`modify`, `done`, `delete`, `purge`) without explicit scope + safety. Quote spaces, parens, regex, `or`, `xor`, shell metachars, user text.
