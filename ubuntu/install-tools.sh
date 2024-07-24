#!/bin/bash
sudo apt install git fzf fd-find bat-cat ripgrep openssh-server openssh-client python3-neovim
mkdir "$HOME/.config/"
git clone https://github.com/JonasGao/nvimrc.git $HOME/.config/nvim
printf """alias fd='fdfind'
alias bat='batcat'
alias n='nvim'
alias k='kubectl'
alias h='helm'
""" >"$HOME/.bash_aliases"
