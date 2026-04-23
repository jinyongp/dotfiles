# Install Profile Default Tuning

Status: `completed`

Suggested priority: `P12`

## Summary

Revisit the default item sets behind `Minimal`, `Recommended`, and `Full`, and make each profile's scope easier to understand at a glance.
The goal is to reduce unnecessary item editing while keeping profile selection fast.

## Why this matters

Profiles only save time if their defaults feel trustworthy.
As the installer becomes more plan-driven, hidden or surprising defaults increase the chance that users either over-install or immediately branch into manual review.

## Proposed direction

- Audit the current default package, plugin, font, and desktop-app selections for each profile.
- Add lightweight profile cues such as counts, included-category hints, or similar at-a-glance summaries where that improves clarity.
- Keep profile defaults editable rather than turning them into rigid presets.
- Avoid changing direct install behavior while tuning interactive profile defaults.

## Success signals

- `Recommended` and `Full` need fewer follow-up edits for typical machines.
- Users can infer what a profile roughly includes before confirming it.
- Profile selection remains faster than going through full manual module and item review.

## Notes / dependencies

- This work should follow summary-stage edit improvements so profile defaults are easier to tune safely.
- It should preserve the current dependency resolution and installed-item disabling behavior.
- Any visual changes should align with the existing prompt style rather than introducing a separate profile UI system.
