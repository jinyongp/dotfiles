# Code Quality Review

Review code quality only when it creates concrete correctness, debugging, test, maintenance, or misuse risk. Do not turn review into style preference.

## Flag

- Helper/composable/function signatures with more than two parameters
- Positional boolean flags or naked primitive config values
- Same-kind primitive params whose meaning is unclear at callsite
- Options/config placed before primary subject/input/context
- Single-use trivial transformation helpers: tiny `normalize*`, `resolve*`, `sanitize*`, `coerce*`, `map*`, `to*`, `from*`, `get*`, `build*`, or adapter/wrapper helpers that only trim, coerce, default, rename, reshape, or pass through values
- Domain-renamed duplicates: same few-line behavior copied under different domain names
- Thin wrappers that only rename/reorder args, inject one literal/default, or compute obvious derived value before delegating
- Helper layers that hide mutation, fallback policy, null handling, or error swallowing behind vague names
- Repo/app/channel prefixes used as fake meaning, e.g. `storefront*`, `admin*`, `api*`, `service*`, unless they model a real boundary

## Require

- Default authored signatures: `subject`, `options`, or `subject, options`
- First parameter = clear primary subject/input/context
- Secondary variation, flags, modes, callbacks, fallback/default/limit/config = named options object
- Multiple same-kind primitives = named object shape
- Inputs immutable by default; return next value/object instead of mutating caller-owned input
- Helper has owned behavior, policy, validation, or boundary responsibility
- Shared behavior lives in one helper with a name based on actual responsibility, not domain branding

## Trivial Transformation Helper Guard

Do not extract single-use trivial transformation helpers. Keep the expression inline or inside the owning function unless the helper owns a real policy boundary or removes real duplication.

Extraction must be earned: extract a helper only when it has multiple callers, meaningful policy, independent test value, or reduces a block that is hard to read inline.

Allowed:

- Normalizes externally inconsistent input at ingress
- Enforces domain rule or security rule
- Centralizes non-trivial fallback/null/error policy
- Is reused because behavior is genuinely identical
- Makes a complex transform named and testable

Flag:

- `resolveTrimmedString(value)` style one-liners
- File-local or module-level helper created only to avoid writing `value.trim()`
- Helper used by exactly one caller and containing only trim/coerce/default/rename/reshape/pass-through logic
- Helper extracted only because a block felt long, without reuse, policy, or test value
- Same helper copied as `normalizeRestaurantName`, `normalizeItemName`, `normalizePickupAddress` when behavior is identical
- Wrapper whose name sounds domain-specific but implementation is generic string cleanup

Prefer inline expression for one-off logic. Prefer one shared generic helper when behavior is truly reused and identical.

## Parameter Count

More than two parameters is a review smell. Prefer no params when value can be derived locally. If input is needed, prefer one primary subject plus one named options object.

Bad:

```ts
function loadOrder(id: string, includeItems: boolean, locale: string, fallbackName: string) {}
```

Good:

```ts
function loadOrder(orderId: string, options?: LoadOrderOptions) {}
```

Do not approve third positional params unless framework/library signature, stable public contract, or migration constraint makes it unavoidable.

## Pass

Pass only when helper boundaries reduce real complexity. Fail code that grows extra functions, names, params, or wrappers without reducing bug risk or clarifying ownership.
