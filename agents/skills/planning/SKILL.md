---
name: planning
description: >
  Use for plans, design, ambiguity, non-trivial implementation, scope negotiation,
  success criteria. Replaces old PLANNING.md without always-read cost.
---

# Planning

Use for plan/design/approach/tradeoffs asks, or ambiguous/non-trivial tasks.

## Ask First

- Do not silently infer key requirements.
- Ask focused questions until scope, constraints, success criteria clear.
- Branches? Name options; resolve one by one.
- Dependent decisions? Walk dependency order.
- Unknown? Say unknown; ask.
- Trivial/specified? Proceed with stated assumptions.

Do not accept unsafe/abstract/under-specified/inconsistent/conflicting decisions as-is, even if user "decided". Surface issue; suggest correction.

## Ledger

Keep unresolved items visible in conversation:

- scope
- constraints
- success criteria
- non-goals
- validation
- owner decision needed

Never move open decisions into docs as settled facts.
Open decision exists? Print in conversation with recommendation + why.
Open decisions require user review? Explain in detailed prose, not terse labels, so the user can decide from context.
User answer vague, wrong, unsafe, inconsistent, or still underspecified? Keep discussing in conversation until testable.

## Gates

- Free-text decision with scope/constraints? Restate structured meaning before acting.
- Completion signal from tool/agent/MCP? Treat as candidate; run local acceptance check.
- Before execution, restate final goal in one sentence when ambiguity was material.
- No candidate accepted by default. User choice, explicit constraint, or verified code fact required.
- If two accepted items conflict, stop and reconcile before work.

## Before Work

- State material assumptions.
- Surface behavior/maintainability/cost/security/UX tradeoffs.
- Mention simpler path.
- Push back on avoidable complexity.
- Add guardrails when chosen path needs boundaries.
- Abstract request => ask concrete scope or convert to testable criteria.
- Plan contradiction => stop; reconcile.

## Decisions

- Open decisions stay in conversation, not docs.
- Options useful? Include options + required recommendation in conversation.
- Recommendation present? Explain reasoning, tradeoffs, consequences, and selection criteria in detailed prose, because the user must inspect and decide.
- Mark optional choices optional.
- Do not let docs hide unresolved choices.
- User answer vague? Convert to testable wording and confirm.
- User answer risky? Present guardrail, default recommendation, and consequence.
- User answer wrong/inconsistent? Stop and reconcile before docs or execution.

## Docs

If user asks docs, write settled facts only: behavior, commands, constraints, current state. No undecided item as decided.
Do not add "Open Decisions", "TODO Decisions", "Questions", or recommendation sections to docs unless user explicitly asks for decision log; even then, label unresolved and mirror in conversation.

## Keep Small

Minimum steps/code. No unrequested feature, speculative config, one-off abstraction, impossible-case handling.

## Edit

Touch request scope only. Match style. Mention unrelated dead code; don't delete unless asked. Remove only code made unused by change. Every changed line traces to goal.

## Verify

Turn plan into checks. Bug: identify/repro, fix root, validate regression. Validation change: valid + invalid. Refactor: preserve before/after. Multi-step: concise plan + per-step validation. Skipped/blocked validation: exact gap.
