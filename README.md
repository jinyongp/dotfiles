# My Custom Dotfiles

## Install

First, clone this repository.

```sh
$ git clone https://github.com/jinyongp/dotfiles.git ~/dotfiles
```

Run `install.sh` to copy(symlink) all of the dotfiles in home directory.

```sh
$ ~/dotfiles/install.sh
```

>The files that already existed are backed up in `dotfiles/.backup` directory.

## Setup

### Oh My Zsh

[Install Oh My Zsh](https://ohmyz.sh/#install)

Install external plugins for oh-my-zsh.


   1. [alias-tips](https://github.com/djui/alias-tips#oh-my-zsh)
   2. [direnv](https://github.com/direnv/direnv/blob/master/docs/installation.md#installation)
   3. [thefuck](https://github.com/nvbn/thefuck#installation)
   4. [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh)
   5. [zsh-completions](https://github.com/zsh-users/zsh-completions#oh-my-zsh)
   6. [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#oh-my-zsh)
   7. [conda-zsh-completion](https://github.com/esc/conda-zsh-completion/blob/382d840f7ad053b3b2ccf0b1f52b26bdabaf66b3/_conda#L24)
   8. [git-flow-completion](https://github.com/bobthecow/git-flow-completion#installation-for-zsh)
   9. [zsh-better-npm-completion](https://github.com/lukechilds/zsh-better-npm-completion#as-an-oh-my-zsh-custom-plugin)

Run command `$ omz reload` to load `~/.zshrc`.

>You can disable some plugins that you don't need by running command `$ omz plugins disable <plugin-name>`.
>Or, find `plugins` array from `~/.zshrc` and delete the corresponding items.

### VundleVim

- [Install VundleVim](https://github.com/VundleVim/Vundle.vim#quick-start)

- Run command [`$ vundle`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/vundle) to install plugins.