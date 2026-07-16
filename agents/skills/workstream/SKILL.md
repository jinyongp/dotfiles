---
name: workstream
description: >
  Orchestrate implementation work from intent to closeout: clarify and specify
  behavior when needed, plan, analyze artifact coverage, queue Taskwarrior
  tasks, implement, verify, converge code with intent, review until clean, and
  optionally prepare commits. Use for workstream, 작업흐름, 작업 흐름,
  기획부터 태스크화, 계획 세우고 구현, and 태스크화해서 구현 requests.
---

# Workstream

Run implementation work as one coherent flow. This skill coordinates existing
skills; it does not replace them.

## Skill Chain

- `caveman`: preserve active terse style unless user says `stop caveman` or `normal mode`.
- `survey`: load before planning when repository structure, commands, or validation paths are not already known.
- `planning`: load for intake, specification, clarification, artifact analysis, tradeoffs, success criteria, and plan docs.
- `queue`: load to convert plan work items into a Taskwarrior task draft.
- `taskwarrior`: load before creating, reading, modifying, or completing tasks.
- `verify`: load before choosing or running validation checks, and before marking implementation tasks done.
- `review-loop`: load after all implementation work and validation for every workstream, before closeout.
- `close`: load for closeout before final status or commit preparation.
- `git-commit`: load only when user asks to stage, commit, split commits, or draft commit text.

## Operating Model

Treat intent artifacts as executable contracts, not disposable notes. Keep the
workflow proportionate: add structure only when it reduces ambiguity, rework,
or validation risk.

### Artifact Depth

Choose exactly one depth during intake and record it with rationale in the plan.
Apply precedence `High-risk > Standard > Light`; risk overrides small size.

- **Light**: use one `plan.md` only when behavior is already explicit and the
  change is local, reversible, low risk, and does not match a higher depth.
- **Standard**: add `spec.md` before `plan.md` for material user-visible
  behavior, public contracts, multiple acceptance paths, or material ambiguity.
- **High-risk**: use `spec.md` plus explicit non-functional, migration,
  rollback/recovery, security/privacy, and observability requirements for auth,
  permissions, persistent data, migrations, destructive operations, external
  integrations, or broad shared infrastructure.

Reuse an existing issue, RFC, spec, or design document as the intent source
when it is authoritative and complete enough. Do not create a duplicate spec.
When the user explicitly invokes workstream for a tiny edit, keep it light only
if all Light conditions hold; tiny auth, migration, permission, destructive, or
persistent-data work remains High-risk.

### Canonical Identity and Paths

Before resolving any artifact path or task project, read
`references/path-contract.md` completely and run
`scripts/resolve_workstream.py`. Use its JSON output exactly. Never invent a
slug, scan for repository plan conventions, choose a nearby writable directory,
or add a collision suffix.

### Intent and Traceability

Use stable IDs in newly created workstream artifacts:

- `REQ-###`: required behavior or constraint.
- `AC-###`: observable acceptance criterion; reference its `REQ-###`.
- `WI-###`: independently verifiable work item; reference covered requirements
  and acceptance criteria.
- `VAL-###`: validation check; reference the work item, acceptance criterion,
  or material risk it proves, and classify it as `task-local`, `standalone`, or
  `review`.

Preserve existing repository ID schemes instead of renumbering them. Every
requirement must have an acceptance signal, every buildable requirement must map
to work, and every work item must map to validation. Do not create work for
post-launch business outcomes that cannot be proven during implementation.

### Governance

Treat applicable `AGENTS.md`, repository rules, architecture docs, contribution
guides, security policies, and user constraints as governing sources. Extract
their relevant MUST/SHOULD rules into the plan's `Governance Check`; a separate
constitution file is optional. Stop before queueing when a MUST rule is violated
or a material exception lacks explicit rationale and user authority.

### Phase Ledger

Keep a compact phase ledger in `plan.md` with phase, status, evidence, and next
entry point. Update it after phase transitions and before interruption or
handoff. The ledger preserves workflow continuity; Taskwarrior remains
authoritative for individual task state. Never duplicate every task update into
the ledger.

## Nested Review Delegation

