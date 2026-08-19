# Build and version compatibility

## Resolve the stack

Inspect the manifest, lockfile, installed metadata, and Astro config. Record:

- Astro version
- `@astrojs/solid-js` version
- `solid-js` version
- router and Solid ecosystem packages
- output mode and adapter
- stable versus prerelease dependencies

Check peer dependency ranges before recommending upgrades. Do not mix Solid major-version guidance or force unsupported combinations as a default fix.

## Production-only failures

Solid ecosystem packages may expose conditional exports or precompiled browser/server variants. Development and production can resolve different paths. Browser-only transitive dependencies may also fail only during prerender or SSR.

When relevant, validate:

1. `astro check`
2. project tests and typecheck
3. `astro build`
4. built output using the configured adapter or preview command
5. hydration in a browser

Do not declare compatibility from `astro dev` alone.

## Versioned findings

Label a finding `VERSION` when it depends on a specific release, prerelease, peer range, or known compatibility issue. Include the detected versions and primary evidence. Do not preserve a dated workaround after its affected range is gone.

Use official sources and installed package metadata:

- Astro Solid integration: https://docs.astro.build/en/guides/integrations-guide/solid-js/
- Astro releases: https://github.com/withastro/astro/releases
- Solid releases: https://github.com/solidjs/solid/releases
