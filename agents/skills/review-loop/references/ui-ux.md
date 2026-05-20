# UI/UX Fluency Review

Fail if UI exposes API responses, DB fields, or admin property names as raw label-value lists.

UI must translate data into user meaning. Do not stop at "all data visible." A scanning user must understand meaning and next action fast.

## Data-to-UI Checks

Before accepting UI, verify data is reorganized around user thinking:

- Core object: what is this screen/card/row about?
- Time/status: when, and what stage?
- Cost/risk/success/failure: what values change judgment?
- Relationship: origin/destination, before/after, parent/child, cause/effect?
- Next action: what should user do now?

## Flag

- `Object.entries(data)` or equivalent raw field rendering in user-facing UI
- API/DB/admin labels shown as primary UI labels, e.g. `restaurant`, `item`, `pickup_from`
- Equal visual weight for every field
- Screens requiring user to mentally join fields before meaning is clear
- Repeated labels where position, group, icon, sequence, or hierarchy could carry meaning

## Require

- Core object strongest visual element
- Time, status, and helper context near core object
- Cost, risk, failure, approval-needed, and irreversible-action values separately emphasized
- Related data shown through structure, sequence, icon, group, or layout, not flat lists
- Labels removed when visual structure already explains meaning

## Example

For order fields:

- `restaurant`
- `item`
- `day`
- `time`
- `pickup_from`
- `deliver_to`
- `total_cost`

Do not render as equal label-value rows. Rebuild as event card:

- Title: `item`
- Subtitle: `day`, `time`, status
- Brand/source: restaurant logo/name as supporting context
- Price: `total_cost` emphasized
- Route: pickup -> delivery as ordered locations
- Actions: next user action, if any

Core distinction:

```text
Bad: field-name UI
Good: meaning-first UI
```

Pass only when user can scan and infer what happened, what matters, and what to do next without reading every raw field.
