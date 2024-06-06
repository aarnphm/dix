zmodload -i zsh/complist

# use completions cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"
# ls color goes hard
zstyle ':completion:*' list-colors ''
# enable hidden files on completion
zstyle ':completion:*' special-dirs true
# disable menu for fzf-tab
zstyle ':completion:*' menu no
# hide parents
zstyle ':completion:*' ignored-patterns '.|..|.DS_Store|**/.|**/..|**/.DS_Store|**/.git|__pycache__|**/__pycache__|.mypy_cache|.ipynb_checkpoints|.ruff_cache'
# hide `..` and `.` from file menu
zstyle ':completion:*' ignore-parents 'parent pwd directory'
# details completions menu formatting and messages
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*:descriptions' format '[%d]'

zstyle ':fzf-tab:*' switch-group '[' ']'
# use the same layout as others and respect my default
local fzf_flags
zstyle -a ':fzf-tab:*' fzf-flags fzf_flags
fzf_flags=( "${fzf_flags[@]}" '--layout=reverse-list' )
zstyle ':fzf-tab:*' fzf-flags $fzf_flags

# complete `ls` / `cat` / etc
zstyle ':fzf-tab:complete:(\\|*/|)(ls|gls|bat|eza|cat|cd|rm|cp|mv|ln|nano|nvim|vim|open|tree|source):*' \
  fzf-preview \
  '_fzf_complete_realpath "$realpath"'

# complete `make`
zstyle ':fzf-tab:complete:(\\|*/|)make:*' fzf-preview \
  'case "$group" in
  "[make target]")
    make -n "$word" | _fzf_complete_realpath
    ;;
  "[make variable]")
    make -pq | rg "^$word =" | _fzf_complete_realpath
    ;;
  "[file]")
    _fzf_complete_realpath "$realpath"
    ;;
  esac'

# complete `killall`
zstyle ':completion:*:*:killall:*:*' command 'ps -u "$USERNAME" -o comm'
zstyle ':fzf-tab:complete:(\\|*/|)killall:*' fzf-preview \
  'ps aux | rg "$word" | _fzf_complete_realpath'

# ignores unavailable commands
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec)|prompt_*)'

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u `whoami` -o pid,user,comm -w -w"

# disable named-directories autocompletion
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

zstyle ':completion:*' users off

# Use caching so that commands like apt and dpkg complete are useable
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path $ZSH/cache/
# Don't complete uninteresting users
zstyle ':completion:*:*:*:users' ignored-patterns \
        adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
        dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
        hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
        mailman mailnull mldonkey mysql nagios \
        named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
        operator pcap postfix postgres privoxy pulse pvm quagga radvd \
        rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs

# ... unless we really want to.
zstyle '*' single-ignored show

zstyle -e ':completion:*:(ssh|scp|sftp|rsh|rsync):hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'
