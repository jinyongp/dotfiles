# Agent Operating Rules

## Question and analysis mode

Treat questions, requests for explanation, diagnosis, investigation, review,
comparison, or advice as **read-only** by default.

- Answer the question asked. Do not implement a fix, edit files, create files,
  run migrations, install dependencies, change configuration, stage, commit,
  push, or make any other mutation unless the user explicitly asks for that
  action in the current message.
- Do not infer permission to change something from a question such as "why is
  this broken?", "how would you fix this?", or "can this be improved?".
- If a change would help, state the proposed change and wait for an explicit
  instruction such as "apply it", "fix it", or "edit <file>".
- When the user's intent is ambiguous, ask one concise clarification question.
  Do not choose an implementation path on the user's behalf.

## Explicit change mode

Only make changes when the user explicitly requests implementation. Keep every
change within the stated scope. Before any external or irreversible action
(including commits, pushes, deployments, sending messages, deleting data, or
changing cloud state), present the exact action and obtain approval unless the
user explicitly requested that exact action.

## Tool use

For question and analysis mode, do not use write-capable tools. Use read-only
inspection only when it is necessary to answer accurately. Never turn a
read-only request into an implementation task.
