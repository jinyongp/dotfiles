catalog::module_records() {
  local platform="$1"

  cat <<'EOF'
packages	Base CLI	Install optional CLI packages like jq, gh, fd, eza, tldr, gnupg, and diff-so-fancy.	0	0
dotfiles	Dotfiles	Create symlinks for ~/.zshrc, ~/.vimrc, and ~/.gitconfig, and prepare local Git config files.	1	0
oh_my_zsh	oh-my-zsh	Install the oh-my-zsh framework and optionally clone extra plugins.	1	0
vim	Vim	Install Vim and bootstrap the existing Vundle-based setup.	0	0
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
    vim) echo "Vim" ;;
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
  cat <<'EOF'
jq
gh
fd
eza
tldr
gnupg
diff-so-fancy
EOF
}

catalog::package_native_name() {
  local package_manager="$1"
  local package_id="$2"

  case "$package_manager:$package_id" in
    brew:jq) echo "jq" ;;
    brew:gh) echo "gh" ;;
    brew:fd) echo "fd" ;;
    brew:eza) echo "eza" ;;
    brew:tldr) echo "tlrc" ;;
    brew:gnupg) echo "gnupg" ;;
    brew:diff-so-fancy) echo "diff-so-fancy" ;;
    apt:jq) echo "jq" ;;
    apt:gh) echo "gh" ;;
    apt:fd) echo "fd-find" ;;
    apt:eza) echo "eza" ;;
    apt:tldr) echo "tealdeer" ;;
    apt:gnupg) echo "gnupg" ;;
    apt:diff-so-fancy) echo "diff-so-fancy" ;;
  esac
}

catalog::package_records() {
  local package_manager="$1"
  local package_id native_name label description

  while IFS= read -r package_id; do
    [[ -n "$package_id" ]] || continue
    native_name="$(catalog::package_native_name "$package_manager" "$package_id")"

    case "$package_id" in
      jq)
        label="jq"
        description="Command-line JSON processor."
        ;;
      gh)
        label="GitHub CLI"
        description="GitHub command-line client."
        ;;
      fd)
        label="fd"
        description="Fast file finder. Uses $native_name on $package_manager."
        ;;
      eza)
        label="eza"
        description="Modern replacement for ls."
        ;;
      tldr)
        label="tldr"
        description="Community-maintained command examples. Uses $native_name on $package_manager."
        ;;
      gnupg)
        label="GnuPG"
        description="GPG tooling for signing and encryption."
        ;;
      diff-so-fancy)
        label="diff-so-fancy"
        description="Nicer Git diff presentation."
        ;;
    esac

    printf '%s\t%s\t%s\t0\t0\n' "$package_id" "$label" "$description"
  done < <(catalog::package_ids)
}

catalog::package_label() {
  case "$1" in
    jq) echo "jq" ;;
    gh) echo "GitHub CLI" ;;
    fd) echo "fd" ;;
    eza) echo "eza" ;;
    tldr) echo "tldr" ;;
    gnupg) echo "GnuPG" ;;
    diff-so-fancy) echo "diff-so-fancy" ;;
  esac
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
  cat <<'EOF'
font-fira-code-nerd-font
font-victor-mono-nerd-font
bundled-firacodeiscript
bundled-monocraft
EOF
}

catalog::font_kind() {
  case "$1" in
    font-fira-code-nerd-font|font-victor-mono-nerd-font) echo "cask" ;;
    bundled-firacodeiscript|bundled-monocraft) echo "bundled" ;;
  esac
}

catalog::font_source() {
  case "$1" in
    font-fira-code-nerd-font) echo "font-fira-code-nerd-font" ;;
    font-victor-mono-nerd-font) echo "font-victor-mono-nerd-font" ;;
    bundled-firacodeiscript) echo "FiraCodeiScript" ;;
    bundled-monocraft) echo "Monocraft" ;;
  esac
}

catalog::font_records() {
  cat <<'EOF'
font-fira-code-nerd-font	Fira Code Nerd Font	Homebrew cask font for terminal glyph coverage.	1	0
font-victor-mono-nerd-font	Victor Mono Nerd Font	Homebrew cask font for terminal glyph coverage.	1	0
bundled-firacodeiscript	FiraCodeiScript (bundled)	Copy the bundled FiraCodeiScript font family into ~/Library/Fonts.	0	0
bundled-monocraft	Monocraft (bundled)	Copy the bundled Monocraft font family into ~/Library/Fonts.	0	0
EOF
}

catalog::font_label() {
  case "$1" in
    font-fira-code-nerd-font) echo "Fira Code Nerd Font" ;;
    font-victor-mono-nerd-font) echo "Victor Mono Nerd Font" ;;
    bundled-firacodeiscript) echo "FiraCodeiScript (bundled)" ;;
    bundled-monocraft) echo "Monocraft (bundled)" ;;
  esac
}

catalog::desktop_app_ids() {
  cat <<'EOF'
arc
iterm2
raycast
keka
kekaexternalhelper
karabiner-elements
visual-studio-code
EOF
}

catalog::desktop_app_records() {
  cat <<'EOF'
arc	Arc	Arc browser via Homebrew cask.	0	0
iterm2	iTerm2	iTerm2 terminal emulator via Homebrew cask.	0	0
raycast	Raycast	Raycast launcher via Homebrew cask.	0	0
keka	Keka	Keka archive utility via Homebrew cask.	0	0
kekaexternalhelper	KekaExternalHelper	Keka helper app via Homebrew cask.	0	0
karabiner-elements	Karabiner-Elements	Keyboard remapping utility via Homebrew cask.	0	0
visual-studio-code	Visual Studio Code	VS Code editor via Homebrew cask.	0	0
EOF
}

catalog::desktop_app_label() {
  case "$1" in
    arc) echo "Arc" ;;
    iterm2) echo "iTerm2" ;;
    raycast) echo "Raycast" ;;
    keka) echo "Keka" ;;
    kekaexternalhelper) echo "KekaExternalHelper" ;;
    karabiner-elements) echo "Karabiner-Elements" ;;
    visual-studio-code) echo "Visual Studio Code" ;;
  esac
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
