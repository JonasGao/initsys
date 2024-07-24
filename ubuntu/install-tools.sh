#!/bin/bash
sudo apt install git fd-find bat-cat ripgrep openssh-server openssh-client python3-neovim
mkdir "$HOME/.config/"
git clone https://github.com/JonasGao/nvimrc.git $HOME/.config/nvim
printf """alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
""" >"$HOME/.bash_aliases"