When the user invokes `workstream`, treat that request as also explicitly
requesting and authorizing subagents, delegation, and parallel agent work for the
nested `review-loop` phase whenever the parent agent judges they improve scoped
review coverage. This is conditional authorization, not a fixed parallelism
requirement: the parent still derives the useful agent count after
implementation, validation, scope, risk, and direct contracts are known.

Do not ask the user to repeat a separate "use subagents" request before
`review-loop` delegation inside a workstream. If the available subagent tool
still cannot be used, state the tool limitation and ask for serial fallback
approval instead of silently reducing coverage.

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

Settle the one-sentence outcome before creating a goal. Put it in the objective
as `Outcome: <one sentence>` before continuity rules; only that outcome must
match the plan `Goal`. If the user materially changes the outcome,
stop and resolve the active goal through the tool's supported workflow instead
of silently diverging. Close it only when the workstream is complete or truly
blocked.

Before creating a goal, read `references/goal-continuity.md` completely. Copy
its common rules, the applicable goal-type termination rule, and, when caveman
is active, its literal caveman payload into the objective. When caveman is
active, load that skill first. Labels such as `caveman-style` or `terse` are not
sufficient after resume or compaction.

## Flow

1. Intake
   - Settle the one-sentence Goal, then clarify scope, non-goals, constraints,
     success criteria, and validation expectations.
   - Choose light, standard, or high-risk artifact depth from evidence, not task
     size alone.
   - For plan-only work, create a settled planning goal before specification or
     planning only when the user explicitly requests goal tracking.
   - For execution work, create the settled goal before planning or
     implementation when a goal tool is available, unless the user opted out or
     an unfinished goal already exists.
   - Run `survey` first when codebase shape, commands, governing sources, or relevant paths are unknown.
   - Ask only for material unknowns. Make conservative assumptions for routine, reversible details.

2. Specify and Clarify
   - For standard/high-risk work, create or update `spec.md` beside the plan, or
     link the authoritative existing intent source.
   - Keep behavior and constraints in the spec; keep solution choices in the
     plan. Existing public-contract facts may appear in both when needed for
     precision.
   - Cover actors, primary/alternate/error/recovery flows, data lifecycle,
     boundary conditions, compatibility, and applicable non-functional needs.
   - Scan unresolved areas by impact: scope, security/privacy, data integrity,
     UX, external failure, performance/reliability, migration/rollback, and
     observability.
   - Ask one focused question at a time only when the answer materially changes
     behavior, architecture, task decomposition, or validation. Keep unresolved
     decisions in conversation and integrate each settled answer immediately.
   - Self-check that requirements are bounded, unambiguous, measurable, and
     free of contradictory placeholders before planning.

3. Plan
   - When the user asks for `workstream` planning, create or update a plan doc by default.
   - Do not satisfy `workstream 계획`, `workstream plan`, or `작업흐름 계획` with conversation-only bullets unless the user says `대화로만`, `문서 쓰지 말고`, or equivalent.
   - After Goal, depth, and intent source are settled, run the canonical resolver
     without `--init`. State its exact slug, work directory, and fixed artifact
     paths, then rerun with `--init` before writing the plan.
   - In a Git repository, ensure the root `.gitignore` contains the exact
     `/.tasks/` rule once before `--init`; use no other ignore location.
   - Accept a non-default slug only when the user explicitly provides it. The
     `.tasks/items/` root cannot be overridden. If resolution, collision, or
     write checks fail, stop; do not fall back to another path.
   - Translate intent into technical decisions, exact implementation surfaces,
     independently verifiable work items, validation, risks, and governance checks.
   - In `Constraints`, record only active context-preservation rules that must
     survive resume: active style mode, durable user constraints, unexpired
     task-local constraints, commit policy, validation policy, and current
     protected paths. Include scope and reason for durable prohibitions and
     scope plus expiry for task-local constraints.
   - Normalize preferences and selected designs into positive canonical state.
     Keep rejected proposals, superseded alternatives, and expired constraints
     out of plans, goals, ledgers, queues, subagent prompts, and handoffs unless
     an explicit audit artifact requires their history.
   - Write settled facts only. Keep unresolved decisions in conversation.
   - Do not add an `Open Decisions` section by default. If a repo template or
     explicit user request requires one, follow `planning` open-decision
     criteria and include only material unresolved decisions.
   - Initialize or refresh the phase ledger, then summarize path + main work items briefly.

