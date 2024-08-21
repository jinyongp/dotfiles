if (( ! $+commands[gh] )); then
  return
fi

if ! gh copilot -v &>/dev/null; then
  return
fi

alias 'e?'="gh copilot explain"
alias 's?'="gh copilot suggest"
