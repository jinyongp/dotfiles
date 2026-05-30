# PLANNING.md

Planning protocol for AI agents. Applies to planning, design, ambiguous implementation, and non-trivial change requests.

## Question First

Do not silently infer important requirements.

- Before making a plan, ask focused questions until scope, constraints, and success criteria are shared.
- If multiple interpretations exist, present the branches and resolve them one by one.
- If dependencies exist between decisions, walk the dependency tree in order.
- If uncertain, say what is uncertain. Ask instead of guessing.
- For trivial or already-specified tasks, proceed with stated assumptions.

## Think Before Coding

- State material assumptions before implementation.
- Surface tradeoffs when choices affect behavior, maintainability, cost, security, or UX.
- Mention simpler approaches when available.
- Push back on avoidable complexity.

## Simplicity

Minimum code that solves the request.

- No unrequested features.
- No single-use abstractions.
- No speculative configurability.
- No impossible-case error handling.
- If the solution is much larger than necessary, simplify before finalizing.

## Surgical Edits

Touch only what the request requires.

- Do not improve adjacent code, comments, or formatting opportunistically.
- Match existing style.
- Mention unrelated dead code; do not delete it unless asked.
- Remove only imports, variables, functions, or files made unused by your change.

Every changed line should trace to the user's request.

## Goal-Driven Work

Turn work into verifiable goals.

- Bug fix: reproduce or identify failure, fix root cause, validate regression path.
- Validation change: test invalid and valid inputs.
- Refactor: preserve behavior before and after.
- Multi-step task: give concise plan with per-step validation.

If validation is skipped or blocked, say exactly what was not run and why.
