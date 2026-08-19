# SSR, security, and performance

## Server and client parity

SSR and hydration require compatible initial output. Treat these as suspect in initial JSX unless a stable server-provided value exists:

- `window`, `document`, storage, media queries, and viewport state
- random values and current time
- locale or timezone values that differ by environment
- DOM measurements

Move browser-only work to a client lifecycle, or provide a deterministic initial snapshot. Do not use no-hydration mechanisms merely to hide a mismatch; they also remove hydration behavior from that subtree.

Effects and mount hooks may have different server behavior. Do not make server output depend on client-only effects.

## Unsafe HTML

Treat HTML injection as a security boundary. Require evidence that content is trusted or sanitized with a suitable policy before rendering unsanitized markup. Escaping and sanitization are different operations.

## Performance claims

Fine-grained reactivity does not make every additional signal, memo, store, or component beneficial. Classify a recommendation as `PERFORMANCE` unless a measured or structurally clear cost exists.

Check:

- update frequency and subscriber count
- list size and identity churn
- repeated expensive computation
- unnecessary client JavaScript or hydration
- whole-object replacement versus targeted updates
- server and client duplicate work

Avoid speculative micro-optimizations that obscure ownership or correctness.

## Validation

For SSR or hydration changes, run the real production build and, when practical, exercise the built output. A development renderer can take different dependency and conditional-export paths.

Primary sources:

- https://docs.solidjs.com/reference/rendering/hydration-script
- https://docs.solidjs.com/reference/rendering/no-hydration
