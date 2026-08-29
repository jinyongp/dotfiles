---
name: dev-docs
description: >
  Create, revise, review, or organize developer-facing product documentation by
  inspecting the product, public behavior, intended readers, existing docs, and
  delivery context, then choosing the most effective structure, format, depth,
  and navigation. Use for documentation that helps developers use a library,
  framework, tool, API, package, or platform; not for internal RFCs, ADRs,
  implementation plans, or code comments.
---

# Dev Docs

Act as both documentation architect and technical writer. Help the intended
developer understand and use the product without requiring knowledge of its
internal implementation. Do not begin from a fixed template or closed catalog
of document types.

Use the capabilities available in the current agent environment without
assuming a particular vendor, product, proprietary tool, or invocation syntax.
Keep generated documentation and reusable supporting resources independent of
agent-specific conventions unless the target project explicitly requires one.

## Understand the Documentation Context

Inspect enough of the project to establish:

- the intended readers, their likely prior knowledge, and the task they need to
  complete
- the supported public behavior, terminology, prerequisites, environments, and
  versions
- the existing documentation structure, style, navigation, examples, and build
  conventions
- the authoritative sources for public claims, such as exported APIs, public
  types, supported configuration, tests, examples, release information, and
  existing user-facing contracts
- the requested scope, from one focused page to a complete documentation set

Use internal source code as evidence, not as the viewpoint of the document. If
a missing fact or unresolved product decision would materially change public
guidance, keep it out of the document and ask for resolution.

## Choose the Best Form

Derive the information architecture from reader needs and the actual product.
Familiar forms and labels are optional patterns, not required sections. Combine,
adapt, omit, or create forms when that gives the reader a clearer path.

Choose page boundaries, sequence, navigation, level of detail, examples,
reference density, and interactive elements according to the task. Preserve an
existing structure for a scoped edit when it still serves the reader. Redesign
broader structure only when the request includes organization work or the
current structure prevents the requested outcome.

Optimize for:

- fast discovery of the right information
- successful completion of the reader's task
- accuracy against the supported public contract
- a natural progression from required context to deeper use
- minimal duplication and one clear home for each concept
- consistency with the product's existing language and documentation system
- maintainability across versions and product changes
- accessible presentation across supported devices and formats

Do not add pages, sections, or navigation levels merely to satisfy a common
documentation pattern.

For a new documentation set, a broad reorganization, or a project that may
need catalogs, playgrounds, showcases, generated reference, or other specialized
surfaces, read [references/information-architecture.md](references/information-architecture.md).

## Describe the Public Model

Explain stable public concepts, capabilities, constraints, and observable
behavior. Organize the explanation around what the reader is trying to achieve.

Do not expose private architecture, internal identifiers, repository paths,
source layout, intermediate data structures, algorithms, or implementation
steps merely because they were visible during research. Advanced documentation
still covers advanced public use; it is not a place to reveal internals.

Include an implementation detail only when a developer must know it to use,
debug, secure, or operate the product correctly. State the smallest useful
detail and explain its user-visible consequence. Do not turn incidental current
behavior into a supported public contract.

## Handle Versions and Product Lifecycle

Write for an identified product version or supported version range. Make the
relevant version, environment, platform, language, or product variant visible
when it changes what the reader should do.

Present the current supported path as the main guidance. Mark experimental,
deprecated, legacy, or removed behavior with its exact scope and direct readers
to the supported path. Keep older behavior in active documentation only when it
is needed for a maintained version, compatibility guidance, or migration.

Treat release notes, changelogs, deprecation notices, and migration guides as
time-bound documentation. Preserve dates, versions, and transition boundaries
there instead of blending historical states into current guidance.

## Write Explanatory Prose

Write for a developer who is new to the documented feature and has only the
prerequisites stated in the document.

- Introduce the purpose and user-facing idea before naming the API, option,
  type, command, or other identifier that implements it.
