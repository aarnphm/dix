zmodload  zsh/complist

unsetopt menu_complete
unsetopt flowcontrol
setopt glob_dots
setopt auto_menu
setopt complete_in_word
setopt always_to_end

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:*:*:*:*' special-dirs true
## pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' verbose true # provide verbose completion information
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:*:*' option-stacking yes

## fuzzy match mistyped completions
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 3 numeric
zstyle ':completion:correct:' prompt 'correct to: %e'
zstyle ':completion:*:correct:*' insert-unambiguous true
zstyle ':completion:*:correct:*' original true
zstyle ':completion:*:matches' group yes

# ## completion system
zstyle ':completion:*:options' description yes
zstyle ':completion:*:options' auto-description 'specify: %d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format $'%{\e[0;31m%}No matches for:%{\e[0m%} %d' # set format for warnings
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
