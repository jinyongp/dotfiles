---
name: queue
description: >
  Convert implementation plans, Markdown checklists, and work items into a
  Taskwarrior task queue. Use when the user asks to queue, taskify, 태스크화,
  작업 큐, 작업 등록, plan to tasks, checklist to tasks, or when workstream
  needs a Taskwarrior draft from plan Work Items. Shows a draft before mutation
  and delegates command safety to the taskwarrior skill.
---

# Queue

Turn a settled plan into Taskwarrior tasks. This skill designs the queue;
`taskwarrior` executes commands safely.

## Inputs

- Plan doc, preferably the repo's existing plan/docs convention; fallback `.agents/work/<slug>/plan.md`.
- Markdown checklist, usually `Work Items` and `Validation`.
- User-provided task list.

If no slug is given, derive one from goal/title with lowercase hyphen words.

## Mapping

- One independently verifiable checklist item = one task.
- Use `project:<slug>` for all tasks in the workstream.
- Implementation work: `+implementation`.
- Survey/research work: `+survey`.
- Validation/test work: `+validation`.
- Review work: `+review`.
- Risk/follow-up work: `+risk` or annotation.
- User-prioritized work: map only explicit priority to `priority:H|M|L`.
- Dependencies: use Taskwarrior `depends:` when work order is strict.

Do not create tasks for headings, vague reminders, unresolved decisions, or
non-goals.

## Dependencies

Use Taskwarrior's built-in dependency model for strict order:

- Discovery/survey tasks usually come before implementation.
- Implementation tasks usually block validation tasks for that behavior.
- Validation tasks usually block review/close tasks.
- Do not use dependencies for loose preference or "nice next" ordering.
- Prefer UUIDs for dependency wiring after task creation.
- Verify with `task project:<slug> blocked`, `task project:<slug> blocking`, and `task project:<slug> +READY next`.

Because dependency targets may not exist before add, draft dependencies by
task number, then wire them after creation with `depends:`.

## Draft

Always show draft before Taskwarrior mutation:

```txt
Task draft:
1. <description> project:<slug> +survey
2. <description> project:<slug> +implementation
3. <description> project:<slug> +validation
4. <description> project:<slug> +review

Dependencies:
- 2 depends on 1
- 3 depends on 2
- 4 depends on 3

Register these tasks?
```

If adding annotations:

```txt
Annotations:
- task 4: <risk or context>
```

## Execute

After user confirmation:

1. Load `taskwarrior`.
2. Resolve project-local store using Taskwarrior rules.
3. Preflight Taskwarrior when needed.
4. Add tasks with quoted descriptions.
5. Refresh `task project:<slug> uuids`.
6. Inspect specific created tasks with `task <uuid> information` when dependency wiring needs confirmation.
7. Apply strict dependencies with `depends:`.
8. Verify with `task project:<slug> list`, `blocked`, `blocking`, and `+READY next`.

Queue is for project/repo work. If no project-local Taskwarrior store exists,
ask to set one up; do not write global tasks.

Prefer simple `task add` commands. For bulk or scripted import, read
Taskwarrior safety refs first.

## Quality Bar

- Task descriptions should start with concrete verbs.
- Keep tasks small enough to complete and verify independently.
- Keep validation tasks explicit, not just `test`.
- Avoid duplicate tasks already present in the same `project:<slug>` report.
- Preserve user wording when it carries domain meaning.

## Output

After registration:

```txt
Queue:
- Project: <slug>
- Added: <n>
- Existing skipped: <n>
- Next: task project:<slug> +READY next
```
