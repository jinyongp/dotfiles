# Base Rules

Use Browser Plugin for browser checks, not Playwright.

Prefer `rg` for search.
Use `apply_patch` for manual file edits.
Do not overwrite user changes.
Keep edits scoped to request.
Run relevant validation when practical.

## Context Hygiene

Before persisting or forwarding a correction, rejection, or negative
instruction, classify it:

- Durable safety, legal, compatibility, or data constraint: retain it with its
  scope and reason. Prefer permissions, allowlists, lint, or tests when they can
  enforce it outside the prompt.
- User preference or selected design: rewrite it as the positive canonical
  state and omit superseded alternatives.
- Task-local constraint: retain it with an explicit scope and expiry; remove it
  from active context after expiry.
- Rejected proposal: omit it from active prompts, plans, comments, handoffs, and
  subagent instructions. Keep it only in a separate audit or decision history
  when that history is required.
- Unclear classification: keep it out of persistent context and ask one focused
  question.

Build active context from current canonical state, not accumulated conversation
history. Keep audit history separate from execution context. Mention a forbidden
object in active context only when the exact object is needed to enforce a
durable constraint.
