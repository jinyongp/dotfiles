if (( ! $+commands[fnm] )); then
  return
fi

source <(fnm env --use-on-cd --shell zsh --version-file-strategy=recursive)
