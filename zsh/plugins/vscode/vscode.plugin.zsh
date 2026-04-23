if (( ! $+commands[code] )); then
  return
fi

if [[ "$TERM_PROGRAM" == "vscode" && "${VSCODE_INJECTION:-0}" != "1" && -z "${VSCODE_SHELL_INTEGRATION:-}" ]]; then
  vscode_shell_integration_path="$(code --locate-shell-integration-path zsh 2>/dev/null || true)"
  if [[ -n "$vscode_shell_integration_path" && -r "$vscode_shell_integration_path" ]]; then
    source "$vscode_shell_integration_path"
  fi
  unset vscode_shell_integration_path
fi
