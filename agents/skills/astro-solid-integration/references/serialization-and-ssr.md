# Serialization and SSR

## Props crossing the boundary

Props passed from `.astro` to a hydrated Solid component cross a serialization boundary. Prefer explicit data-transfer objects containing supported values.

Do not pass:

- callbacks or Solid accessors/setters
- DOM nodes
- framework proxies or stores
- service objects with behavior
- arbitrary class instances without documented serialization support

Pass identifiers, permissions, and initial snapshots. Define event handlers inside the island. Send server mutations through Actions, endpoints, or another explicit protocol.

Large repeated props across many islands can duplicate serialized payload. Consider one parent island, a client cache, or identifier-based loading.

## Data ownership

Avoid fetching identical initial data in Astro frontmatter and again on Solid mount. Pick one initial owner:

```text
server request/build
  -> serialized initial snapshot
  -> Solid island owns later client refreshes
```

Use request-scoped Astro facilities for authentication, permissions, session, and user-specific server data.

## SSR and browser APIs

Unless `client:only` is used, Solid output can participate in server rendering before hydration. Initial code must not assume `window`, storage, viewport, or DOM availability.

Move browser-only setup to `onMount`, and register disposal with `onCleanup`. Provide deterministic initial output so server and browser agree.

Random values, current time, locale, timezone, and viewport-dependent branches can create mismatches. Prefer server snapshots or a stable placeholder followed by a client update.

## Async rendering

Do not assume Solid async primitives run only in the browser. Current `@astrojs/solid-js` versions render server and hydrated components with an async top-level Suspense boundary so resources and lazy components can resolve during server rendering; `client:only` is the exception. Verify this behavior against the installed integration version, and ensure fetchers can execute wherever the renderer invokes them.

Primary sources:

- https://docs.astro.build/en/guides/framework-components/
- https://docs.astro.build/en/guides/server-side-rendering/
- https://docs.astro.build/en/guides/actions/
