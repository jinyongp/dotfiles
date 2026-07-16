---
name: review-loop
description: >
  Unified scoped code review + parent-owned fix loop. Use for /review-loop,
  review until clean, code review with fixes, or modes: web, server, database,
  node, planning.
compatibility: Requires Git worktree for default scope. Designed for Codex read-only subagents.
---

# Review Loop

Trigger semantics:
- `/review-loop`, `review until clean`, `review-and-fix`, or `code review with fixes` means the user is requesting the review-loop workflow, including read-only subagents when the inferred scope/risk is broad enough to benefit.
- When `review-loop` is reached from `workstream`, carry forward
  `workstream`'s nested review delegation authorization: the original
  workstream request explicitly authorizes subagents, delegation, and parallel
  agent work for this phase whenever parent judgment says they improve scoped
  review coverage.
- Plain `review` or `code review` means review-only: report findings, do not fix unless separately requested. It does not disable subagents. Use read-only subagents whenever parent judgment says parallel review improves coverage, even if the user did not mention subagents, delegation, or parallel review.
- Do not ask the user to restate "use subagents" before delegating read-only review. Derive the needed agent count from scope/risk/contracts.

Modes:
- `web`: browser/client, SSR/rendering, hydration, client state, assets, UI/UX
- `server`: HTTP/API, middleware, auth/session, webhooks, jobs, queues, integrations
- `database`: schema, migrations, ORM/models, SQL, transactions, indexes, constraints, fixtures/backfills
- `node`: JS/TS runtime, package scripts, CLIs, workers, libs, build tooling, modules/deps/process/fs
- `planning`: plans, specs, ADRs, RFCs, requirements, design docs

Aliases:
- web: `frontend client browser ui ux design ssr rendering hydration assets`
- server: `api backend http middleware auth session webhook jobs queue integration`
- database: `db sql orm migration schema transaction index constraint repository data-access`
- node: `js ts typescript javascript nodejs package npm pnpm yarn cli worker build esm cjs`
- planning: `plan planning docs document design-doc spec proposal adr rfc requirements roadmap task-list implementation-plan`

Normalize aliases. Examples: `/review-loop web server`, `/review-loop frontend api`, `/review-loop backend db`, `/review-loop ts package`, `/review-loop planning docs/checkout-plan.md`. No explicit area/mode/axis: inspect requested scope first, then infer review area, modes, risk axes, and agent plan from changed code plus direct contracts. Ask only when the target or material coverage is genuinely ambiguous.

Infer review plan from paths/content:
- web: `component|page|layout|style|css|client|browser|hydration|asset|screen`
- server: `route|api|middleware|controller|auth|session|webhook|job|queue`
- database: `schema|migration|sql|prisma|drizzle|typeorm|model|repository`
- node: `package.json|tsconfig|script|cli|worker|build|esm|cjs|fs|process`
- planning: `plan|planning|proposal|design-doc|design_doc|adr|rfc|spec|requirements|roadmap|milestone|migration-plan|implementation-plan|docs/.+\\.md|\\.md$`

## Contract

Goal: exhaustively review the given scope and its direct contracts, fix in-scope actionable issues, then repeat review/validation until no in-scope actionable findings remain or a user decision blocks progress.

Parent owns scope, coverage, modes, axes, findings, fixes, decisions, validation, oscillation, subagents. Final = canonical review record unless user asks otherwise.

Do not describe any in-progress cycle, local-only validation, pending subagent
result, or candidate clean state with terminal wording that implies the loop is
done. During the loop, use precise non-terminal wording such as "cycle
validation", "local validation", "affected-axis re-review", "subagent result
pending", "candidate clean pending subagent/CI", or "cycle closeout". Reserve
terminal wording such as "final", "done", "complete", or "clean" for states
where all selected axes and subagents are closed, no actionable in-scope
findings remain, and final validation is complete or explicitly blocked.

## Continuity

If the agent has persistent goal/progress tools, use them as a review-loop continuity guard. At workflow start, create or refresh one active goal whose objective is to finish the scoped review-loop only when the scoped coverage plan is clean or blocked by a user decision. At the end of every full cycle, update/refresh the goal with the current cycle number, completed axes, unresolved findings, fixes applied, validation status, and next cycle entry point. If the available goal API only supports terminal status, re-read/refresh the goal each cycle and keep the cycle ledger in the thread.

