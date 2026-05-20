---
name: planning
description: >
  Use for plans, design, ambiguity, non-trivial implementation, scope negotiation,
  success criteria. Replaces old PLANNING.md without always-read cost.
---

# Planning

Use when user asks plan/design/approach/tradeoffs or task is ambiguous/non-trivial.

## Ask First

- Do not silently infer important requirements.
- Ask focused questions until scope, constraints, success criteria clear.
- Branches? Name options; resolve one by one.
- Dependent decisions? Walk dependency order.
- Unknown? Say unknown; ask.
- Trivial/specified? Proceed with stated assumptions.

Do not rubber-stamp unsafe/abstract/under-specified/inconsistent/conflicting decisions. Surface issue; suggest correction.

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
- Options useful? include options + required recommendation.
- Mark optional choices optional.
- Do not let docs hide unresolved choices.

## Docs

If user asks docs, write settled facts only: behavior, commands, constraints, current state. No undecided item as decided.

## Keep Small

Minimum steps/code. No unrequested feature, speculative config, one-off abstraction, impossible-case handling.

## Edit

Touch request scope only. Match style. Mention unrelated dead code; don't delete unless asked. Remove only code made unused by change. Every changed line traces to goal.

## Verify

Turn plan into checks. Bug: identify/repro, fix root, validate regression. Validation change: valid + invalid. Refactor: preserve before/after. Multi-step: concise plan + per-step validation. Skipped/blocked validation: exact gap.
