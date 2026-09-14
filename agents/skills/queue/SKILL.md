---
name: queue
description: >
  Convert implementation plans, Markdown checklists, and work items into a
  task queue. Use when the user asks to queue, taskify, 태스크화, 작업 큐,
  작업 등록, plan to tasks, or checklist to tasks.
---

# Queue

Turn a settled plan, checklist, or user-provided list into actionable tasks.
Use the task tool selected for the project when registration is requested.

## Mapping

- One independently verifiable checklist item becomes one task.
- Preserve project scope and references to source work items.
- Distinguish implementation, survey, validation, review, and follow-up work.
- Map priorities only when explicitly provided.
- Add dependencies only for strict work order, not loose preferences.
- Exclude headings, vague reminders, unresolved decisions, and non-goals.
- Register only explicit actionable items; add no terminal quality or closeout
  tasks absent from the input.

## Registration

For a draft request, return the proposed queue. When the user asks to register
tasks, show a concise summary in the user's language, inspect existing tasks
to avoid duplicates, and register the unambiguous items using the selected
tool's documented commands. Preserve task IDs for dependency wiring and verify
the resulting queue. Ask for the target tool if the project and request do not
identify one.

## Quality Bar

- Start task descriptions with concrete verbs.
- Keep tasks small enough to complete and verify independently.
- Make validation tasks specific about the behavior they check.
- Preserve user wording when it carries domain meaning.

## Output

Report the project, tasks drafted or added, existing tasks skipped, dependencies,
and next actionable work. Match the user's language and level of detail.
