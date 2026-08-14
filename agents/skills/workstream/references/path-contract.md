# Task Identity and Path Contract

Use one canonical identity for every change. Do not infer repository naming
conventions or improvise fallback paths.

## Resolution

1. Settle the one-sentence Goal, artifact depth, and intent source.
2. Read the repository root from survey results: Git top-level for a Git repo;
   otherwise the explicit target directory.
3. Choose exactly one intent source kind:
   - `plan-local`: local `spec.md` supplies Standard/High-risk intent.
   - `authoritative`: pass the exact path, URL, or identifier with
     `--intent-source`; no local `spec.md`.
4. Unless the user supplied an explicit slug, choose a semantic slug base from
   the settled Goal and pass it as `--slug-base`. Use three to five lowercase
   ASCII English tokens that convey the concrete domain/object and outcome.
   Translate meaning from non-English Goals; do not transliterate. Avoid bases
   made only from generic workflow or surface words such as `api`, `ui`,
   `admin`, `ops`, `feature`, `task`, `add`, `update`, or `fix`.
5. Run `scripts/resolve_workstream.py` without `--init` and use its JSON exactly.
   Pass `--intent-source-kind plan-local` or both
   `--intent-source-kind authoritative --intent-source <exact-source>`.
6. Show the resolved slug and work directory before the first artifact write.
7. Run the same command with `--init` to create only the directory and
   `manifest.json` identity manifest.

`--slug-base` is the normal semantic input. The resolver validates it and
appends the Goal hash; agents must not append or calculate that hash. The only
full-slug override is an explicitly user-supplied `--slug`: lowercase ASCII
kebab-case, maximum 63 characters. The root and intermediate directories cannot
be overridden. Never derive a full-slug override from branch names, nearby
folders, issue titles, or a different agent's preference.

## Canonical Defaults

```text
.tasks/
├── taskrc                    # project-local task configuration
├── data/                     # project-local task database
├── aux/                      # exports, backups, diagnostics; created on demand
└── items/
    └── <slug>/
        ├── manifest.json     # immutable identity
        ├── spec.md           # Standard/High-risk, plan-local intent only
        ├── plan.md           # always
        └── validation.md     # execution validation evidence
```

- Task project: `<slug>` with no tool or workflow prefix.
- Use absolute paths from resolver JSON for tool operations. Record only its
  POSIX-style `*_relative` paths in committed artifacts.
- Artifact filenames are fixed. Never add dates, titles, sequence numbers,
  `final`, `v2`, or agent-specific suffixes.
- Authoritative intent omits local `spec.md`; record its exact source without
  trimming or rewriting whitespace or case.
- Plan-only work never creates `validation.md`.
- Create no empty placeholder artifacts.
- In a Git repository, add the exact root rule `/.tasks/` to the root
  `.gitignore` once before initialization. Do not use `.git/info/exclude`, a
  nested ignore file, or a second repo-local state root.

## Slug Algorithm

- Explicit valid `--slug` wins.
- Otherwise, a valid semantic `--slug-base` receives the first ten Goal hash
  digits: `<semantic-base>-<hash10>`.
- Otherwise normalize Goal with Unicode NFKC, collapse whitespace, case-fold,
  and hash with SHA-256. Use up to five ASCII alphanumeric Goal tokens plus the
  first ten hash digits only when those tokens pass the same minimum descriptive
  quality bar. Fail instead of creating `goal-<hash>` or a generic-only name.

The resolver owns validation and hash composition. Agents choose only the
semantic base and must not reproduce the full algorithm manually.

Goal identity is lexical, not semantic. After initialization, never paraphrase
the settled Goal to rediscover a workstream. Resume from the stored slug,
manifest, plan, or active goal Outcome. If none is available, ask which
workstream to resume instead of matching by meaning.

## Reuse and Failure

- Reuse an existing directory only when `manifest.json` exactly matches its
  slug, normalized Goal/hash, schema, depth, intent source, and task project.
- Never auto-migrate an older or unknown manifest schema. Stop for explicit
  migration direction or use an explicit new slug.
- Never scan or adopt legacy `.taskwarrior/` or `.workstreams/` directories.
  Migration requires an explicit user request.
- A non-empty directory without a manifest is unmanaged and must not be adopted.
- A matching slug with a different Goal is a collision. Stop and ask for an
  explicit new slug.
- If the selected path is unavailable or unwritable, stop and report it. Never
  choose the nearest writable directory or append an automatic suffix.
- If the platform cannot provide secure no-follow directory operations, stop;
  never downgrade to an unsafe initialization path.
