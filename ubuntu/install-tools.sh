#!/bin/bash
sudo apt install git fzf fd-find bat ripgrep openssh-server openssh-client
sudo add-apt-repository ppa:neovim-ppa/stable -y
sudo apt update
sudo apt install neovim
mkdir "$HOME/.config/"
git clone https://github.com/JonasGao/nvimrc.git $HOME/.config/nvim
printf """alias fd='fdfind'
alias bat='batcat'
alias n='nvim'
alias k='kubectl'
alias h='helm'
""" >"$HOME/.bash_aliases"
printf """
# Fzf for bash
eval \"\$(fzf --bash)\"
""">> "$HOME/.bashrc"
