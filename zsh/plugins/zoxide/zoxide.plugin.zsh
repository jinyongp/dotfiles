if (( ! $+commands[pnpm] )); then
  return
fi

eval "$(zoxide init zsh)"
