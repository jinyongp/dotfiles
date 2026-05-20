# Read And Report

Use for read-only: search/list/count/inspect/summarize/export/discover.

## Start Narrow

```bash
task next
task +PENDING list
task project:Work next
task +OVERDUE list
task 12 information
task +READY count
```

Ambiguous natural language: inspect first; propose command; don't mutate.

## Defaults

- `next`: actionable by urgency
- `ready`: actionable, excludes future scheduled/waiting
- `list`: pending
- `long`: detailed pending
- `information`: full detail
- `count`: numeric
- `summary`, `projects`, `tags`, `timesheet`, `calendar`: summaries
- `reports`, `columns`, `commands`, `show`: discovery/config

## Built-Ins

Tasks: `active all blocked blocking completed list long ls minimal newest next oldest overdue ready recurring unblocked waiting`.

Stats: `count projects stats summary tags timesheet burndown.{daily,weekly,monthly} history.{daily,weekly,monthly,annual} ghistory.{daily,weekly,monthly,annual}`.

Meta: `reports columns commands show "show all" udas ids uuids version news colors diagnostics`.

## Export

Read-only command, but redirected file is generated artifact:

```bash
out_dir="$([ -d .codex ] && printf '%s' '.codex/taskwarrior' || printf '%s' '.taskwarrior/agent')"
mkdir -p "$out_dir"
task export > "$out_dir/taskwarrior-export.json"
task project:Work export > "$out_dir/work-tasks.json"
```

Use JSON for machines. `import` is mutating; safety branch.

## Custom Reports

1. `task columns`, `task reports`.
2. If exists: `task show report.<name>`.
3. Propose `task config report.<name>.*`; config mutation => safety ref.

Keys: filter, columns, labels, sort, description. Verify names via `columns`/`show`.

## Large Output

First count/narrow:

```bash
task +PENDING count
task project:Work count
task +PENDING limit:20 next
```

Long raw output: summarize by project/tag/due/urgency unless raw requested.