Preserve active response-style context for the whole review-loop. If `caveman`
is active, load the `caveman` skill before creating the goal, then copy the
absolute skill path and actual rules into the goal objective or cycle ledger. Do
not write only `caveman-style`, `terse`, or another label; labels are not enough
after resume or context compaction.

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
- Keep code, commands, filenames, errors, security, and exact review findings
  clear and exact.
```

Never mark the goal complete until the whole scoped coverage plan has no actionable in-scope findings and final validation is complete or explicitly blocked. Mark blocked only for a real user decision, repeated oscillation, or an unavailable required validation/service that prevents further progress. Context length, subagent completion, or a single clean axis is not a stop condition.

## Gates

1. Scope explicit wins. No scope = current session changes only: files/behaviors
   created, edited, deleted, or intentionally generated by the current assistant
   session, plus direct contracts needed to judge those changes. Never review
   all Git uncommitted changes by default.
2. Stop+ask if no Git repo, no reliable current-session changed scope,
   unreadable/unclear target, or review plan still unclear after scope
   inference. Do not fall back to all uncommitted changes unless the user
   explicitly asks for that scope.
3. User says plain `review`/`code review` only => review-only, but still use
   read-only subagents when scope/risk justifies parallel coverage. User says
   `/review-loop`, until clean, fix, or review-and-fix => review-and-fix.
4. Before subagents: derive a coverage plan from scope. Cover every in-scope changed file/behavior and direct contract needed to judge it. Select material modes/axes for that coverage and choose useful agent count from scope size/risk/independent concerns. `config.toml` agent count is capacity, not quota; never spawn fixed-count or empty-work agents just because slots exist.
5. First pass: planned read-only subagents if available and authorized by the
   direct request or a parent workflow such as `workstream`; else ask serial
   fallback approval.
6. Budget = live thread. Run planned axes in waves; do not drop selected axes.
7. Continuity guard: if goal/progress tools exist, refresh the active goal or cycle ledger once per cycle before deciding whether to continue, complete, or block.
8. Subagents direct children only, no recursion, read-only.
9. Parent aggregates, edits, tests, validates, final.
10. Loop until the whole scoped coverage plan has no actionable in-scope findings or user decision blocks.
11. Oscillation: A->B->A serious. Same issue twice => stop/blocker.
12. Close subagents before final CI/end; copy unresolved findings first.
13. Final CI after cleanup. In-scope fail => fix + affected-axis re-review + CI again.
14. DB guard: no prod/staging migrations, destructive resets, seed truncation, backfills, data repair, live provider ops, shared-env writes without explicit approval.

Severity:
- P0: exploit/data loss/prod outage
- P1: likely bug/regression/security/auth/data-integrity issue
- P2: edge-case bug, missing validation/test causing real risk
- P3: maintainability/nit only if correctness/operation affected

## Scope Discovery

```text
git rev-parse --show-toplevel
git diff --name-only --cached
git diff --name-only
git ls-files --others --exclude-standard
git diff --cached -- <session-path>
git diff -- <session-path>
git diff --no-index -- /dev/null <untracked-path>
```

Steps: verify root; verify explicit scope readable. For default scope, first
build the current-session changed set from this thread's tool history, active
goal/cycle ledger, workstream plan/task notes, and files the assistant reports
as edited/created/deleted/generated. Use Git commands to inspect diffs for only
those paths and to detect whether each path is staged, unstaged, untracked, or
deleted. Do not add unrelated uncommitted files merely because Git reports them.
Include generated/lockfile only when generated by this session or required by a
session-touched source change. Exclude vendored/dist unless changed by request.
Empty or unreliable default session scope => ask+stop. Derive review area
(feature/module/file set), modes, axes, coverage map, and agent plan from
session-changed paths/content plus direct deps/contracts/tests/config/generated
sources; read enough context to cover every in-scope behavior and confirm
findings.

## Axes

Use selected modes only. Do not run every listed axis merely because a mode matched, but do not leave any in-scope changed behavior unreviewed. Select axes whose failure modes are plausible from changed code and direct contracts; include high-risk axes when scope touches auth, permissions, persistence, migrations, provider I/O, process/env, routing, or user-facing workflows.

Parent reads and passes selected mode references:
- web: `references/web.md`
- server: `references/server.md`
- database: `references/database.md`
- node: `references/node.md`
- planning: `references/planning.md`

For any selected mode, read `references/code-quality.md` when scope adds or changes authored helpers, composables, function signatures, normalization/resolve layers, duplicate domain helpers, or public-ish APIs.
For Web UI/UX fluency review, read `references/ui-ux.md` when scope includes user-facing screens, components, cards, tables, dashboards, order/admin views, forms, status/action surfaces, or data-heavy UI.
For Planning review, read `../planning/SKILL.md` before `references/planning.md`. Run alone for docs-only scope or with code modes when plans describe changed behavior.

Custom axes: preserve. Too many axes => waves. Small adjacent axes may share one read-only subagent; high-risk or broad independent axes get their own subagent. Agent count = useful independent review threads for the selected axes, bounded by available capacity, not fixed by config.

## Subagent Prompt

Each review assignment gets same scope + selected mode/axis set. Prefer one
focused axis per subagent when risk is high; combine tightly related low-risk
axes when that improves signal. Pass only relevant active context: current user
decisions expressed as positive state, active non-goals, effective allowed
approaches, durable prohibitions with scope and reason, unexpired task-local
constraints with scope and expiry, legacy/compat policy, product constraints,
validation constraints, repo conventions, and prior accepted risks. Exclude
rejected proposals, superseded alternatives, and expired constraints. Do not
let subagents flag issues that contradict accepted constraints.

Also pass selected mode reference content and required companion skill rules loaded by parent.
If `caveman` is active, every subagent prompt must include the full literal
style payload from `Continuity`, not only the skill name or a summary. Tell the
subagent to follow that payload for its own status, summary, and finding output
while keeping review findings exact. This preserves response style across
parallel read-only review and after subagent context compaction.

Read-only. Adjacent direct contracts OK only to confirm concrete finding. No writes/validation.

Finding format:

```text
path:line | P0-P3 | mode/axis | status | issue | fix | validation
```

Status: `actionable|suspected|out-of-scope|user-decision`. Clean: `no actionable findings`. Include evidence, not prose.

## Fix Loop

1. Start each cycle from the latest coverage map plus goal/cycle ledger when available.
2. Dedup by root cause/files/fix; keep mode+axis tags.
3. Queue user decisions.
4. If not review-only, fix clear local in-scope issues.
5. Prove suspected security/race/runtime/cache/webhook/data/transaction/migration/query/integration bugs before edit with smallest reliable repro/test/dry-run/schema/query/transaction/replay/mock/import check.
6. No broad redesign, public contract reshape, package/routing/auth/session/deploy/DB engine/ORM migration/destructive repair/product change without approval.
7. Do not “fix” by weakening tests, changing expected behavior without approval, adding speculative refactor, dependency upgrade, legacy path, or compatibility shim that violates stated direction.
8. Test cleanup is allowed when a test asserts volatile implementation details that are not behavior contracts. Remove or rewrite assertions against Tailwind/static class strings, incidental DOM structure, generated ids, ordering without semantic meaning, exact copy not owned by the feature, timestamps, random values, or other frequently changing values unless the test is explicitly about that style/content/serialization contract.
9. After fixes: re-review touched files/contracts; run targeted validation.
10. Affected-axis re-review after fixes. If fixes alter reviewed behavior, refresh the coverage map and repeat selected axes until the entire scope is clean.
11. End each cycle by recording completed axes, remaining findings, validation results, and next entry point in the goal/cycle ledger.
12. Check oscillation before touching same issue again. Same root cause after 2 fix attempts => stop+ask. Product decision required => defer, don't guess. Validation unavailable after workaround => stop, report risk.

## Validation

Discover repo commands. Prefer targeted tests, touched-package typecheck/lint, route/API/middleware/webhook/integration mocks, browser/runtime tests, schema/generated-client checks, migration dry-run, SQL lint/parse, local/test DB, query/transaction tests, CLI/import checks.

Final: project CI or nearest local equivalent for scope. If format/lint-fix exists and code changed, run cleanup, re-review changed files/contracts, rerun validation. Final status cannot be clean unless scoped coverage, fixes, re-review, and validation are complete or explicitly blocked.

Never prod-affecting/destructive/deploy/dependency update/secret rotation/live provider/destructive migration/seed reset/backfill/shared-env DB write without approval.

## Final

Include scope, coverage summary, modes, review-only vs fix, axis execution, final status, axis summary, fixed issues, deferred decisions, validation, remaining risks. No code changes? say so. No decisions? “No remaining user decisions.” Validation blocked? exact missing service/credential/dependency/env.
