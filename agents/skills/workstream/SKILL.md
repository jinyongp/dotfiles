---
name: workstream
description: >
  Orchestrate implementation work from intake to closeout. Use when the user
  asks to run a task through a consistent work flow, plan first, turn a plan
  into Taskwarrior tasks, execute task-by-task, verify, review, and optionally
  prepare commits. Trigger phrases include workstream, 작업흐름, 작업 흐름,
  기획부터 태스크화, 계획 세우고 구현, and 태스크화해서 구현.
---

# Workstream

Run implementation work as one coherent flow. This skill coordinates existing
skills; it does not replace them.

## Skill Chain

- `caveman`: preserve active terse style unless user says `stop caveman` or `normal mode`.
- `survey`: load before planning when repository structure, commands, or validation paths are not already known.
- `planning`: load for intake, scope, assumptions, tradeoffs, success criteria, plan docs.
- `queue`: load to convert plan work items into a Taskwarrior task draft.
- `taskwarrior`: load before creating, reading, modifying, or completing tasks.
- `verify`: load before choosing or running validation checks, and before marking implementation tasks done.
- `review-loop`: load after all implementation work and validation for every workstream, before closeout.
- `close`: load for closeout before final status or commit preparation.
- `git-commit`: load only when user asks to stage, commit, split commits, or draft commit text.

## Goal Tool

If an agent goal tool is available, create a goal before starting execution work
in a workstream. Do this even when the user did not explicitly ask for
goal-backed work. Skip only when the request is plan-only, the tool is
unavailable, the user explicitly opts out of goal tracking, or an unfinished
goal already exists and must be continued or resolved first.

Plan-only workstream requests must not create a goal unless the user explicitly
asks for goal-backed planning. Plan-only triggers include `workstream 계획`,
`workstream plan`, and `작업흐름 계획` when the user does not ask to queue,
implement, execute, verify, review, or close the work.

Goal-backed work is especially important for triggers such as:

- `workstream goal`
- `goal로 관리`
- `목표 잡고 진행`
- `budget <n>` or explicit token budget

When a goal exists, align the objective with the plan `Goal`, then close it only
when the workstream is actually complete or truly blocked.

When creating the goal objective, include context-preservation rules needed to
resume correctly after compaction or interruption. If `caveman` is active, load
the `caveman` skill before creating the goal, then copy the absolute skill path
and actual rules into the goal objective. Do not write only `caveman-style`,
`terse`, or another label; labels are not enough after resume or context
compaction.

Use this literal style payload when `caveman` is active:

```text
Response style: caveman active until the user says `stop caveman` or
`normal mode`.
- Skill path: `/Users/jinyongp/.dotfiles/agents/skills/caveman/SKILL.md`.
- On resume or compaction, read the skill path before the first normal response
  and keep following it.
- Apply this to assistant conversation, status updates, summaries, and
  explanations.
- Do not merely mention the style; use it in the actual answer.
- Drop filler, pleasantries, hedging, prefaces, repeated context, and style
  explanations unless directly asked.
- Korean: casual, terse, no honorific or polite endings; avoid `-습니다`,
  `-합니다`, `-요`; prefer noun endings like `추가`, `연결`, `적용`, `확인`,
  `수정`.
- Prefer 1-4 short lines when no technical detail is required.
- Do not apply caveman style to deliverable prose such as copywriting, docs, UI
  text, commit/PR text, changelogs, or generated artifacts unless explicitly
  requested.
- Keep code, commands, filenames, errors, security, and exact workstream status
  clear and exact.
```

Also include these workstream continuity rules:

- Continue from the newest user request and current plan/task state; do not
  restart from scratch after resume or context compaction.
- Preserve active constraints, assumptions, non-goals, validation expectations,
  and unresolved decisions from the plan.
- Protect user work: do not revert unrelated changes, and do not commit unless
  the user asked for commit work.
- Keep the workstream open until `close` confirms complete or truly blocked.

## Flow

1. Intake
   - Clarify goal, scope, non-goals, constraints, success criteria, validation.
   - If the request is plan-only, do not create a goal unless the user explicitly asks for goal-backed planning.
   - If execution work will start and a goal tool is available, create the goal before further work unless the user opted out or an unfinished goal already exists.
   - Run `survey` first when codebase shape, commands, or relevant paths are unknown.
   - Ask only for material unknowns. Make conservative assumptions for routine details.
   - If ambiguity affects behavior, restate the decision before planning.

