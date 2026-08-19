---
name: astro-solid-integration
description: Build, debug, refactor, or review Astro applications that integrate SolidJS, including islands, client directives, state ownership, prop serialization, SSR and hydration, routing, persistence, composition, and production compatibility. Do not use for Solid-only applications or Astro integrations that do not use Solid.
---

# Astro Solid Integration

Treat Astro and each hydrated Solid island as explicit runtime and ownership boundaries.

## Start

1. Inspect `package.json`, lockfile, `astro.config.*`, TypeScript config, relevant `.astro` and Solid files.
2. Identify resolved Astro, `@astrojs/solid-js`, and `solid-js` versions plus peer constraints.
3. Identify output mode, adapter, SSR/SSG/on-demand rendering, client router, and Solid router use.
4. Map which layer owns routing, server data, interactive state, and side effects.

Use current official Astro and Solid documentation when behavior is version-sensitive. Do not apply prerelease guidance to stable projects.

## Route references

- Read [islands-and-state.md](references/islands-and-state.md) for island size, client directives, contexts, and cross-island state.
- Read [serialization-and-ssr.md](references/serialization-and-ssr.md) for prop DTOs, server/client data ownership, browser APIs, and hydration parity.
- Read [routing-lifecycle-and-composition.md](references/routing-lifecycle-and-composition.md) for ClientRouter, Solid Router, persistence, component boundaries, and JSX framework coexistence.
- Read [build-and-versions.md](references/build-and-versions.md) for peer versions, conditional exports, adapters, and production validation.

When the task also requires reasoning inside Solid TSX, apply the sibling [solidjs-development](../solidjs-development/SKILL.md) skill if it is available. Otherwise inspect the installed Solid version and official Solid documentation directly. Do not infer Solid-internal behavior from Astro's integration boundary.

## Judgment

Classify findings as `ERROR`, `WARNING`, `PERFORMANCE`, `STYLE`, or `VERSION`. Trace a concrete execution path before reporting a problem.

Do not assume:

- every interactive fragment needs a Solid island
- one Context spans sibling islands
- all islands should use `client:load`
- server and client should both fetch the same initial data
- development-server success proves deployment compatibility

## Validation

Use repository commands. For integration changes, prefer `astro check`, focused tests, and the real production build with the configured output mode and adapter. Exercise hydrated behavior when practical.
