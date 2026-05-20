# caveman

Smart terse mode. Same brain, fewer tokens.

## What it does

Compress responses. Drop filler, pleasantries, hedging. Keep technical details, code blocks, errors, symbols exact.

Repeated lists compress hard: group common prefixes, use tree/glob/range when clearer.

Modes:

| Level | What change |
|-------|-------------|
| `lite` | Full sentences, no filler/hedging. |
| `full` | Default. Fragments OK, articles dropped. |

## Invoke

```bash
/caveman
/caveman lite
stop caveman
normal mode
```

## Example

Normal:
> Your component re-renders because you create a new object reference each render. Wrapping it in `useMemo` will fix the issue.

Full:
> New object ref each render. Inline object prop = new ref = re-render. Wrap in `useMemo`.
