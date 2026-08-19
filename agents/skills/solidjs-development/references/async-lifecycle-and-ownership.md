# Async, lifecycle, and ownership

## Async tracking

Reactive tracking is synchronous. Reads made after an `await` are not automatically dependencies of the computation that began before it.

Capture tracked inputs before crossing the async boundary, or use the version-appropriate async primitive.

```tsx
createEffect(() => {
  const id = userId();
  void loadUser(id);
});
```

Do not hide changing dependencies inside an async helper and assume the outer effect tracks them.

## Races and stale results

When requests can overlap, ensure an older response cannot overwrite newer state. Use cancellation, request identity, sequence checks, or a framework primitive with documented stale-result handling.

Inspect error, loading, refresh, and disposal behavior—not only the success path.

## Ownership

Computations, cleanup, context, and error boundaries depend on an owner. Reactive work created later from an unowned callback may outlive its intended tree or lose context.

Before reporting an ownership bug, trace where the callback was registered and where the computation is actually created. Use owner capture or a scoped root only when lifetime semantics require it.

## Cleanup

Register cleanup with `onCleanup` in the owning scope.

```tsx
onMount(() => {
  const handler = () => setWidth(window.innerWidth);
  window.addEventListener("resize", handler);
  onCleanup(() => window.removeEventListener("resize", handler));
});
```

Returning a cleanup function from `onMount` is not the React effect contract. Verify the actual Solid API before assuming return-value cleanup.

Review timers, observers, subscriptions, sockets, event listeners, and imperative library instances.

## Events versus effects

Handle user actions directly in event handlers. Do not convert an action into a signal solely to trigger an effect unless the intermediate state has independent meaning.

Primary sources:

- https://docs.solidjs.com/reference/lifecycle/on-cleanup
- https://docs.solidjs.com/reference/lifecycle/on-mount
- https://docs.solidjs.com/reference/reactive-utilities/get-owner
