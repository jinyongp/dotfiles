# Task Backlog

This directory tracks follow-up backlog items for the interactive installer and related script infrastructure.
These documents are intentionally short: they are meant to capture why the work matters, the current direction, and the expected outcome without turning each task into a full implementation spec.

Each task carries its own current status.

| Priority | Status | Task | Summary | File |
| --- | --- | --- | --- | --- |
| P1 | completed | [Non-Interactive Zsh Bootstrap](./noninteractive-zsh-bootstrap.md) | Move minimal shell bootstrap earlier so non-interactive `zsh` can resolve Homebrew and fnm-managed Node tooling. | [noninteractive-zsh-bootstrap.md](./noninteractive-zsh-bootstrap.md) |
| P2 | completed | [Prompt Rendering Snapshots](./prompt-rendering-snapshots.md) | Add automated rendering coverage for the current interactive prompt UI. | [prompt-rendering-snapshots.md](./prompt-rendering-snapshots.md) |
| P3 | completed | [Prompt Layout and Style Separation](./prompt-layout-style-separation.md) | Split prompt layout decisions from prompt styling decisions to make UI tuning safer. | [prompt-layout-style-separation.md](./prompt-layout-style-separation.md) |
| P4 | completed | [Install Responsibility Split](./install-responsibility-split.md) | Break the top-level installer into smaller focused subsystems without changing behavior. | [install-responsibility-split.md](./install-responsibility-split.md) |
| P5 | completed | [Terminal Palette Detection](./terminal-palette-detection.md) | Improve terminal palette detection while keeping default-foreground-first rendering. | [terminal-palette-detection.md](./terminal-palette-detection.md) |
| P6 | completed | [Install Internal Refactor Follow-ups](./install-internal-refactor-followups.md) | Track the second phase after the first installer responsibility split. | [install-internal-refactor-followups.md](./install-internal-refactor-followups.md) |
| P7 | completed | [Install Summary Actions](./install-summary-actions.md) | Let the final plan summary branch back into module, item, and Git edits without restarting the installer. | [install-summary-actions.md](./install-summary-actions.md) |
| P8 | completed | [Install UI Modes](./install-ui-modes.md) | Evaluate plain, compact, and rich installer UI modes for different terminal environments. | [install-ui-modes.md](./install-ui-modes.md) |
| P9 | completed | [Install Execution Progress](./install-execution-progress.md) | Make execution-time install output the next structured layer after the current planning UI. | [install-execution-progress.md](./install-execution-progress.md) |
| P10 | completed | [Catalog Package Metadata Source of Truth](./catalog-package-metadata-source-of-truth.md) | Remove duplicated package, cask, font, and desktop-app metadata across catalog and installer libraries. | [catalog-package-metadata-source-of-truth.md](./catalog-package-metadata-source-of-truth.md) |
| P11 | completed | [Toolchain Runtime Path Parity](./toolchain-runtime-path-parity.md) | Align install-time and shell-bootstrap path rules for Homebrew, fnm, npm global bin, pnpm, and install env files. | [toolchain-runtime-path-parity.md](./toolchain-runtime-path-parity.md) |
| P12 | planned | [Install Profile Default Tuning](./install-profile-default-tuning.md) | Revisit profile defaults and make what each profile includes easier to understand at a glance. | [install-profile-default-tuning.md](./install-profile-default-tuning.md) |
| P13 | planned | [Interactive Installer README Update](./interactive-installer-readme-update.md) | Sync the README with the current interactive installer flow and keyboard interactions. | [interactive-installer-readme-update.md](./interactive-installer-readme-update.md) |
