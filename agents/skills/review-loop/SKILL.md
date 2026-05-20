---
name: review-loop
description: >
  Unified scoped code review + parent-owned fix loop. Use for /review-loop,
  review until clean, code review with fixes, or modes: web, server, database, node.
compatibility: Requires Git worktree for default scope. Designed for Codex read-only subagents.
---

# Review Loop

Modes:
- `web`: browser/client, SSR/rendering, hydration, client state, assets
- `server`: HTTP/API, middleware, auth/session, webhooks, jobs, queues, integrations
- `database`: schema, migrations, ORM/models, SQL, transactions, indexes, constraints, fixtures/backfills
- `node`: JS/TS runtime, package scripts, CLIs, workers, libs, build tooling, modules/deps/process/fs

Aliases:
- web: `frontend client browser ui ssr rendering hydration assets`
- server: `api backend http middleware auth session webhook jobs queue integration`
- database: `db sql orm migration schema transaction index constraint repository data-access`
- node: `js ts typescript javascript nodejs package npm pnpm yarn cli worker build esm cjs`

Normalize aliases. Examples: `/review-loop web server`, `/review-loop frontend api`, `/review-loop backend db`, `/review-loop ts package`. No mode: infer from request/files; unclear => ask one mode question.

## Contract

Parent owns scope, modes, axes, findings, fixes, decisions, validation, oscillation, subagents. Final = canonical review record unless user asks otherwise.

## Gates

1. Scope explicit wins. No scope = current Git uncommitted only. Never whole repo by default.
2. Stop+ask if no Git repo, empty default scope, unreadable/unclear target, unclear modes.
3. Review-only only if user says review-only/audit/report/summary/no edits/findings. Else review-and-fix.
4. First pass: read-only axis subagents if available; else ask serial fallback approval.
5. Budget = live thread. Run axes in waves; do not drop axes.
6. Subagents direct children only, no recursion, read-only.
7. Parent aggregates, edits, tests, validates, final.
8. Loop until no actionable in-scope findings or user decision blocks.
9. Oscillation: A->B->A serious. Same issue twice => stop/blocker.
10. Close subagents before final CI/end; copy unresolved findings first.
11. Final CI after cleanup. In-scope fail => fix + affected-axis re-review + CI again.
12. DB guard: no prod/staging migrations, destructive resets, seed truncation, backfills, data repair, live provider ops, shared-env writes without explicit approval.

## Scope Discovery

```text
git rev-parse --show-toplevel
git diff --name-only --cached
git diff --name-only
git ls-files --others --exclude-standard
git diff --cached -- <path>
git diff -- <path>
```

Steps: verify root; verify explicit scope readable; default enumerate staged/unstaged/untracked/deleted diffs; empty default ask+stop; classify paths by modes; read only direct deps/contracts/tests/config/generated sources needed to confirm findings.

## Axes

Use selected modes only.

Web:
1. Client security, sensitive data, storage
2. SSR/render/hydration/assets/cache/redirects
3. Interaction, async state, double submit, stale responses
4. UI/API contract drift, generated clients, validation assumptions

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

Custom axes: preserve. Too many axes => waves. Do not merge unless asked.

## Subagent Prompt

Each axis gets same scope + one axis. Read-only. Adjacent direct contracts OK only to confirm concrete finding. Return only file refs, evidence, severity, likely root cause, suggested validation, status: `actionable|suspected|out-of-scope|user-decision`. Clean: “no actionable findings”. No writes/validation.

## Fix Loop

1. Dedup by root cause/files/fix; keep mode+axis tags.
2. Queue user decisions.
3. If not review-only, fix clear local in-scope issues.
4. Prove suspected security/race/runtime/cache/webhook/data/transaction/migration/query/integration bugs before edit with smallest reliable repro/test/dry-run/schema/query/transaction/replay/mock/import check.
5. No broad redesign, public contract reshape, package/routing/auth/session/deploy/DB engine/ORM migration/destructive repair/product change without approval.
6. After fixes: re-review touched files/contracts; run targeted validation.
7. Affected-axis re-review after fixes. Full selected-axis pass before final cleanup if relevant files changed since last pass.
8. Check oscillation before touching same issue again.

## Validation

Discover repo commands. Prefer targeted tests, touched-package typecheck/lint, route/API/middleware/webhook/integration mocks, browser/runtime tests, schema/generated-client checks, migration dry-run, SQL lint/parse, local/test DB, query/transaction tests, CLI/import checks.

Final: project CI or nearest local equivalent for scope. If format/lint-fix exists and code changed, run cleanup, re-review changed files, rerun validation.

Never prod-affecting/destructive/deploy/dependency update/secret rotation/live provider/destructive migration/seed reset/backfill/shared-env DB write without approval.

## Final

Include scope, modes, review-only vs fix, axis execution, final status, axis summary, fixed issues, deferred decisions, validation, remaining risks. No code changes? say so. No decisions? “No remaining user decisions.” Validation blocked? exact missing service/credential/dependency/env.
