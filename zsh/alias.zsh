if exists git; then
  alias gpft="git push --follow-tags"
  alias 'gcm!'="gc! -m"
  alias 'gcmsg!'="gc! --message"
fi

if exists eza; then
  alias ls="eza --classify --icons --color=automatic --header --sort=type --git --show-symlinks"
  alias la="ls --all --long"
  alias lsd="ls --only-dirs"
  alias lst="eza --reverse --tree"
fi

if exists npm; then
  alias npv="npm --no-git-tag-version version"
fi

if open -Ra "Xcode"; then
  alias xcode="open -a Xcode"
fi
