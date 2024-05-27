# options, disable for now
# HISTSIZE=10000
# SAVEHIST=100000
# HISTORY_IGNORE="(ls|cd|pwd|zsh|exit|cd ..)"
# LISTMAX=1000
# KEYTIMEOUT=1
# WORDCHARS='*?_-.[]~&;!#$%^(){}<>|'
#
# # autoload
# autoload -Uz run-help
# autoload -Uz add-zsh-hook
# autoload -Uz is-at-least
#
# # core
# ulimit -c unlimited
#
# umask 022
#
# export DISABLE_DEVICONS=false
#
# unsetopt clobber
# unsetopt hist_verify
#
# setopt prompt_subst
# setopt notify
# setopt correct
# setopt autopushd
# setopt multios
# setopt pushd_ignore_dups
# setopt pushd_silent
# setopt pushd_to_home
# setopt cdable_vars
# setopt extendedglob
# setopt extended_history
# setopt append_history
# setopt share_history
# setopt hist_reduce_blanks
# setopt hist_save_no_dups
# setopt hist_no_store
# setopt hist_expand
# setopt hist_ignore_all_dups
# setopt inc_append_history

# NOTE: Keybinding
# stty intr '^C'
# stty susp '^Z'
# stty stop undef
bindkey -v     # vi 風

## delete ##
bindkey '^?'    backward-delete-char
bindkey '^H'    backward-delete-char
bindkey '^[[3~' delete-char
bindkey '^[[3;5~' delete-word

## move ##
bindkey '^[h' backward-char
bindkey '^[j' down-line-or-history
bindkey '^[k' up-line-or-history
bindkey '^[l' forward-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

## history ##
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^[p" history-beginning-search-backward
bindkey "^[n" history-beginning-search-forward
bindkey '^R' history-incremental-pattern-search-backward
bindkey '^S' history-incremental-pattern-search-forward

## edit ##
bindkey '^[u' undo
bindkey '^[r' redo
bindkey -s "^T" "^[Isudo ^[A" # "t" for "toughguy"

## completion ##
# vim hjkl
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'l' vi-forward-char
# shift-tab
bindkey '^[[Z' reverse-menu-complete
bindkey -M menuselect '^[[Z' reverse-menu-complete


# edit command-line using editor (like fc command)
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^xe' edit-command-line
bindkey '^x^e' edit-command-line

## etc ##
bindkey '^X*' expand-word
# stack command
zle -N show_buffer_stack
