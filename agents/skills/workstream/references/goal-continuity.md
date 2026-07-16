# Goal Continuity

Read this file before creating a workstream goal. Copy the applicable literal
payload and continuity rules into the goal objective so resume and compaction do
not erase active constraints.

## Caveman Payload

Include this literal block when caveman mode is active:

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
- Keep code, commands, filenames, errors, security, and exact workstream status
  clear and exact.
```

## Common Continuity

Include these rules for every workstream goal after `Outcome: <one sentence>`:

- Continue from the newest user request and current plan/task state; do not
  restart from scratch after resume or context compaction.
- Rebuild continuity from the current canonical plan/task state, not the
  conversation transcript.
- Preserve durable constraints with scope and reason, unexpired task-local
  constraints with scope and expiry, current assumptions and non-goals,
  validation expectations, and unresolved decisions from the conversation
  ledger.
- Express preferences and selected designs as positive current state. Exclude
  rejected proposals, superseded alternatives, and expired constraints unless
  an exact prohibition remains necessary for a durable constraint.
- Protect user work: do not revert unrelated changes, and do not commit unless
  the user asked for commit work.

## Goal-Type Termination

Include exactly one rule:

- Execution goal: keep the workstream open until `close` confirms complete or
  truly blocked.
- Explicit plan-only goal: keep the planning workstream open until `Analyze
  Artifacts` reports the final artifacts, then complete or block the goal from
  that analysis result without running execution Close.
