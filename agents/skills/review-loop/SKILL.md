---
name: review-loop
description: >
  Unified scoped code review + parent-owned fix loop. Use for /review-loop,
  review until clean, code review with fixes, or modes: web, server, database, node.
compatibility: Requires Git worktree for default scope. Designed for Codex read-only subagents.
---

# Review Loop

Modes:
- `web`: browser/client, SSR/rendering, hydration, client state, assets, UI/UX
- `server`: HTTP/API, middleware, auth/session, webhooks, jobs, queues, integrations
- `database`: schema, migrations, ORM/models, SQL, transactions, indexes, constraints, fixtures/backfills
- `node`: JS/TS runtime, package scripts, CLIs, workers, libs, build tooling, modules/deps/process/fs

Aliases:
- web: `frontend client browser ui ux design ssr rendering hydration assets`
- server: `api backend http middleware auth session webhook jobs queue integration`
- database: `db sql orm migration schema transaction index constraint repository data-access`
- node: `js ts typescript javascript nodejs package npm pnpm yarn cli worker build esm cjs`

Normalize aliases. Examples: `/review-loop web server`, `/review-loop frontend api`, `/review-loop backend db`, `/review-loop ts package`. No explicit area/mode/axis: inspect requested scope first, then infer review area, modes, risk axes, and agent plan from changed code plus direct contracts. Ask only when the target or material coverage is genuinely ambiguous.

Infer review plan from paths/content:
- web: `component|page|layout|style|css|client|browser|hydration|asset|screen`
- server: `route|api|middleware|controller|auth|session|webhook|job|queue`
- database: `schema|migration|sql|prisma|drizzle|typeorm|model|repository`
- node: `package.json|tsconfig|script|cli|worker|build|esm|cjs|fs|process`

## Contract

Parent owns scope, modes, axes, findings, fixes, decisions, validation, oscillation, subagents. Final = canonical review record unless user asks otherwise.

## Gates

