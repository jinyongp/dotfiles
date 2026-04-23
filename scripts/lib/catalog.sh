#!/usr/bin/env bash

if [[ -z "${DOTFILES_CATALOG_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    DOTFILES_CATALOG_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    DOTFILES_CATALOG_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

catalog::__lib_dir() {
  [[ -n "${DOTFILES_CATALOG_LIB_DIR:-}" ]] || return 1
  printf '%s' "$DOTFILES_CATALOG_LIB_DIR"
}

catalog::__source_data() {
  local data_path=""
  local lib_dir=""

  if typeset -f catalog_data::package_rows >/dev/null 2>&1; then
    return 0
  fi

  if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/catalog-data.sh" ]]; then
    data_path="$DOTFILES_ROOT/scripts/lib/catalog-data.sh"
  else
    lib_dir="$(catalog::__lib_dir)" || return 1
    data_path="$lib_dir/catalog-data.sh"
  fi

  # shellcheck disable=SC1090
  source "$data_path"
}

catalog::__source_data || return 1

catalog::__row_field_by_id() {
  local row_function="$1"
  local row_id="$2"
  local field_index="$3"

  "$row_function" | awk -F '\t' -v row_id="$row_id" -v field_index="$field_index" '$1 == row_id { print $field_index; exit }'
}

catalog::profile_label() {
  case "$1" in
    minimal) echo "Minimal" ;;
    recommended) echo "Recommended" ;;
    full) echo "Full" ;;
    custom) echo "Custom" ;;
  esac
}

catalog::profile_default_modules() {
  local profile="$1"
  local platform="$2"

  case "$profile" in
    minimal)
      echo "dotfiles"
      ;;
    recommended)
      echo "dotfiles packages neovim"
      ;;
    full)
      if [[ "$platform" == "macos" ]]; then
        echo "dotfiles packages oh_my_zsh neovim fonts desktop_apps macos_defaults"
      else
        echo "dotfiles packages oh_my_zsh neovim"
      fi
      ;;
    custom)
      echo ""
      ;;
  esac
}

catalog::ids_as_words() {
  local id
  local output=""

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if [[ -n "$output" ]]; then
      output="$output $id"
    else
      output="$id"
    fi
  done < <("$@")

  printf '%s' "$output"
}

catalog::profile_default_item_ids() {
  local profile="$1"
  local module_id="$2"

  case "$profile:$module_id" in
    recommended:packages)
      printf '%s' "jq gh fd eza fnm"
      ;;
    full:packages)
      catalog::ids_as_words catalog::package_ids
      ;;
    full:oh_my_zsh)
      catalog::ids_as_words catalog::omz_plugin_ids
      ;;
    full:fonts)
      catalog::ids_as_words catalog::font_ids
      ;;
    full:desktop_apps)
      catalog::ids_as_words catalog::desktop_app_ids
      ;;
  esac
}

catalog::__count_words() {
  local words="$1"
  local count=0
  local word

  for word in $words; do
    count=$((count + 1))
  done

  printf '%s' "$count"
}

catalog::__count_label() {
  local count="$1"
  local singular="$2"
  local plural="${3:-${singular}s}"

  if [[ "$count" == "1" ]]; then
    printf '%s %s' "$count" "$singular"
  else
    printf '%s %s' "$count" "$plural"
  fi
}

catalog::profile_module_count() {
  local profile="$1"
  local platform="$2"

  catalog::__count_words "$(catalog::profile_default_modules "$profile" "$platform")"
}

catalog::profile_default_item_count() {
  local profile="$1"
  local module_id="$2"
  local platform="${3:-}"

  if [[ -n "$platform" ]] && [[ " $(catalog::profile_default_modules "$profile" "$platform") " != *" $module_id "* ]]; then
    printf '%s' "0"
    return 0
  fi

  catalog::__count_words "$(catalog::profile_default_item_ids "$profile" "$module_id")"
}