2. Plan
   - When the user asks for `workstream` planning, create or update a plan doc by default.
   - Do not satisfy `workstream 계획`, `workstream plan`, or `작업흐름 계획` with conversation-only bullets unless the user says `대화로만`, `문서 쓰지 말고`, or equivalent.
   - Prefer an existing repo convention such as `docs/`, `plans/`, or `docs/exec-plans/`.
   - If no convention exists, use `.agents/work/<slug>/plan.md`.
   - If creating repo-local agent files may be unwanted, state the path first.
   - In `Constraints`, record context-preservation rules that must survive resume, including active style mode, user constraints, commit policy, validation policy, and any "do not touch" paths.
   - Write settled facts only. Keep unresolved decisions in conversation.
   - After writing the doc, summarize path + main work items briefly in conversation.

3. Queue
   - Use `queue` to extract actionable `Work Items` from the plan.
   - Use `taskwarrior` for all workstream task reads, creation, updates, and completion.
   - Add the Taskwarrior queue before implementation starts; do not substitute Codex plan tracking to avoid a confirmation pause.
   - Workstream task creation, annotation, dependency wiring, start/stop, and completion are pre-approved non-destructive repo-local mutations. Proceed without asking for confirmation when scope is unambiguous.
   - Show a concise user-language queue summary before mutation, then execute.
   - Use `project:<slug>` plus tags such as `+survey`, `+implementation`, `+validation`, `+review`, `+risk`.
   - Use Taskwarrior `depends:` for strict task order such as survey -> implementation -> validation -> review.
   - Prefer one task per independently verifiable work item.
   - Workstream queues are repo-local. If no project-local Taskwarrior store is found, set one up automatically and ensure `.taskwarrior/` is ignored; do not write global Taskwarrior tasks.

4. Execute
   - Work from the ready task queue, normally `task project:<slug> +READY next`.
   - Refresh reports before using numeric IDs. Prefer UUIDs for multi-step updates.
   - Start or annotate tasks when useful. Mark done only after relevant validation passes.
   - Keep edits scoped to the active task and plan.

5. Verify
   - Use `verify` to map every work item, behavior, and material risk to a check.
   - Run targeted checks first, then broader checks for shared or risky changes.
   - If validation is skipped or blocked, keep affected tasks pending or blocked unless the user explicitly accepts deferral.

6. Review
   - Run `review-loop` after all work items are implemented and relevant validation has run.
   - Treat review-loop as required for every workstream before closeout, not only broad or risky changes.
   - Treat review-loop as the full loop workflow, not a single review pass. Do
     not move to closeout after "found issue -> fixed issue -> validation
     passed" unless review-loop has completed its affected-axis re-review and
     recorded no remaining actionable in-scope findings.
   - If review-loop fixes anything, rerun the affected validation and re-enter
     review-loop from the latest changed files/contracts until it returns a
     clean final review record or a real user-decision/blocker remains.
   - The review task is done only when the final review-loop result includes
     scope, modes/axes covered, cycle count or equivalent loop ledger, validation
     status, and "no actionable findings" or explicit blocked/deferred items.
   - Fix findings in scope. Convert deferred follow-ups into Taskwarrior tasks only with clear scope.

7. Close
   - Use `close` only after review-loop is clean or explicitly blocked.
   - Check plan/task status, validation results, review-loop state, git status, and residual risk.
   - If a workstream goal exists, update it only after `close` confirms complete or blocked status.
   - Do not commit unless user asked. If asked, use `git-commit`.

## Plan Format

```md
# <Title> Plan

## Goal

## Scope

## Non-goals

## Constraints

## Assumptions

## Work Items
- [ ] ...

## Validation
- [ ] ...

## Risks
```

## Task Draft

Use `queue` for the authoritative registration format. Keep raw Taskwarrior
commands and dependency lines internal unless the user asks or mutation risk
requires explicit inspection. For workstream execution, Taskwarrior queue
registration is pre-approved; add tasks before implementation and proceed
without a confirmation gate.

## Triggers

Use this skill for:

- `workstream으로 진행`
- `workstream 계획`
- `workstream으로 계획 세워줘`
- `작업흐름으로 진행`
- `작업흐름 계획`
- `기획부터 태스크화해서 구현`
- `계획 세우고 taskwarrior에 넣어서 진행`
- `작업 계획 문서 만들고 수행`

Do not use for tiny one-shot edits unless the user explicitly asks for workstream.
