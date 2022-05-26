#!/bin/bash

PWD=$(dirname $(readlink -f $0))

ZSHRC=$HOME/.zshrc
VIMRC=$HOME/.vimrc

[[ -f $ZSHRC ]] || ln -s $PWD/.zshrc $ZSHRC && echo "$ZSHRC already exists. skipped."
[[ -f $VIMRC ]] || ln -s $PWD/.vimrc $VIMRC && echo "$VIMRC already exists. skipped."
