source ~/.zplug/init.zsh

# Misc

export LANG="en_US.UTF-8"

zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-history-substring-search"
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-autosuggestions"
zplug "supercrabtree/k"
zplug "b4b4r07/enhancd", use:init.sh
zplug "b4b4r07/emoji-cli"
zplug "mrowa44/emojify", as:command
zplug "k4rthik/git-cal", as:command
zplug "lib/completion", from:oh-my-zsh
zplug "plugins/colored-man-pages", from:oh-my-zsh
zplug "plugins/man", from:oh-my-zsh
zplug "plugins/sudo", from:oh-my-zsh
zplug "plugins/encode64", from:oh-my-zsh
zplug 'plugins/extract', from:oh-my-zsh
zplug "romkatv/powerlevel10k", as:theme, depth:1
zplug "agkozak/zsh-z"

if ! zplug check --verbose; then
  printf "Install? [y/N]: "
  if read -q; then
    echo; zplug install
  else
    echo
  fi
fi

zplug load

HISTSIZE=50000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt inc_append_history
setopt share_history
setopt auto_cd autopushd pushdignoredups

bindkey  "^[[H"   beginning-of-line
bindkey  "^[[F"   end-of-line
bindkey  "^[[3~"  delete-char
bindkey  "^[[5~"  history-beginning-search-backward
bindkey  "^[[6~"  history-beginning-search-forward

# Instead By 'zplug "agkozak/zsh-z"'
# . "$HOME/.local/z.sh"

alias ll='exa -l'
alias ll='exa -l -a'

export PATH="$HOME/.local/bin:$PATH"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
