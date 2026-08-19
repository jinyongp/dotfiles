# Reactivity and props

## Component execution model

A Solid component normally executes once to create reactive computations and DOM update points. It is not a function rerun for every state change.

Values read into ordinary variables or used in top-level control flow are snapshots unless the surrounding operation creates a tracking scope.

```tsx
// Snapshot: label and branch are fixed during component setup.
const online = props.user.online;
const label = online ? "Online" : "Offline";
if (!online) return <Offline />;
```

Keep changing reads inside JSX, an accessor, a memo, or reactive control flow.

```tsx
const label = () => (props.user.online ? "Online" : "Offline");

return (
  <Show when={props.user.online} fallback={<Offline />}>
    <Online label={label()} />
  </Show>
);
```

Do not flag top-level reads when the input is intentionally immutable and the contract proves it. State the assumption.

## Props

Props may expose reactive getters. Destructuring or copying a property can break future tracking.

```tsx
// Risk when values can change.
function Input({ value }: Props) {
  return <input value={value} />;
}
```

Prefer direct property access. Use `splitProps` when groups must be separated and `mergeProps` for reactive defaults in versions that provide those APIs.

```tsx
const [local, others] = splitProps(props, ["value", "label"]);
return <input {...others} value={local.value} aria-label={local.label} />;
```

Do not mechanically rewrite every destructure. First establish whether the prop can change within the component lifetime.

## Children

Repeatedly resolving `props.children` can recreate or reevaluate child expressions. Use Solid's `children` helper when code must inspect, normalize, or reuse children. A single direct render does not require the helper.

## Dynamic component choice

This captures the first component choice:

```tsx
const View = views[props.mode];
return <View />;
```

Use the version-appropriate dynamic component primitive when the component type must change reactively.

## Tracking boundaries

For every suspected stale read, answer:

1. Which reactive source is read?
2. Which computation or JSX expression owns the read?
3. Can the source change after setup?
4. What observable output should update?

No changing source or no required update means no correctness finding.

Primary source: https://docs.solidjs.com/concepts/intro-to-reactivity
