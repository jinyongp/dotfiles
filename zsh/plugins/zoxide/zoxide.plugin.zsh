if (( ! $+commands[zoxide] )); then
  return
fi

eval "$(zoxide init zsh)"