catalog::profile_status() {
  local profile="$1"
  local platform="$2"
  local module_count=""
  local package_count=""
  local plugin_count=""
  local font_count=""
  local app_count=""
  local status=""

  if [[ "$profile" == "custom" ]]; then
    printf '%s' "manual"
    return 0
  fi

  module_count="$(catalog::profile_module_count "$profile" "$platform")"
  status="$(catalog::__count_label "$module_count" "module")"

  package_count="$(catalog::profile_default_item_count "$profile" "packages" "$platform")"
  if [[ "$package_count" != "0" ]]; then
    status="$status · $(catalog::__count_label "$package_count" "package")"
  fi

  plugin_count="$(catalog::profile_default_item_count "$profile" "oh_my_zsh" "$platform")"
  if [[ "$plugin_count" != "0" ]]; then
    status="$status · $(catalog::__count_label "$plugin_count" "plugin")"
  fi

  font_count="$(catalog::profile_default_item_count "$profile" "fonts" "$platform")"
  if [[ "$font_count" != "0" ]]; then
    status="$status · $(catalog::__count_label "$font_count" "font")"
  fi

  app_count="$(catalog::profile_default_item_count "$profile" "desktop_apps" "$platform")"
  if [[ "$app_count" != "0" ]]; then
    status="$status · $(catalog::__count_label "$app_count" "app")"
  fi

  printf '%s' "$status"
}

catalog::profile_description() {
  local profile="$1"
  local platform="$2"

  case "$profile" in
    minimal)
      printf '%s' "Dotfiles only."
      ;;
    recommended)
      printf '%s' "Dotfiles + base CLI + Neovim baseline."
      ;;
    full)
      if [[ "$platform" == "macos" ]]; then
        printf '%s' "All visible modules for macOS, with all visible leaf items preselected."
      else
        printf '%s' "All visible modules for this platform, with all visible leaf items preselected."
      fi
      ;;
    custom)
      printf '%s' "Manual module and item selection."
      ;;
  esac
}

catalog::profile_records() {
  local platform="$1"
  local profile_id label description status selected

  for profile_id in minimal recommended full custom; do
    label="$(catalog::profile_label "$profile_id")"
    description="$(catalog::profile_description "$profile_id" "$platform")"
    status="$(catalog::profile_status "$profile_id" "$platform")"
    selected=0

    if [[ "$profile_id" == "recommended" ]]; then
      selected=1
    fi

    printf '%s\t%s\t%s\t%s\t0\t%s\n' "$profile_id" "$label" "$description" "$selected" "$status"
  done
}

catalog::module_records() {
  local platform="$1"

  cat <<'EOF'
dotfiles	Dotfiles	Link ~/.zshenv, ~/.zprofile, ~/.zshrc, ~/.vimrc, ~/.config/nvim, and ~/.gitconfig, then prepare local Git config files.	0	0
packages	Base CLI	Install optional CLI packages like jq, gh, fd, eza, tldr, gnupg, diff-so-fancy, and fnm.	0	0
oh_my_zsh	oh-my-zsh	Install the oh-my-zsh framework and optionally clone extra plugins.	0	0
neovim	Neovim	Install Neovim with search tooling and optional TypeScript editor extras.	0	0
EOF

  if [[ "$platform" == "macos" ]]; then
    cat <<'EOF'
fonts	Fonts	Install selected terminal fonts and optional bundled font families.	0	0
desktop_apps	Desktop Apps	Install selected macOS desktop applications via Homebrew cask.	0	0
macos_defaults	macOS Defaults	Apply the bundled macOS keybinding defaults.	0	0
EOF
  fi
}

catalog::module_label() {
  case "$1" in
    packages) echo "Base CLI" ;;
    dotfiles) echo "Dotfiles" ;;
    oh_my_zsh) echo "oh-my-zsh" ;;
    neovim) echo "Neovim" ;;
    fonts) echo "Fonts" ;;
    desktop_apps) echo "Desktop Apps" ;;
    macos_defaults) echo "macOS Defaults" ;;
  esac
}

catalog::module_is_leaf() {
  case "$1" in
    packages|oh_my_zsh|fonts|desktop_apps) return 0 ;;
    *) return 1 ;;
  esac
}

catalog::theme_records() {
  cat <<'EOF'
starship	starship	Cross-platform prompt using the Starship binary.	1	0
powerlevel10k	powerlevel10k	oh-my-zsh theme with the powerlevel10k repository.	0	0
default	default	Use oh-my-zsh's built-in robbyrussell theme.	0	0
none	none	Do not enable a prompt theme.	0	0
EOF
}

catalog::theme_label() {
  case "$1" in
    starship) echo "starship" ;;
    powerlevel10k) echo "powerlevel10k" ;;
    default) echo "default" ;;
    none) echo "none" ;;
  esac
}

catalog::package_ids() {
  catalog_data::package_rows | awk -F '\t' '$3 == "1" { print $1 }'
}

catalog::package_native_name() {
  local package_manager="$1"
  local package_id="$2"

  case "$package_manager" in
    brew) catalog::__row_field_by_id catalog_data::package_rows "$package_id" 6 ;;
    apt) catalog::__row_field_by_id catalog_data::package_rows "$package_id" 7 ;;
  esac
}

