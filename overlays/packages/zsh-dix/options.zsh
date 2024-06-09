unsetopt extendedglob
unsetopt beep
unsetopt menu_complete
unsetopt flowcontrol

setopt prompt_sp
setopt correct
setopt autopushd
setopt multios
setopt pushd_ignore_dups
setopt pushd_silent
setopt pushd_to_home
setopt append_history
setopt share_history
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_no_store
setopt hist_expand
setopt inc_append_history
setopt auto_menu
setopt complete_in_word
setopt always_to_end


# NOTE: Keybinding
stty intr '^C'
stty susp '^Z'
stty stop undef
bindkey -v

## delete ##
bindkey '^?'    backward-delete-char
bindkey '^H'    backward-delete-char
bindkey '^[[3~' delete-char
bindkey '^[[3;5~' delete-word

## jump ##
bindkey  '^[[H' beginning-of-line
bindkey  '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[7~' beginning-of-line
bindkey '^[[8~' end-of-line
bindkey '^U' backward-kill-line
bindkey '^[^?' delete-char-or-list

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
bindkey '^S' history-incremental-pattern-search-forward

## edit ##
bindkey -s "^A" "^[Isudo ^[A" # "t" for "toughguy"
