# Planning Review

Use Planning skill rules loaded by parent plus these axes:

1. Scope/non-goals/constraints/success/acceptance are explicit and testable.
2. Logic: no contradiction, impossible state, circular dep, false premise, or missing prerequisite.
3. Structure: steps follow dependency order; ownership/boundaries clear; work split reviewably.
4. Contract: claims match code, APIs, schemas, data flow, runtime, external systems.
5. Risk: security, data, migration/backfill, rollback, ops, perf, compatibility covered when material.
6. Decisions: unresolved choices stay visible, not settled; vague/risky choices get guardrails or user decision.
7. Validation: material behavior maps to concrete checks, including failure cases and final acceptance.
8. Context hygiene: active artifacts contain current canonical state; durable prohibitions include scope and reason; task-local constraints include expiry; rejected, superseded, and expired context appears only in an explicitly required audit record.
