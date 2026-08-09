---
name: queue
description: >
  Convert implementation plans, Markdown checklists, and work items into a
  Taskwarrior task queue. Use when the user asks to queue, taskify, 태스크화,
  작업 큐, 작업 등록, plan to tasks, checklist to tasks, or when workstream
  needs a Taskwarrior queue from plan Work Items. Shows a concise user-language
  summary before mutation, then registers the queue when scope is unambiguous.
  Delegates command safety to the taskwarrior skill.
---

# Queue

Turn a settled plan into Taskwarrior tasks. This skill designs the queue;
`taskwarrior` executes commands safely.

## Inputs

- Plan doc, preferably the canonical `.tasks/items/<slug>/plan.md`.
- Markdown checklist, usually `Work Items` and `Validation`.
- User-provided task list.

If no slug is given, use the canonical resolver output. For standalone queues,
derive one from the settled goal/title with lowercase hyphen words.

## Mapping

- One independently verifiable checklist item = one task.
- Use `project:<slug>` for all tasks in the change.
- Implementation work: `+implementation`.
- Survey/research work: `+survey`.
- Validation/test work: `+validation`.
- Review work: `+review`.
- Risk/follow-up work: `+risk` or annotation.
- User-prioritized work: map only explicit priority to `priority:H|M|L`.
- Dependencies: use Taskwarrior `depends:` when work order is strict.

Do not create tasks for headings, vague reminders, unresolved decisions, or
non-goals.
Register only explicit actionable items from the input. Do not synthesize
terminal quality or closeout tasks absent from the plan or checklist.

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

## Registration

Taskwarrior queue registration is pre-approved when the user explicitly asks to
queue/taskify/register tasks or when `workstream` execution reaches the queue
step. Show a concise summary in the user's current language, then add the tasks
without a confirmation gate when scope is unambiguous and the mutation is
non-destructive repo-local task creation, annotation, or dependency wiring.

Do not dump raw `project:<slug>`, tags, or dependency lines by default when all
tasks share the same project.

```txt
작업 큐 추가:
- 프로젝트: <slug>
- 작업: <n>개
- 구성: 조사 <n>, 구현 <n>, 검증 <n>, 리뷰 <n>

요약:
- <short summary in user language>
- <short summary in user language>
- <short summary in user language>

바로 추가.
```

Keep the raw execution plan internally:

- task descriptions
- `project:<slug>`
- tags
- dependency map
- annotations

Show raw details only when the user asks, when projects differ, when dependency
shape is unusual, or when a mutation risk needs explicit inspection.

## Execute

1. Load `taskwarrior`.
2. Resolve project-local store using Taskwarrior rules.
3. Preflight Taskwarrior when needed.
4. Add tasks with quoted descriptions.
5. Refresh `task project:<slug> uuids`.
6. Inspect specific created tasks with `task <uuid> information` when dependency wiring needs confirmation.
7. Apply strict dependencies with `depends:`.
8. Verify with `task project:<slug> list`, `blocked`, `blocking`, and `+READY next`.

Queue is for project/repo work. If no project-local Taskwarrior store exists and
the queue is part of a workstream execution, set it up automatically and ensure
the root `.gitignore` contains the exact `/.tasks/` rule once. For standalone
queue requests, ask before setup. Do not write global tasks or create another
repo-local state root.

Prefer simple `task add` commands. For bulk or scripted import, read
Taskwarrior safety refs first.

## Quality Bar

- Task descriptions should start with concrete verbs.
- Keep tasks small enough to complete and verify independently.
- Keep validation tasks explicit, not just `test`.
- Avoid duplicate tasks already present in the same `project:<slug>` report.
- Preserve user wording when it carries domain meaning.
- User-facing registration summary should match the user's current language and level of detail.

## Output

After registration:

```txt
Queue:
- Project: <slug>
- Added: <n>
- Existing skipped: <n>
- Next: task project:<slug> +READY next
```
