# Mutate Tasks

Use for add/edit/annotate/clone/start/stop/done.

Baseline before existing-task change:
1. Read target set.
2. Check filter not empty/too broad.
3. Destructive/bulk/import/sync/undo/config/hook/alias => safety first.
4. Verify after with `information`, `list`, or report.

## Add

```bash
task add "Prepare launch checklist" project:Ops due:friday +planning
task add "Reply to supplier" project:Procurement wait:tomorrow
```

Context can add hidden defaults. If relevant: `task context show`.

## Log Done Work

```bash
task log "Called supplier about ink samples" project:Procurement +call
```

## Modify

```bash
task 12 modify project:Ops due:tomorrow +urgent
task 12 modify priority:
task 12 modify depends:34
```

Multi-task preview:

```bash
task project:Ops +PENDING count
task project:Ops +PENDING list
task project:Ops +PENDING modify +review
```

No broad `modify` without explicit filter + confirmation.

## Description / Notes

```bash
task 12 annotate "Waiting for vendor reply"
task 12 denotate "Waiting for vendor reply"
task 12 append "- final proof"
task 12 prepend "URGENT:"
```

`modify "new description"` replaces whole description. Use only when intended.

## Start / Stop

```bash
task 12 start
task 12 stop
task +ACTIVE list
```

Check active tasks before broad start/stop.

## Done

```bash
task 12 done
task project:Ops +READY done
```

Bulk done: preview exact target + count first.

## Duplicate

```bash
task 12 duplicate
task 12 duplicate project:NextCycle due:nextweek
```

Inspect new task; verify inherited attrs/recurrence.

## Edit

`task <id> edit` opens editor. Prefer explicit `modify|annotate|append|prepend` for agent audit. Use `edit` only when user wants manual interactive edit.