4. Analyze Artifacts
   - Before queueing, perform a read-only consistency and coverage pass over the
     intent source, plan, governing rules, work items, and validation.
   - Check duplicate/conflicting requirements, vague or untestable acceptance
     criteria, governance violations, uncovered `REQ/AC`, unmapped `WI`, missing
     `VAL`, impossible ordering, file-path or terminology drift, and stale
     rejected or expired context outside an explicit audit artifact.
   - Treat governing MUST violations, contradictory intent, unresolved
     security/data/migration/public-contract decisions, and missing coverage or
     validation for baseline behavior as blockers. Other gaps may be deferred
     only with explicit user risk acceptance.
   - Report evidence and severity. Do not silently rewrite intent to make the analysis pass.
   - Correct settled artifact inconsistencies in scope, keep real decisions in
     conversation, and rerun analysis. Queue only when zero blockers remain.
     Explicit risk acceptance can defer non-blocking findings only.
   - For plan-only requests, stop here after reporting the analyzed artifacts.
     Unless the user explicitly requested goal-backed planning, do not create a
     goal; if they did, complete or block that planning goal from the analysis
     result. Never create a Taskwarrior queue, mutate code, verify an
     implementation, run review-loop, or close an execution workstream.

5. Queue
   - Use `queue` to extract actionable `Work Items` from the analyzed plan.
   - Use `taskwarrior` for all workstream task reads, creation, updates, and completion.
   - Add the Taskwarrior queue before implementation starts; do not substitute Codex plan tracking to avoid a confirmation pause.
   - Workstream task creation, annotation, dependency wiring, start/stop, and completion are pre-approved non-destructive repo-local mutations. Proceed without asking for confirmation when scope is unambiguous.
   - Show a concise user-language queue summary before mutation, then execute.
   - Preserve `WI/REQ/AC` source IDs in task descriptions or annotations. Include
     exact paths and validation IDs when known.
   - Create one implementation task per `WI`. Keep task-local acceptance checks
     as mapped `VAL` evidence run before that WI is done. Create a standalone
     validation task only for broader or cross-WI checks; it depends on the
     relevant WI tasks. Map every `review` VAL to one final `+review` task
     depending on all required WI/standalone validation tasks. Keep Close
     phase-only so it can inspect a clear queue rather than depend on itself.
   - On convergence re-entry, reuse the single pending/in-progress review task,
     add dependencies on every new WI and standalone VAL, and never create a
     second review task.
   - Use the resolver's exact `project:<slug>` plus tags such as
     `+survey`, `+implementation`, `+validation`, `+review`, `+risk`.
   - Use Taskwarrior `depends:` for strict task order. Mark work parallel-safe
     only when it touches different files/resources and has no incomplete dependency.
   - Prefer one task per independently verifiable work item; do not create tasks
     for headings, open decisions, or non-buildable outcome metrics.
   - Queues are repo-local. If no project-local task store is found, set one up
     under `.tasks/` automatically and ensure that single root is ignored; do
     not write global tasks or create another state root.

6. Execute
   - Work from the ready task queue using the resolver's exact project, normally
     `task project:<slug> +READY next`.
   - Refresh reports before using numeric IDs. Prefer UUIDs for multi-step updates.
   - Start or annotate tasks when useful. Mark a WI task done after its mapped
     task-local acceptance checks pass. Never wait on a standalone validation
     task that depends on that WI.
   - Respect dependencies and file conflicts. Keep edits scoped to the active
     task, intent, and plan.

