---
name: git-commit
description: Use when user asks commit/stage/unstage/split commits/draft commit msg. Inspect full worktree by default, group changes into behavior commits, protect secrets/accidental files, keep user-excluded scope untouched.
compatibility: Requires git CLI + shell in repo worktree.
allowed-tools: Bash(git:*) Bash(cat:*) Bash(sed:*) Bash(grep:*) Bash(file:*) Bash(mktemp:*) Bash(wc:*) Read
metadata:
  version: "2.0.0"
---

# Git Commit

Make repo-fit commits from current worktree.

## Bounds

Use only for commit/stage/unstage/split/msg draft. Not generic Git/branch/rebase/squash/publish unless user asks.

Defaults:
- scope = all tracked + untracked unless user narrows
- user scope wins; staged state = draft
- no source edits unless asked
- no amend/squash/reset/force-push/history rewrite unless explicit

Stop if: not Git repo, conflicts/merge/rebase/cherry-pick not requested, detached `HEAD` not accepted, in-scope secret/local config, out-of-scope staged changes cannot separate, hooks/validation fail.

Risk files: `.env`, `.npmrc`, `.pypirc`, cloud creds, private keys, tokens, passwords, IDE files, caches, large binaries, ignored `-f`.

## Inspect

From root:

```bash
git rev-parse --show-toplevel
git status --short --branch
git diff --stat
git diff --cached --stat
git diff
git diff --cached
git ls-files --others --exclude-standard
git diff --name-only --diff-filter=U
git log --format='%h %s' -n 20
git log --format='%B%x00' -n 5
git config --show-origin --get-all commit.template
```

Template exists? Read file. Non-comment text = msg constraint.

Untracked/large/binary before stage:

```bash
file -- <path>
wc -c -- <path>
sed -n '1,200p' -- <path>
```

## Scope / Group

Narrowed scope:
1. Candidate = named paths/hunks/concerns only.
2. Leave others uncommitted.
3. Out-of-scope staged => no normal `git commit`.
4. Non-overlap clear: save cached patch, unstage, commit scoped, reapply, verify.
5. Overlap/ambiguous => report conflict.

Group by behavior. Keep code/tests/fixtures/generated/docs/config together when one logical change. Split independent concerns even same file. Prereqs first. Read diffs, not names/stats.

## Stage / Validate / Commit

For each group:
1. Compare staged/unstaged.
2. Stage only group files/hunks (`git add -p` or `git apply --cached`).
3. Never `git add -f` ignored file unless user named it.
4. Verify:

```bash
git diff --cached --stat
git diff --cached
git diff --cached --check
```

Unrelated hunks staged? Fix index first.

Message: follow history/template. Prefer recent dominant style; `type(scope): verb phrase` if fits. Imperative subject. No file list/trailing period. Body only for why/migration/constraints/validation/side effects. Commit via temp file + `git commit -F <file>`.

Run cheap relevant checks when obvious. Never claim pass unless run + succeeded. No `--no-verify` unless asked; final says bypassed.

Loop until in-scope committed or blocked. After each commit:

```bash
git status --short
git diff --stat
git diff --cached --stat
git log --oneline -n 5
```

## Final

Report commits hash+subject, grouping, validation/hooks, in-scope left+why, out-of-scope untouched. No commit? exact reason + status.
