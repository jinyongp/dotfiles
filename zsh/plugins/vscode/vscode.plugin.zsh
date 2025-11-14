if (( ! $+commands[code] )); then
  return
fi

if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  . "$(code --locate-shell-integration-path zsh)"
fi
