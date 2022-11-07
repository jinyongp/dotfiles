# My Dotfiles

## Getting Started

Clone this repository.

```sh
$ git clone https://github.com/jinyongp/dotfiles.git ~/dotfiles
```

Run `install.sh` to install all packages and plugins I'm using, and copy(symlink) all of the dotfiles in home directory. All of the installation processes will proceed automatically.

```sh
$ ~/dotfiles/install.sh
```

> The files that already existed are backed up in `.backup` directory.

## Installing packages and plugins

### Homebrew

[Install Homebrew](https://brew.sh) with my favorite packages!

I prefer to install most packages using homebrew as mush as possible.

_Formulae_

```
$ brew install jq bat direnv gnupg exa gh fd
```

_Casks_

```
$ brew install --cask iterm2 miniconda karabiner-elements raycast keka kekaexternalhelper google-chrome macvim visual-studio-code
```

### Oh My Zsh

[Install Oh My Zsh](https://ohmyz.sh/#install) with awesome omz plugins!

- [alias-tips](https://github.com/djui/alias-tips#oh-my-zsh)
- [zsh-completions](https://github.com/zsh-users/zsh-completions#oh-my-zsh)
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh)
- [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting#oh-my-zsh)
- [zsh-better-npm-completion](https://github.com/lukechilds/zsh-better-npm-completion#as-an-oh-my-zsh-custom-plugin)
- [conda-zsh-completion](https://github.com/esc/conda-zsh-completion/blob/382d840f7ad053b3b2ccf0b1f52b26bdabaf66b3/_conda#L24)

I'm using [PowerLevel10K](https://github.com/romkatv/powerlevel10k#oh-my-zsh) theme.

Run command `$ omz reload` to load omz plugins.

### VundleVim

- [Install VundleVim](https://github.com/VundleVim/Vundle.vim#quick-start)
- Run command [`$ vundle`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/vundle) to install vim plugins. (not my concern)

### Assets

- [Install nerd-font](https://github.com/ryanoasis/nerd-fonts#option-4-homebrew-fonts) using homebrew.

  ```sh
  $ brew tap homebrew/cask-fonts
  $ brew install --cask font-fira-code-nerd-font
  ```

- Copy the fonts to `~/Library/Fonts` (It is not working. Just example.)

  ```sh
  $ cp [/assets/fonts/*] ~/Library/Fonts/*
  ```
