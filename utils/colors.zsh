#!/bin/zsh

# Reset
reset="\033[0m"

# Foreground
black      (){ printf "\033[0;30m$*$reset"; }
red        (){ printf "\033[0;31m$*$reset"; }
green      (){ printf "\033[0;32m$*$reset"; }
yellow     (){ printf "\033[0;33m$*$reset"; }
blue       (){ printf "\033[0;34m$*$reset"; }
purple     (){ printf "\033[0;35m$*$reset"; }
cyan       (){ printf "\033[0;36m$*$reset"; }
white      (){ printf "\033[0;37m$*$reset"; }

# Bold
b_black    (){ printf "\033[1;30m$*$reset"; }
b_red      (){ printf "\033[1;31m$*$reset"; }
b_green    (){ printf "\033[1;32m$*$reset"; }
b_yellow   (){ printf "\033[1;33m$*$reset"; }
b_blue     (){ printf "\033[1;34m$*$reset"; }
b_purple   (){ printf "\033[1;35m$*$reset"; }
b_cyan     (){ printf "\033[1;36m$*$reset"; }
b_white    (){ printf "\033[1;37m$*$reset"; }

# Transparent
t_black    (){ printf "\033[2;30m$*$reset"; }
t_red      (){ printf "\033[2;31m$*$reset"; }
t_green    (){ printf "\033[2;32m$*$reset"; }
t_yellow   (){ printf "\033[2;33m$*$reset"; }
t_blue     (){ printf "\033[2;34m$*$reset"; }
t_purple   (){ printf "\033[2;35m$*$reset"; }
t_cyan     (){ printf "\033[2;36m$*$reset"; }
t_white    (){ printf "\033[2;37m$*$reset"; }

# Italic
i_black    (){ printf "\033[3;30m$*$reset"; }
i_red      (){ printf "\033[3;31m$*$reset"; }
i_green    (){ printf "\033[3;32m$*$reset"; }
i_yellow   (){ printf "\033[3;33m$*$reset"; }
i_blue     (){ printf "\033[3;34m$*$reset"; }
i_purple   (){ printf "\033[3;35m$*$reset"; }
i_cyan     (){ printf "\033[3;36m$*$reset"; }
i_white    (){ printf "\033[3;37m$*$reset"; }

# Underline
u_black    (){ printf "\033[4;30m$*$reset"; }
u_red      (){ printf "\033[4;31m$*$reset"; }
u_green    (){ printf "\033[4;32m$*$reset"; }
u_yellow   (){ printf "\033[4;33m$*$reset"; }
u_blue     (){ printf "\033[4;34m$*$reset"; }
u_purple   (){ printf "\033[4;35m$*$reset"; }
u_cyan     (){ printf "\033[4;36m$*$reset"; }
u_white    (){ printf "\033[4;37m$*$reset"; }

# Background
bg_black   (){ printf "\033[40m$*$reset"; }
bg_red     (){ printf "\033[41m$*$reset"; }
bg_green   (){ printf "\033[42m$*$reset"; }
bg_yellow  (){ printf "\033[43m$*$reset"; }
bg_blue    (){ printf "\033[44m$*$reset"; }
bg_purple  (){ printf "\033[45m$*$reset"; }
bg_cyan    (){ printf "\033[46m$*$reset"; }
bg_white   (){ printf "\033[47m$*$reset"; }