7. Verify
   - Use `verify` to map every work item, acceptance criterion, and material risk to a check.
   - Treat tests and relevant validation as required by risk and behavior, even
     when the original request does not explicitly ask for tests.
   - Run targeted checks first, then broader checks for shared or risky changes.
   - A failed or unavailable task-local VAL keeps its WI pending or blocked and
     cannot be deferred as complete. A failed standalone VAL stays pending and
     becomes corrective convergence work; during focused Queue re-entry, add
     dependencies from that failed VAL task to its corrective WI and any new
     prerequisite VAL so `+READY` selects the repair first. An
     unavailable/skipped standalone VAL stays pending
     unless the user explicitly accepts the risk; then annotate it with the
     reason and acceptance, mark that validation task done, and preserve the gap
     in the ledger and closeout.
   - Write the canonical validation evidence to the resolver's `validation.md`.
     Record its path in the phase ledger. Do not reopen a completed WI to
     mirror standalone status unless evidence invalidates its task-local
     acceptance; use convergence for corrective work.

8. Converge
   - After implementation and relevant validation, compare current code and
     observable behavior against `REQ/AC`, plan decisions, governing MUST rules,
     and completed Taskwarrior work.
   - Bound inspection to current-workstream changes, planned implementation
     surfaces, and direct contracts. Do not classify unrelated pre-existing
     behavior as unrequested work.
   - Classify evidence-backed gaps as `missing`, `partial`, `contradicts`, or
     `unrequested`. Report unrequested behavior; never delete it automatically.
   - If actionable gaps exist, append new stable `WI/VAL` entries without
     rewriting, renumbering, or reopening completed history to hide the gap.
     Re-enter a focused `Analyze Artifacts -> Queue` pass before registering the
     new repo-local tasks.
   - Continue `Execute -> Verify -> Converge` after the focused analysis and
     queue pass until no actionable intent gap remains. The same unresolved root
     cause after two fix attempts becomes a user decision/blocker, not an infinite loop.
   - If no gap remains, record convergence evidence in the phase ledger.

9. Review
   - Run `review-loop` after all work items are implemented and relevant validation has run.
   - Treat review-loop as required for every workstream before closeout, not only broad or risky changes.
   - Carry the `Nested Review Delegation` authorization into `review-loop` so
     parent-selected read-only subagents can be used when they improve coverage.
   - Delegate fix/re-review mechanics and final-record schema to `review-loop`.
     Mark the single review task done only when its final record has no
     actionable in-scope findings and all `review` VAL checks pass.
   - Out-of-scope findings do not block that clean in-scope result; create any
     approved follow-up under a distinct follow-up project, never the active
     workstream queue. An accepted or unresolved in-scope residual is explicitly
     blocked, not a generic deferred terminal state; keep the review task pending
     or blocked and send that state to Close.
   - If review fixes change observable behavior, contracts, or coverage, rerun
     affected validation and focused convergence, then continue `review-loop`
     before declaring the review task done.
   - Write the final canonical review record to the resolver's `review.md` and
     record its path in the phase ledger.

10. Close
   - Use `close` only after review-loop is clean or explicitly blocked.
   - Check intent satisfaction, artifact analysis, convergence, plan/task
     status, validation results, review-loop state, phase ledger, git status, and residual risk.
   - If a workstream goal exists, update it only after `close` confirms complete or blocked status.
   - Do not commit unless user asked. If asked, use `git-commit`.

## Adoption Boundaries

- Do not create or switch branches unless the user requests branch work.
- Do not require fixed human approval gates when intent is settled and the next
  action is safe; ask only for material decisions or required authority.
- Do not make tests optional merely because the request omitted the word
  `test`; choose validation from behavior and risk.
- Do not add a generic hook, preset, or plugin system to a repository merely to
  run this workflow.
- Do not let analysis replace runtime verification or let convergence replace
  code review. They answer different questions.

## Artifact Contracts

Before creating or updating workstream artifacts, read both
`references/path-contract.md` and `references/artifact-contracts.md` completely.
Use the fixed paths from the resolver and the relevant content contract.

## Task Draft

Use `queue` for the authoritative registration format. Keep raw Taskwarrior
commands and dependency lines internal unless the user asks or mutation risk
requires explicit inspection. For workstream execution, Taskwarrior queue
registration is pre-approved; add tasks before implementation and proceed
without a confirmation gate.

Do not use for tiny one-shot edits unless the user explicitly asks for workstream.
