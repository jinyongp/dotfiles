---
name: solidjs-development
description: Build, debug, refactor, or review SolidJS and Solid TSX code with version-aware fine-grained reactivity, ownership, async, rendering, SSR, and hydration guidance. Use for Solid-specific implementation and correctness work; do not use for React, Vue, or Astro integration boundaries that contain no Solid code.
---

# SolidJS Development

Apply Solid's execution and reactivity model instead of React-style rerender assumptions.

## Start

1. Inspect `package.json`, the lockfile, TypeScript config, and relevant source.
2. Identify the resolved `solid-js` version and whether it is stable or prerelease.
3. Detect SolidStart, router, SSR, hydration, and rendering-library involvement.
4. Follow the user's requested mode: explain, review, diagnose, implement, or verify.

Do not apply remembered APIs across major versions. When version-sensitive behavior matters, inspect installed package types/source or current official Solid documentation.

## Route references

- Read [reactivity-and-props.md](references/reactivity-and-props.md) for component execution, tracking, props, children, and dynamic components.
- Read [state-rendering-and-identity.md](references/state-rendering-and-identity.md) for derived state, effects, stores, context, lists, and identity.
- Read [async-lifecycle-and-ownership.md](references/async-lifecycle-and-ownership.md) for resources, `await`, cleanup, owners, races, and external effects.
- Read [ssr-security-and-performance.md](references/ssr-security-and-performance.md) for SSR, hydration, browser APIs, unsafe HTML, and performance claims.
- Read [versions.md](references/versions.md) whenever API availability, migration, prerelease behavior, or ecosystem compatibility affects the answer.

Load only references relevant to the current task.

## Judgment

Classify review findings:

- `ERROR`: demonstrated incorrect behavior, leak, hydration fault, or security issue.
- `WARNING`: likely design defect with a concrete failure mode.
- `PERFORMANCE`: optimization claim requiring workload evidence or measurement.
- `STYLE`: valid alternatives governed by team preference.
- `VERSION`: rule or API limited to a specific Solid version.

Never turn these into universal syntax bans:

- ternary versus `<Show>`
- `.map()` versus `<For>`
- accessor versus `createMemo`
- signal versus store
- `createResource` or `<Suspense>` for every async operation

Trace actual reads, writes, owners, identities, and render boundaries. Report a finding only when the data flow supports it.

## Validation

Use the repository's commands. Prefer typecheck and focused tests, then SSR or production build when hydration, conditional exports, browser-only dependencies, or server rendering are involved. Development-server success alone does not prove production compatibility.
