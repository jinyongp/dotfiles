#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

export DOTFILES_ROOT

source "$DOTFILES_ROOT/scripts/lib/catalog.sh"

catalog_metadata_test::fail() {
  printf 'catalog-metadata: %s\n' "$1" >&2
  exit 1
}

catalog_metadata_test::assert_equal() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    catalog_metadata_test::fail "$message"
  fi
}

catalog_metadata_test::assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  printf '%s\n' "$haystack" | grep -Fq -- "$needle" || catalog_metadata_test::fail "$message"
}

catalog_metadata_test::assert_package_ids() {
  local package_ids

  package_ids="$(catalog::package_ids | paste -sd' ' -)"
  catalog_metadata_test::assert_equal "$package_ids" "jq gh fd eza fzf zoxide tldr gnupg diff-so-fancy fnm" "unexpected visible package ids"

  if catalog::package_ids | grep -Fxq git; then
    catalog_metadata_test::fail "internal dependency package should not be visible in package_ids"
  fi

  if ! catalog_data::package_rows | awk -F '\t' '$1 == "git" { found=1 } END { exit(found ? 0 : 1) }'; then
    catalog_metadata_test::fail "expected internal dependency package metadata for git"
  fi

  printf 'ok package_ids\n'
}

catalog_metadata_test::assert_package_native_names() {
  catalog_metadata_test::assert_equal "$(catalog::package_native_name brew fd)" "fd" "expected brew fd mapping"
  catalog_metadata_test::assert_equal "$(catalog::package_native_name apt fd)" "fd-find" "expected apt fd mapping"
  catalog_metadata_test::assert_equal "$(catalog::package_native_name brew tldr)" "tlrc" "expected brew tldr mapping"
  catalog_metadata_test::assert_equal "$(catalog::package_native_name apt tldr)" "tealdeer" "expected apt tldr mapping"
  catalog_metadata_test::assert_equal "$(catalog::package_native_name brew git)" "git" "expected brew git mapping"
  catalog_metadata_test::assert_equal "$(catalog::package_native_name apt starship)" "starship" "expected apt starship mapping"
  printf 'ok package_native_names\n'
}

catalog_metadata_test::assert_package_command_names() {
  catalog_metadata_test::assert_equal "$(catalog::package_command_name apt fd)" "fdfind" "expected apt fd command name"
  catalog_metadata_test::assert_equal "$(catalog::package_command_name brew gnupg)" "gpg" "expected gnupg command name"
  catalog_metadata_test::assert_equal "$(catalog::package_command_name brew tldr)" "tldr" "expected brew tldr command name"
  catalog_metadata_test::assert_equal "$(catalog::package_command_name apt tldr)" "tldr" "expected apt tldr command name"
  catalog_metadata_test::assert_equal "$(catalog::package_command_name brew neovim)" "nvim" "expected neovim command name"
  printf 'ok package_command_names\n'
}

catalog_metadata_test::assert_package_records() {
  local brew_records apt_records

  brew_records="$(catalog::package_records brew)"
  apt_records="$(catalog::package_records apt)"

  catalog_metadata_test::assert_contains "$brew_records" $'fd\tfd\tFast file finder. Uses fd on brew.\t0\t0' "missing brew fd record"
  catalog_metadata_test::assert_contains "$apt_records" $'fd\tfd\tFast file finder. Uses fd-find on apt.\t0\t0' "missing apt fd record"
  catalog_metadata_test::assert_contains "$brew_records" $'fzf\tfzf\tCommand-line fuzzy finder.\t0\t0' "missing brew fzf record"
  catalog_metadata_test::assert_contains "$apt_records" $'zoxide\tzoxide\tSmarter cd command with frecency.\t0\t0' "missing apt zoxide record"
  catalog_metadata_test::assert_contains "$brew_records" $'tldr\ttldr\tCommunity-maintained command examples. Uses tlrc on brew.\t0\t0' "missing brew tldr record"
  catalog_metadata_test::assert_contains "$apt_records" $'tldr\ttldr\tCommunity-maintained command examples. Uses tealdeer on apt.\t0\t0' "missing apt tldr record"
  catalog_metadata_test::assert_contains "$brew_records" $'fnm\tfnm\tFast Node.js version manager via Homebrew.\t0\t0' "missing brew fnm record"
  catalog_metadata_test::assert_contains "$apt_records" $'fnm\tfnm\tFast Node.js version manager via the official install script.\t0\t0' "missing apt fnm record"
  printf 'ok package_records\n'
}

catalog_metadata_test::assert_font_and_desktop_sources() {
  catalog_metadata_test::assert_equal "$(catalog::font_kind font-fira-code-nerd-font)" "cask" "expected cask font kind"
  catalog_metadata_test::assert_equal "$(catalog::font_kind bundled-monocraft)" "bundled" "expected bundled font kind"
  catalog_metadata_test::assert_equal "$(catalog::font_source font-victor-mono-nerd-font)" "font-victor-mono-nerd-font" "expected font cask source"
  catalog_metadata_test::assert_equal "$(catalog::font_source bundled-firacodeiscript)" "FiraCodeiScript" "expected bundled font source"
  catalog_metadata_test::assert_equal "$(catalog::desktop_app_source arc)" "arc" "expected desktop app source"
  catalog_metadata_test::assert_equal "$(catalog::desktop_app_source visual-studio-code)" "visual-studio-code" "expected desktop app source"
  catalog_metadata_test::assert_equal "$(catalog::desktop_app_source kekaexternalhelper)" "kekaexternalhelper" "expected hidden desktop app source"
  if catalog::desktop_app_ids | grep -Fxq kekaexternalhelper; then
    catalog_metadata_test::fail "required helper app should not be visible in desktop_app_ids"
  fi
  printf 'ok font_and_desktop_sources\n'
}

catalog_metadata_test::assert_required_item_metadata() {
  catalog_metadata_test::assert_equal "$(catalog::required_item_ids packages zoxide)" "fzf" "expected zoxide package dependency"
  catalog_metadata_test::assert_equal "$(catalog::required_item_ids desktop_apps keka)" "kekaexternalhelper" "expected Keka helper dependency"
  catalog_metadata_test::assert_equal "$(catalog::required_item_reason packages zoxide fzf)" "zoxide requires fzf for interactive selection." "expected zoxide dependency reason"
  printf 'ok required_item_metadata\n'
}

catalog_metadata_test::main() {
  catalog_metadata_test::assert_package_ids
  catalog_metadata_test::assert_package_native_names
  catalog_metadata_test::assert_package_command_names
  catalog_metadata_test::assert_package_records
  catalog_metadata_test::assert_font_and_desktop_sources
  catalog_metadata_test::assert_required_item_metadata
  printf 'all catalog metadata tests passed\n'
}

catalog_metadata_test::main "$@"
