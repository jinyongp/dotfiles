# Information Architecture

Use this guide when choosing or changing the structure of more than one page.
It provides decision lenses, not a required documentation taxonomy.

## Start with Reader Questions

Identify the questions that should have clearly discoverable answers. Common
question shapes include:

- What is this, and when is it useful?
- How do I get a successful first result?
- How do I complete a specific task?
- What does this public API, command, option, or format mean?
- How do the public concepts and constraints fit together?
- How do I diagnose a problem, move from an older version, or respond to a
  product change?

Use these questions to separate pages with different reading modes. A guided
learning path, a task procedure, a conceptual explanation, and lookup material
may link closely while remaining distinct when combining them would make any of
those jobs slower.

These question shapes do not prescribe top-level labels. Use names and groupings
that make sense to the product's readers.

## Select the Organizing Axes

Choose the smallest set of axes that matches how readers recognize their
situation. Useful axes can include:

- task or desired outcome
- product, capability, or domain
- reader role or prior experience
- platform, runtime, language, framework, or deployment environment
- version, compatibility range, or product lifecycle state

Use the dominant reader question as the primary axis. Add another axis only
when it removes meaningful ambiguity. Keep repository layout, team ownership,
and implementation boundaries out of navigation unless they are also stable
public product boundaries.

## Draw Page Boundaries

Give each page one primary purpose and a title that promises that purpose.
Separate a page when its audience, prerequisite, version, task, or reading mode
materially differs. Combine closely related material when separation would make
the reader repeatedly switch pages to complete one coherent task.

Place prerequisites before the action that needs them, warnings immediately
before the risky step, and explanations close to the example or decision they
clarify. Route readers to prerequisite, next-step, related reference, migration,
and troubleshooting material at the point where those links become useful.

## Design Discovery

Provide stable browseable paths to important content. Use concise navigation,
descriptive headings, contextual links, and landing pages that explain the
available routes. Add search, indexes, filters, tags, or a glossary when the
content volume or terminology makes them useful. Search supplements these paths;
it does not replace them.

Avoid duplicate canonical explanations. Let overview and routing pages summarize
briefly, then link to the one maintained home for each concept or contract.

## Choose Specialized Surfaces Deliberately

Use a specialized surface when it serves a repeated reader need better than
ordinary prose pages:

- A catalog or package directory helps readers compare many items. Use stable
  metadata, meaningful grouping or filters, compatibility and lifecycle status,
  and a consistent route to detailed guidance.
- A playground or sandbox helps readers learn by changing a working example.
  Provide an understandable starting state, visible results, reset or recovery,
  relevant version context, and an accessible static path to the same essential
  guidance. Account for maintenance and embedding constraints before making it
  part of the primary path.
- A showcase helps readers evaluate possibilities through real outcomes. Give
  each entry enough context to understand what was built and why it is relevant,
  and distinguish curated examples from compatibility or support guarantees.
- An ecosystem or add-on area helps readers judge extensions. State ownership,
  support level, compatibility, maintenance status, and trust-relevant facts
  without presenting third-party items as part of the core product.
- Generated API, CLI, configuration, or schema reference helps cover a large
  public surface consistently. Pair generation with editorial review, stable
  linking, version alignment, and explanatory guidance for real tasks.

Other forms are equally valid. Create one when the reader need, content shape,
and delivery environment justify it. Do not create a specialized surface solely
because another documentation site has one.

## Check the Structure

Test the proposed structure with representative reader journeys:

1. A new reader finds the right starting point and reaches a successful result.
2. A returning reader finds one exact fact without following a full tutorial.
3. A reader in a different version or environment recognizes the applicable
   guidance before acting.
4. A reader encountering an error or product change reaches the relevant
   recovery, migration, or lifecycle information.
5. A maintainer can identify one canonical home for each concept and update the
   documentation without repeating the same claim across many pages.

Revise the structure when a journey depends on internal project knowledge,
ambiguous labels, search alone, or repeated backtracking.
