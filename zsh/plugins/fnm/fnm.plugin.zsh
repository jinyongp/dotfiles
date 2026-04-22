if [[ -n "${XDG_DATA_HOME:-}" ]]; then
  dotfiles_prepend_path "$XDG_DATA_HOME/fnm"
elif [[ "$DOTFILES_PLATFORM" == "macos" ]]; then
  dotfiles_prepend_path "$HOME/Library/Application Support/fnm"
else
  dotfiles_prepend_path "$HOME/.local/share/fnm"
fi

if (( ! $+commands[fnm] )); then
  return
fi

typeset -g _fnm_runtime_dir="${XDG_RUNTIME_DIR:-}"

if [[ -z "$_fnm_runtime_dir" || ! -d "$_fnm_runtime_dir" || ! -w "$_fnm_runtime_dir" ]]; then
  _fnm_runtime_dir="${TMPDIR:-/tmp}/fnm-runtime-${UID}"
  mkdir -p "$_fnm_runtime_dir" || return
  chmod 700 "$_fnm_runtime_dir" 2>/dev/null || true
fi

source <(XDG_RUNTIME_DIR="$_fnm_runtime_dir" fnm env --use-on-cd --shell zsh --version-file-strategy=recursive)

unset _fnm_runtime_dir
