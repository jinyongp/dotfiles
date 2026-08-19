# Version discipline

## Detect before advising

Read the manifest and lockfile. Record:

- resolved `solid-js` version
- stable versus prerelease channel
- SolidStart and router versions
- renderer or meta-framework integration versions
- peer dependency constraints

Package ranges alone may not identify the installed version. Prefer lockfile resolution or installed package metadata when available.

## Apply version-scoped rules

Do not mix examples from different major versions. Before recommending a primitive:

1. Verify it exists in the installed version.
2. Check its server behavior and ownership contract.
3. Check integration peer ranges.
4. Mark migration-only advice as `VERSION`.

Never recommend forcing incompatible peer dependencies as a routine fix. For prerelease experiments, use an isolated branch or proof of concept and state the unsupported boundary.

## Sources

Use official documentation, package metadata, release notes, and installed types/source in that order appropriate to the question. Third-party skills and blog posts may suggest leads but do not establish API guarantees.

- Solid documentation: https://docs.solidjs.com/
- Solid releases: https://github.com/solidjs/solid/releases
