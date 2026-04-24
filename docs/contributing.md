# Contributing

## Commit Messages

All commits in this repository use Conventional Commits.

Use this subject format:

```text
type(scope)!: description
```

The scope and `!` are optional.

Examples:

```text
feat(installer): add profile-based install planning
fix(hooks): validate pushed WIP ranges
docs: update installer usage notes
refactor(prompt)!: simplify prompt state handling
```

Allowed types:

- `feat`: a new feature
- `fix`: a bug fix
- `docs`: documentation-only changes
- `style`: formatting or style changes that do not affect behavior
- `refactor`: code changes that neither fix a bug nor add a feature
- `perf`: performance improvements
- `test`: adding or updating tests
- `build`: build system or dependency changes
- `ci`: CI configuration or script changes
- `chore`: maintenance tasks that do not change runtime behavior
- `revert`: revert a previous commit

Use the imperative mood in the subject: `add`, `fix`, `update`, not `added` or `fixes`.
Keep the subject concise, ideally 72 characters or less.

For breaking changes, add `!` to the subject and include a footer:

```text
BREAKING CHANGE: describe the required migration
```