- Explain how steps and examples produce the intended result. Do not rely on
  code, identifiers, headings, tables, or bullet lists to carry the explanation
  by themselves.
- Use complete, natural sentences and connect related ideas explicitly. Define
  unfamiliar terms on first use and avoid unexplained project jargon.
- Keep examples small enough to understand but complete enough to run or adapt.
  Explain important input, behavior, and output near the example.
- Put prerequisites, constraints, warnings, and failure conditions where the
  reader needs them.
- Prefer concrete user-facing language over abstractions derived from the code
  structure. Use public identifiers precisely, but never as a substitute for
  explaining meaning.
- Keep the writing concise without reducing it to fragments or reference-only
  prose.

## Build Reliable Reference and Examples

When the reader needs to look up a public surface, give reference pages a
predictable structure and enough coverage to answer the same kinds of questions
consistently. Include applicable syntax, inputs, outputs, constraints, errors,
permissions, compatibility, and examples. Include only fields that are relevant
to the documented surface.

Generated reference is a starting point, not an automatic final document.
Review it for missing user context, misleading source comments, unsupported
internals, inconsistent terminology, useful examples, and links to the guidance
that explains when and why to use the feature.

Examples must use supported public behavior and state the setup needed to run
them. Prefer a small complete example over a fragment that hides essential
context. Use secure, accessible, non-deprecated patterns suitable for adaptation
unless the example is explicitly labeled as a limited demonstration. Never use
real credentials or imply that unsafe placeholder configuration is production
guidance.

## Write Each Language Natively

When documentation is required in more than one language, treat each version as
an independent piece of writing with the same meaning. Preserve intent,
technical accuracy, scope, and tone rather than sentence structure or word
order.

Restructure sentences and paragraphs as needed for the target language. Use its
natural grammar, rhythm, technical vocabulary, and explanatory conventions.
Avoid literal translation, calques, and wording that reads as if it was copied
from another language. Review every language version on its own for clarity and
naturalness.

Keep code identifiers, commands, literal values, package names, and product
names exact unless an official localized form exists. Maintain terminology
consistently within each language without forcing one-to-one wording across
languages.

Adapt locale-sensitive details when relevant, including user-interface terms,
dates, numbers, units, links, images, and layout. Follow the target language's
established terminology or style guide when one exists. Validate each localized
version in context rather than checking sentence correspondence alone.

## Keep Only the Current Canonical State

Record user preferences and adopted designs as positive statements of the
current settled state. Omit rejected proposals, superseded alternatives, and
constraints that no longer apply from active documentation.

Retain an explicit prohibition when it is necessary to enforce a durable
constraint. State its scope and reason so future edits preserve the intended
boundary. Include historical states only when the document's purpose requires
them, such as migration guidance or an explicitly requested history, and label
their time and scope clearly.

Do not write unresolved decisions as settled facts. Keep decision discussion in
the conversation until it is resolved.

## Verify Before Delivery

- Check factual claims against the supported public behavior and relevant
  version. Surface conflicting evidence instead of choosing silently.
- Verify commands and examples when practical. Ensure they use public APIs and
  do not depend on private test helpers or repository-only state. Check the
  supported versions and environments represented by the guidance.
- Confirm the structure fits the reader's task rather than the repository's
  internal organization.
- Confirm important destinations have stable browseable routes and useful
  cross-links. Treat search, indexes, filters, and glossaries as additional
  discovery tools according to the size and shape of the content.
- Confirm a reader new to the feature can understand the explanation and adapt
  the examples using only stated prerequisites.
- Review generated reference as user documentation and confirm that lifecycle
  status, compatibility, constraints, and security-sensitive requirements are
  visible where they affect use.
- Remove unnecessary implementation details and internal identifiers.
- Check that current choices are stated canonically and stale alternatives are
  absent.
- For every target language, review the result as native writing rather than as
  a translation.
- Match the repository's documentation format and tooling, and check links,
  navigation, formatting, and generated output when the task changes them.
