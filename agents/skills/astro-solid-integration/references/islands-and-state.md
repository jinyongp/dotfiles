# Islands and state ownership

## Island boundary

An Astro page may render multiple independent Solid roots. Each hydrated island has its own owner tree, context boundary, hydration timing, and lifecycle.

Sibling islands cannot rely on one Solid Context provider spanning both roots. If components require the same context and atomic state transitions, place them under one parent Solid island.

Do not merge unrelated UI into a single root merely to make sharing convenient. That couples hydration timing and lifecycle.

## State-sharing choices

Choose the narrowest suitable owner:

- one cohesive Solid island: shared context and transactions
- module-level client signal/store: small browser-only state shared by Solid roots
- framework-neutral store or browser event: state shared with Astro scripts or another UI framework
- server request context/session/database: request- or user-specific state

Never treat module scope as request scope. A module imported during server rendering may be shared by multiple requests in the same process, so do not place user-specific server data there.

Astro frontmatter runs during build or server rendering. It is not a persistent reactive client component and does not rerender because a Solid or external store changes.

## Client directives

Select hydration by actual interaction needs:

- `client:load`: immediate interaction is required
- `client:idle`: interaction can wait for browser idle time
- `client:visible`: below-the-fold or visibility-triggered UI
- `client:media`: behavior needed only for a matching media query
- `client:only="solid-js"`: SSR is impossible or intentionally omitted; the framework value is required

Do not use `client:only` as the default workaround for SSR bugs. It removes server rendering and changes loading behavior.

## Island cost

Before adding an island, ask:

1. Does this UI require browser JavaScript?
2. Could semantic HTML or an Astro script handle it?
3. What state and context does it own?
4. Why is this hydration directive appropriate?

Primary sources:

- https://docs.astro.build/en/concepts/islands/
- https://docs.astro.build/en/reference/directives-reference/#client-directives
- https://docs.astro.build/en/recipes/sharing-state-islands/
