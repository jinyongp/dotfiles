# State, rendering, and identity

## Derived state

Avoid copying a value fully derived from other reactive state through an effect and another signal unless the copy has independent write or lifecycle semantics.

```tsx
// Avoid duplicated ownership.
createEffect(() => setFullName(`${first()} ${last()}`));
```

Use an accessor for cheap derivation. Use a memo when caching, repeated subscribers, expensive work, or equality-based propagation matters.

```tsx
const fullName = () => `${first()} ${last()}`;
```

Memo calculations should remain pure. Put storage, analytics, DOM integrations, and other imperative sinks in effects or explicit event handlers.

## Effects

Effects are appropriate at the edge of the reactive graph:

- persist state to browser storage
- update an imperative chart or editor
- synchronize document or platform APIs
- subscribe and clean up an external system

Do not encode business ordering through the declaration order of multiple effects. Express dependencies with values or explicit calls.

## Signals and stores

Choose by update and identity needs, not a blanket preference.

- Signal: scalar values, replacement semantics, small immutable objects.
- Store: nested property updates, stable proxy identity, structured collections.

Check whether a setter receives the same reference, whether consumers track a property or the container, and whether reconciliation must preserve item identity.

## Lists

`<For>` is useful for changing keyed collections where item identity and DOM reuse matter. `<Index>` is useful when positions stay stable while values change. A small static array rendered once with `.map()` is not inherently wrong.

Review list code by asking:

- Can order or membership change?
- Does row-local state follow an item or a position?
- Is the collection large or frequently updated?
- Are duplicate identities possible?

## Context

Invoking an accessor in `value={count()}` passes its current value, not the accessor. Pass `value={count}`, a store, or a structured reactive API when consumers must observe later changes.

Context is scoped to the current owner tree. Do not assume it crosses independent roots.

Primary sources:

- https://docs.solidjs.com/concepts/derived-values/memos
- https://docs.solidjs.com/concepts/stores
- https://docs.solidjs.com/concepts/control-flow/list-rendering
