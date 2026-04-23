# Catalog Package Metadata Source of Truth

Status: `completed`

Suggested priority: `P10`

## Summary

Define one canonical metadata source for package, cask, font, and desktop-app install records.
The goal is to stop maintaining overlapping labels, IDs, and native package mappings in both the catalog and installer layers.

## Why this matters

The current installer keeps package and cask metadata in more than one place.
That makes it easier for interactive labels, native package names, and direct install behavior to drift apart over time.

## Proposed direction

- Move package-manager-facing metadata and interactive catalog metadata behind one shared source.
- Keep package IDs, labels, native names, and cask names derivable from that shared source instead of duplicating them across files.
- Preserve the existing installer UX and direct install behavior while reducing metadata duplication.

## Success signals

- Package, font, and desktop-app metadata changes happen in one place.
- Interactive prompts and installer execution use the same labels and native package mappings.
- Adding or removing an item no longer requires updating parallel records in multiple libraries.

## Notes / dependencies

- This should cover the overlap between `scripts/lib/catalog.sh` and `scripts/lib/packages.zsh`.
- It should preserve current package-manager-specific behavior, including recipe-based installs such as `fnm`.
- This is an internal cleanup task, not a profile or prompt UX task.
