# Non-Interactive Zsh Bootstrap

Status: `completed`
Suggested priority: `P1`

## Summary

Make non-interactive `zsh` startup expose the same minimal Node toolchain as interactive shells.
The target is reliable `brew`, `fnm`, `node`, `npm`, and `pnpm` discovery without depending on `.zshrc`.

## Why this matters

The current dotfiles layout puts Homebrew and `fnm` activation behind the repo-managed `.zshrc` path.
That works for normal interactive terminal sessions, but it breaks for non-interactive `zsh` entrypoints because `.zshrc` is not loaded there.

This mismatch is especially visible in installer or automation flows that rely on `zsh` but do not start an interactive shell first.
It also creates platform drift between environments where Homebrew is already available in `.zprofile` and environments where it is not.

## Proposed direction

- Introduce a minimal shared bootstrap for non-interactive-safe shell environment setup.
- Move only environment-safe startup into repo-managed `.zshenv` and `.zprofile`.
- Keep themes, aliases, completions, `oh-my-zsh`, and other interactive behavior in `.zshrc`.
- Split base `fnm` activation from interactive-only `--use-on-cd` behavior.
- Update installer-managed shell entrypoints and documentation so the repo owns `~/.zshenv`, `~/.zprofile`, and `~/.zshrc` together.

## Success signals

- `zsh -lc` can resolve `brew`, `fnm`, `node`, `npm`, and `pnpm` without relying on an already-initialized parent shell.
- `zsh -c` and `zsh <script>` see the same minimal toolchain bootstrap.
- Interactive shell UX remains unchanged apart from the environment bootstrap moving earlier in startup.

## Notes / dependencies

- Keep `.zshenv` minimal because it runs for every `zsh` process.
- This work should document new machine-local override locations for universal and login-only shell additions.
- The top-level README should be updated after the shell bootstrap contract is finalized.
- Completed by adding repo-managed zsh bootstrap entrypoints and `scripts/tests/zsh-bootstrap.sh`.