catalog::package_command_name() {
  local package_manager="$1"
  local package_id="$2"

  case "$package_manager" in
    brew) catalog::__row_field_by_id catalog_data::package_rows "$package_id" 4 ;;
    apt) catalog::__row_field_by_id catalog_data::package_rows "$package_id" 5 ;;
  esac
}

catalog::package_records() {
  local package_manager="$1"

  catalog_data::package_rows | awk -F '\t' -v package_manager="$package_manager" '
    $3 == "1" {
      description = (package_manager == "apt" ? $9 : $8)
      printf "%s\t%s\t%s\t0\t0\n", $1, $2, description
    }
  '
}

catalog::package_label() {
  catalog::__row_field_by_id catalog_data::package_rows "$1" 2
}

catalog::omz_plugin_ids() {
  cat <<'EOF'
alias-tips
zsh-completions
zsh-autosuggestions
zsh-better-npm-completion
autoupdate
fast-syntax-highlighting
EOF
}

catalog::omz_plugin_repo() {
  case "$1" in
    alias-tips) echo "djui/alias-tips" ;;
    zsh-completions) echo "zsh-users/zsh-completions" ;;
    zsh-autosuggestions) echo "zsh-users/zsh-autosuggestions" ;;
    zsh-better-npm-completion) echo "lukechilds/zsh-better-npm-completion" ;;
    autoupdate) echo "tamcore/autoupdate-oh-my-zsh-plugins" ;;
    fast-syntax-highlighting) echo "zdharma-continuum/fast-syntax-highlighting" ;;
  esac
}

catalog::omz_plugin_records() {
  cat <<'EOF'
alias-tips	alias-tips	Show alias suggestions after matching commands.	0	0
zsh-completions	zsh-completions	Extra completions for common tools.	1	0
zsh-autosuggestions	zsh-autosuggestions	Show history-based suggestions while typing.	1	0
zsh-better-npm-completion	zsh-better-npm-completion	Better npm and package completion.	0	0
autoupdate	autoupdate	Periodic update reminder plugin for oh-my-zsh.	0	0
fast-syntax-highlighting	fast-syntax-highlighting	Fast command-line syntax highlighting.	1	0
EOF
}

catalog::omz_plugin_label() {
  case "$1" in
    alias-tips) echo "alias-tips" ;;
    zsh-completions) echo "zsh-completions" ;;
    zsh-autosuggestions) echo "zsh-autosuggestions" ;;
    zsh-better-npm-completion) echo "zsh-better-npm-completion" ;;
    autoupdate) echo "autoupdate" ;;
    fast-syntax-highlighting) echo "fast-syntax-highlighting" ;;
  esac
}

catalog::font_ids() {
  catalog_data::font_rows | awk -F '\t' '{ print $1 }'
}

catalog::font_kind() {
  catalog::__row_field_by_id catalog_data::font_rows "$1" 3
}

catalog::font_source() {
  catalog::__row_field_by_id catalog_data::font_rows "$1" 4
}

catalog::font_records() {
  local font_id label kind source description

  while IFS=$'\t' read -r font_id label kind source description; do
    [[ -n "$font_id" ]] || continue
    printf '%s\t%s\t%s\t0\t0\n' "$font_id" "$label" "$description"
  done < <(catalog_data::font_rows)
}

catalog::font_label() {
  catalog::__row_field_by_id catalog_data::font_rows "$1" 2
}

catalog::desktop_app_ids() {
  catalog_data::desktop_app_rows | awk -F '\t' '{ print $1 }'
}

catalog::desktop_app_source() {
  catalog::__row_field_by_id catalog_data::desktop_app_rows "$1" 3
}

catalog::desktop_app_records() {
  local app_id label source description

  while IFS=$'\t' read -r app_id label source description; do
    [[ -n "$app_id" ]] || continue
    printf '%s\t%s\t%s\t0\t0\n' "$app_id" "$label" "$description"
  done < <(catalog_data::desktop_app_rows)
}

catalog::desktop_app_label() {
  catalog::__row_field_by_id catalog_data::desktop_app_rows "$1" 2
}

catalog::item_label() {
  local module="$1"
  local item_id="$2"

  case "$module" in
    packages) catalog::package_label "$item_id" ;;
    oh_my_zsh) catalog::omz_plugin_label "$item_id" ;;
    fonts) catalog::font_label "$item_id" ;;
    desktop_apps) catalog::desktop_app_label "$item_id" ;;
  esac
}
