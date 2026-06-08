---
name: survey
description: >
  Map a repository or working directory before implementation. Use when the
  user asks to survey, scan, inspect, orient, 구조 파악, 훑어보기, 작업 전
  파악, or when workstream needs a pre-implementation map of project structure,
  package manager, commands, tests, local apps, ownership boundaries, and risk
  areas. Produces concise findings and recommended next checks without making
  code changes.
---

# Survey

Build a working map before planning or editing. Read only. If the user asks for
changes, finish the survey first, then hand off to the appropriate workflow or
skill.

## Goals

- Identify project shape, ownership boundaries, and likely files for the task.
- Find package manager, runtime, scripts, test commands, lint/typecheck commands, and dev server commands.
- Detect local conventions: framework, module layout, aliases, generated files, fixtures, test style.
- Surface risk areas: migrations, env files, generated artifacts, global config, broad shared modules.
- Return concise findings that help planning and validation.

## Workflow

1. Confirm target
   - Use cwd by default.
   - If user names a path, inspect that path.
   - If target is ambiguous, ask one concise question.

2. Read fast
   - Start with `pwd`.
   - Check whether target is in a Git repo before running Git-only commands.
   - In Git repos, run `git status --short`, `rg --files`, and inspect top-level manifests.
   - Outside Git repos, skip Git commands and use filesystem listing plus visible manifests.
   - Prefer `rg` over slow search tools.
   - Inspect package/config files before source files.
   - Read only task-relevant source after structure is known.

3. Map commands
   - Identify install, build, lint, typecheck, test, e2e, dev, format commands.
   - Prefer repo scripts over invented commands.
   - Note required env or services only when visible from repo files.

4. Map implementation surface
   - List likely source files, tests, fixtures, generated files, and public contracts.
   - Name direct dependencies that may be affected.
   - Separate confirmed facts from inferred guesses.

5. Map validation
   - Recommend the smallest meaningful checks first.
   - Add broader checks for shared or risky changes.
   - If no test path is obvious, say so and suggest inspection/manual check.

## Output

Keep output short:

```txt
Survey:
- Shape: ...
- Commands: ...
- Relevant paths: ...
- Risks: ...
- Suggested checks: ...
```

For `workstream`, feed these findings into the plan. Do not create tasks from
survey findings unless the user asks or the workstream queue phase starts.

## Guardrails

- Do not modify files.
- Do not install dependencies.
- Do not start long-running servers unless user asks.
- Do not treat inferred commands as verified until run.
- Do not use broad destructive commands.
