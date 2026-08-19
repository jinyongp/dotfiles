# Routing, lifecycle, and composition

## Routing ownership

Treat overlapping Astro ClientRouter and Solid Router ownership as a warning to investigate, not an automatic error. Avoid letting both systems own the same top-level URL space and link interception.

Prefer one clear arrangement:

```text
Astro file routing -> independent Solid islands
Astro file routing -> one Solid Router SPA zone under a base path
Solid-native application routing -> Solid owns the application route tree
```

If both routers exist, document the base-path boundary and which system owns navigation, loading, scroll restoration, and route context.

## View transitions and persistence

With Astro client navigation, `transition:persist` retains an island's state while updating it with the next page's props by default. Adding `transition:persist-props` retains the old props as well.

Use prop persistence only when stale route input is intended. Review timers, observers, subscriptions, listeners, and resources across navigation and disposal.

Astro scripts that must rerun after client navigation should use the documented Astro navigation lifecycle rather than assuming a full page reload.

## Composition boundary

Hydration directives belong on framework components directly imported by an `.astro` file. Do not assume a runtime-selected component variable can always receive a `client:*` directive.

When dynamic component selection is required, choose statically imported branches in Astro or perform the dynamic choice inside one directly imported Solid island.

Astro-generated children or slots passed into a Solid island remain Astro-rendered content; they do not become reactive Solid descendants or gain Solid context automatically.

Do not import `.astro` components into Solid TSX as if they were ordinary Solid components. Compose at the Astro parent boundary.

## Multiple JSX frameworks

When Astro uses multiple JSX frameworks, inspect integration `include` and `exclude` configuration. Ensure each file is compiled by the intended renderer rather than relying on ambiguous extension matching.

Primary sources:

- https://docs.astro.build/en/guides/view-transitions/
- https://docs.astro.build/en/guides/framework-components/
- https://docs.astro.build/en/guides/integrations-guide/solid-js/
