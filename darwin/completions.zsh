zmodload  zsh/complist

unsetopt menu_complete
unsetopt flowcontrol
setopt globdots
setopt auto_menu
setopt complete_in_word
setopt always_to_end

autoload -Uz add-zle-hook-widget

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:*:*:*:*' special-dirs true
## pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' verbose true # provide verbose completion information
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:*:*' option-stacking yes
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/

## correction
# run rehash on completion so new installed program are found automatically:
_force_rehash() {
    (( CURRENT == 1 )) && rehash
    return 1 # Because we didn't really complete anything
}

# enable caching to make completion for commands such as dpkg and apt usable
zstyle ':completion::complete:*' use-cache true
zstyle ':completion::complete:*' cache-path "${HOME}/.zcompcache"

# Don't complete uninteresting users
zstyle ':completion:*:*:*:users' ignored-patterns \
    adm amanda apache at avahi avahi-autoipd beaglidx bin cacti canna \
    clamav daemon dbus distcache dnsmasq dovecot fax ftp games gdm \
    gkrellmd gopher hacluster haldaemon halt hsqldb ident junkbust kdm \
    ldap lp mail mailman mailnull man messagebus  mldonkey mysql nagios \
    named netdump news nfsnobody nobody nscd ntp nut nx obsrun openvpn \
    operator pcap polkitd postfix postgres privoxy pulse pvm quagga radvd \
    rpc rpcuser rpm rtkit scard shutdown squid sshd statd svn sync tftp \
    usbmux uucp vcsa wwwrun xfs '_*'

# ... unless we really want to.
zstyle '*' single-ignored show

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
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'

zstyle ':completion:*:complete:-command-::commands' ignored-patterns '*\~' # don't complete backup files as executables
zstyle ':completion:*:*:zcompile:*'                 ignored-patterns '(*~|*.zwc)'       # define files to ignore for zcompile
zstyle ':completion::(^approximate*):*:functions'   ignored-patterns '_*'    # Ignore completion functions for commands you don't have:
zstyle ':completion:*:approximate:'                 max-errors 'reply=( $((($#PREFIX+$#SUFFIX)/3 )) numeric )' # allow one error for every three characters typed in approximate completer
zstyle ':completion:*:default'                      list-colors ${(s.:.)LS_COLORS}      # activate color-completion(!)
zstyle ':completion:*:descriptions'                 format $'%{\e[0;31m%}-- %B%d%b%{\e[0m%} %{\e[0;31m%}--'  # format on completion
zstyle ':completion:*:*:cd:*:directory-stack'       menu yes select              # complete 'cd -<tab>' with menu
zstyle ':completion:*:expand:*'                     tag-order all-expansions            # insert all expansions for expand completer
zstyle ':completion:*:matches'                      group yes                           # separate matches into groups
zstyle ':completion:*:messages'                     format ' %F{purple} -- %d --%f'
zstyle ':completion:*:default'                      list-prompt '%S%M matches%s'
zstyle ':completion:*:options'                      auto-description 'specify: %d'
zstyle ':completion:*:options'                      description 'yes'                   # describe options in full
zstyle ':completion:*:processes'                    command 'ps -au$USER'               # on processes completion complete all user processes
zstyle ':completion:*:*:-subscript-:*'              tag-order indexes parameters        # offer indexes before parameters in subscripts

# rehash if command not found (possibly recently installed)
zstyle ':completion:*' rehash true

# fuzzy match mistyped completions
zstyle ':completion:*' completer _complete _match _approximate _expand _force_rehash _files
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# directories
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
zstyle ':completion:*' squeeze-slashes true

# gnu make completion is slow
zstyle ':completion:*:make:*:targets' call-command true
zstyle ':completion:*:make::' tag-order targets:
zstyle ':completion:*:*:*make:*:targets' command awk \''/^[a-zA-Z0-9][^\/\t=]+:/ {print $1}'\' \$file

# ignores unavailable commands
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec)|prompt_*)'

# completion element sorting
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# man
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true
zstyle ':completion:*:man:*' menu yes select

# exa
zstyle ':completion:*:eza' file-sort modification
zstyle ':completion:*:eza' sort false

# # ignores unavailable commands
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec)|prompt_*)'

# completion element sorting
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters
# ps
zstyle ':completion:*:processes' command 'ps x -o pid,s,args'

# sudo
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin

# Kill
zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always
zstyle ':completion:*:*:kill:*' insert-ids single

# ignore multiple entries
zstyle ':completion:*' file-patterns '%p:globbed-files' '*(-/):directories' '*:all-files'
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
zstyle ':completion:*:rm:*' file-patterns '*:all-files'

# history
zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes

# bentoml
zstyle ":bentoml:*" use-groups true


# command for process lists, the local web server details and host completion
zstyle ':completion:*:urls' local 'www' '/var/www/' 'public_html'

# Environmental Variables
zstyle ':completion::*:(-command-|export):*' fake-parameters ${${${_comps[(I)-value-*]#*,}%%,*}:#-*-}

# host completion /* add brackets as vim can't parse zsh's complex cmdlines 8-) {{{ */
[ -r ~/.ssh/known_hosts ] && _ssh_hosts=(${${${${(f)"$(<$HOME/.ssh/known_hosts)"}:#[\|]*}%%\ *}%%,*}) || _ssh_hosts=()
[ -r /etc/hosts ] && : ${(A)_etc_hosts:=${(s: :)${(ps:\t:)${${(f)~~"$(</etc/hosts)"}%%\#*}##[:blank:]#[^[:blank:]]#}}} || _etc_hosts=()

hosts=(`hostname` "$_ssh_hosts[@]" "$_etc_hosts[@]" localhost)
zstyle ':completion:*:hosts' hosts $hosts

# ssh/scp/rsync
zstyle ':completion:*:(scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:ssh:*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'
