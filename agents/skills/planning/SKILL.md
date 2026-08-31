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
- Treat a decision as open only when all are true:
  - Two or more viable choices remain after reading the request, relevant
    project conventions, nearby code, and available docs.
  - The choice materially affects behavior, public API, data shape, migration,
    security, privacy, UX, cost, schedule, validation scope, or future
    compatibility.
  - The agent lacks authority or evidence to choose safely, and a wrong choice
    would cause meaningful rework or user-visible surprise.
- Do not mark routine implementation details, validation command selection,
  naming that follows local convention, easily reversible choices, or "nice to
  know" context as open decisions.
- Every open decision must include: the concrete choice, current evidence, why
  existing context cannot settle it, impact of choosing wrong, the recommended
  option, and viable alternatives with tradeoffs.
- Recommend one option unless evidence is truly balanced. State why it is the
  default path.
- Include only real alternatives: materially different, in-scope,
  implementable, and supported by available evidence. Do not invent or pad
  alternatives to satisfy a format.
- If only one defensible option remains, it is not an open decision. Treat it as
  a decision or assumption and proceed.
- If a decision is low-impact or safely reversible, make a conservative
  assumption and record it as an assumption instead of raising an open decision.
- If no safe default exists, ask one concise question and keep affected work
  blocked until answered.
- Options useful? Include options + required recommendation in conversation.
- Recommendation present? Explain reasoning, tradeoffs, consequences, and selection criteria in detailed prose, because the user must inspect and decide.
- Mark optional choices optional.
- Do not let docs hide unresolved choices.
- User answer vague? Convert to testable wording and confirm.
- User answer risky? Present guardrail, default recommendation, and consequence.
- User answer wrong/inconsistent? Stop and reconcile before docs or execution.

## Decision Canonicalization

When the user replaces or rejects a proposal, apply the governing context
hygiene rules before updating any artifact or handoff:

- Make the selected behavior or design the positive canonical state.
- Remove superseded alternatives from active specs, plans, prompts, comments,
  summaries, and handoffs.
- Preserve an exact prohibition only when it remains an active durable
  constraint; record its scope and reason.
- Preserve a task-local constraint only for its stated scope and lifetime.
- Put historical rationale only in an explicitly required audit or decision
  record, never in the active execution context by default.

After a material decision change, scan the active artifacts for stale mentions
before treating the decision as settled.

## Docs

If user asks docs, write settled facts only: behavior, commands, constraints, current state. No undecided item as decided.
Do not add "Open Decisions", "TODO Decisions", "Questions", or recommendation sections to docs unless user explicitly asks for decision log; even then, label unresolved and mirror in conversation.

## Keep Small

Minimum steps/code. No unrequested feature, speculative config, one-off abstraction, impossible-case handling.

## Edit

Touch request scope only. Match style. Mention unrelated dead code; don't delete unless asked. Remove only code made unused by change. Every changed line traces to goal.
Never modify another project unless the user explicitly directs changes to that project in the current request.

## Verify

Turn material risks into checks. First decide whether validation is necessary based on plausible failure, impact, useful signal, and cost. Do not add checks for trivial or mechanical changes solely because an item ended; group related small edits and validate at a meaningful behavior boundary. Bug: identify/repro, fix root, validate regression. Validation change: valid + invalid. Refactor: preserve before/after. Multi-step: concise plan + warranted per-step validation. Skipped/blocked required validation: exact gap.
For sequential work with warranted checks, classify validation as per-item or pre-close integrated. Run lightweight checks before ending an item only when useful. Schedule justified heavyweight checks after all implementation items and before close, while keeping their commands, scope, and prerequisites ready after each item.
Record validation for each work item as required or `not-needed`. Required pre-close validation remains an open completion gate: an item may be implementation-complete while validation is pending, but do not mark affected work done until the check passes.
