# Selectors And Filters

Shape:

```text
task <filter> <command> [mods|args]
```

Filter before command. Mods after.

```bash
task project:Work +urgent next
task +PENDING due.before:eow list
task 12 modify due:tomorrow priority:H +client
task 12 annotate "Waiting for supplier reply"
```

## Safe Select

- Single visible task: refresh report before numeric ID.
- Scripts/multi-step/cross-session: prefer `task <filter> uuids`.
- Bulk: first `count`, `list`, or `uuids` with same filter.
- Status matters: use `status:pending` or `+PENDING`; don't assume report default.
- Active context: `task context show`; contexts affect reads + write defaults.

## Common Filters

```bash
task +PENDING list
task project:Work list
task +urgent due.before:eow next
task status:completed completed
task +OVERDUE list
task -BLOCKED +READY next
task description.contains:invoice list
task /regex/ list
```

`+tag` require/add. `-tag` exclude/remove. Position matters.

## Logic

Default op: `and`. Quote `or|xor` + parens:

```bash
task '( project:Work or project:Ops )' list
task '( +urgent or due:today )' next
```

## IDs

```bash
task 1 information
task 1 2 3 modify +review
task 1-5 list
task ebeeab00-ccf8-464b-8b58-f7f2d606edfb information
```

Numeric IDs interactive only. UUIDs safer.

## Dates / Recurrence

Common: `due:today`, `due:tomorrow`, `due:eow`, `wait:later`, `scheduled:monday`, `until:eom`, `recur:weekly`, `recur:monthly`.

Recurring task: require frequency + meaningful due/scheduled. Verify `task recurring`, `task <id> information`.

## Attrs

Common mods: `project:Work`, `priority:H|M|L`, `priority:`, `due:tomorrow`, `wait:later`, `scheduled:today`, `recur:weekly`, `until:eoy`, `+tag`, `-tag`.

Empty value clears. Confirm before bulk clear.

## Tags

Virtual tags filter only: `+PENDING`, `+OVERDUE`, `+READY`, `+ACTIVE`, `+BLOCKED`, `+ANNOTATED`, `+UDA`, `+WAITING`. Do not add/remove.

Real special tags assignable: `+next`, `+nocolor`, `+nonag`, `+nocal`. Explain side effect.

## Quote

Quote spaces, parens, regex, wildcards, `or`, `xor`, `$`, `!`, `&`, `|`, `;`, `<`, `>`, backticks. Avoid shell-building with untrusted descriptions.