1. Scope explicit wins. No scope = current Git uncommitted only. Never whole repo by default.
2. Stop+ask if no Git repo, empty default scope, unreadable/unclear target, or review plan still unclear after scope inference.
3. User says plain `review`/`code review` only => review-only. User says `/review-loop`, until clean, fix, or review-and-fix => review-and-fix.
4. Before subagents: derive a review plan from scope. Select only material modes/axes and choose useful agent count from scope size/risk/independent concerns. `config.toml` agent count is capacity, not quota; never spawn fixed-count or empty-work agents just because slots exist.
5. First pass: planned read-only subagents if available; else ask serial fallback approval.
6. Budget = live thread. Run planned axes in waves; do not drop selected axes.
7. Subagents direct children only, no recursion, read-only.
8. Parent aggregates, edits, tests, validates, final.
9. Loop until no actionable in-scope findings or user decision blocks.
10. Oscillation: A->B->A serious. Same issue twice => stop/blocker.
11. Close subagents before final CI/end; copy unresolved findings first.
12. Final CI after cleanup. In-scope fail => fix + affected-axis re-review + CI again.
13. DB guard: no prod/staging migrations, destructive resets, seed truncation, backfills, data repair, live provider ops, shared-env writes without explicit approval.

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
git diff --cached -- <path>
git diff -- <path>
```

Steps: verify root; verify explicit scope readable; default enumerate staged/unstaged/untracked/deleted diffs; include generated/lockfile only with related source; exclude vendored/dist unless changed by request; empty default ask+stop; derive review area (feature/module/file set), modes, axes, and agent plan from changed paths/content plus direct deps/contracts/tests/config/generated sources; read only context needed to confirm findings.

## Axes

Use selected modes only. Do not run every listed axis merely because a mode matched. Select axes whose failure modes are plausible from changed code and direct contracts; include high-risk axes when scope touches auth, permissions, persistence, migrations, provider I/O, process/env, routing, or user-facing workflows.

For any selected mode, read `references/code-quality.md` when scope adds or changes authored helpers, composables, function signatures, normalization/resolve layers, duplicate domain helpers, or public-ish APIs.

Web:
1. Client security, sensitive data, storage
2. SSR/render/hydration/assets/cache/redirects
3. Interaction, async state, double submit, stale responses
4. UI/API contract drift, generated clients, validation assumptions
5. UI/UX fluency, information hierarchy, raw data rendering, action clarity

For Web UI/UX fluency review, read `references/ui-ux.md` when scope includes user-facing screens, components, cards, tables, dashboards, order/admin views, forms, status/action surfaces, or data-heavy UI.

Server:
1. Security, authz, tenancy, permissions, sensitive data
2. API contract, request validation, response semantics, versioning
3. Routing, middleware, sessions, cookies, CSRF, CORS, headers, proxy trust
4. Webhooks/jobs/queues/retries/idempotency/provider I/O
5. Errors, observability, shutdown, health/readiness

Database:
1. Schema/migrations/generated models/compatibility
2. Constraints/indexes/uniqueness/FK/tenant isolation
3. Queries/filters/pagination/raw SQL/N+1/plans
4. Transactions/consistency/idempotency/retry races
5. Seeds/fixtures/backfills/generated-client drift

Node:
1. Runtime/data shape/nullability/control flow
2. Async/promises/event-loop/timers/cancel
3. Modules/package boundaries/exports/imports/ESM/CJS/build output
4. Dependency/version/package scripts
5. Process/env/fs/path/OS/child process
6. Perf/memory/stream/backpressure/cleanup
7. Tests/fixtures/mocks/determinism/typecheck/build

Custom axes: preserve. Too many axes => waves. Small adjacent axes may share one read-only subagent; high-risk or broad independent axes get their own subagent. Agent count = useful independent review threads for the selected axes, bounded by available capacity, not fixed by config.

## Subagent Prompt

Each review assignment gets same scope + selected mode/axis set. Prefer one focused axis per subagent when risk is high; combine tightly related low-risk axes when that improves signal. Also pass relevant known context: user decisions, explicit non-goals, allowed/forbidden approaches, legacy/compat policy, product constraints, validation constraints, repo conventions, prior accepted risks. Do not let subagents flag issues that contradict accepted constraints.

Read-only. Adjacent direct contracts OK only to confirm concrete finding. No writes/validation.

Finding format:

```text
path:line | P0-P3 | mode/axis | status | issue | fix | validation
```

Status: `actionable|suspected|out-of-scope|user-decision`. Clean: `no actionable findings`. Include evidence, not prose.

## Fix Loop

1. Dedup by root cause/files/fix; keep mode+axis tags.
2. Queue user decisions.
3. If not review-only, fix clear local in-scope issues.
4. Prove suspected security/race/runtime/cache/webhook/data/transaction/migration/query/integration bugs before edit with smallest reliable repro/test/dry-run/schema/query/transaction/replay/mock/import check.
5. No broad redesign, public contract reshape, package/routing/auth/session/deploy/DB engine/ORM migration/destructive repair/product change without approval.
6. Do not “fix” by weakening tests, changing expected behavior without approval, adding speculative refactor, dependency upgrade, legacy path, or compatibility shim that violates stated direction.
7. After fixes: re-review touched files/contracts; run targeted validation.
8. Affected-axis re-review after fixes. Full selected-axis pass before final cleanup if relevant files changed since last pass.
9. Check oscillation before touching same issue again. Same root cause after 2 fix attempts => stop+ask. Product decision required => defer, don't guess. Validation unavailable after workaround => stop, report risk.

## Validation

Discover repo commands. Prefer targeted tests, touched-package typecheck/lint, route/API/middleware/webhook/integration mocks, browser/runtime tests, schema/generated-client checks, migration dry-run, SQL lint/parse, local/test DB, query/transaction tests, CLI/import checks.

Final: project CI or nearest local equivalent for scope. If format/lint-fix exists and code changed, run cleanup, re-review changed files, rerun validation.

Never prod-affecting/destructive/deploy/dependency update/secret rotation/live provider/destructive migration/seed reset/backfill/shared-env DB write without approval.

## Final

Include scope, modes, review-only vs fix, axis execution, final status, axis summary, fixed issues, deferred decisions, validation, remaining risks. No code changes? say so. No decisions? “No remaining user decisions.” Validation blocked? exact missing service/credential/dependency/env.
