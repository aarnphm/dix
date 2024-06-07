rsign-discord() {
  find /Applications/Discord.app/Contents/Frameworks -d -type d -iname "*.app" | while read -r dir; do
    sudo codesign --remove-signature "$dir"
    sudo codesign --sign - "$dir"
  done
}

path() {
    if (($+PATH)); then
        printf '%q\n' "$path[@]"
    else
        echo "PATH unset"
    fi
}

fpath() {
    if (($+FPATH)); then
        printf '%q\n' "$fpath[@]"
    else
        echo "PATH unset"
    fi
}

bwunlock() {
    zmodload zsh/mapfile
    bwpassfile="$HOME/bw.master"
    bitwarden=("${(f@)mapfile[$bwpassfile]}")
    BW_MASTER=$bitwarden[1]
    export BW_SESSION="$(bw unlock $BW_MASTER 2>/dev/null | grep '$env' | sed -e 's/^.*="\(.*\)"$/\1/')"
}

__exec_command_with_tmux() {
    local cmd="$@"
    if [[ "$(ps -p $(ps -p $$ -o ppid=) -o comm= 2> /dev/null)" =~ tmux ]]; then
        if [[ $(tmux show-window-options -v automatic-rename) != "off" ]]; then
            local title=$(echo "$cmd" | cut -d ' ' -f 2- | tr ' ' '\n'  | grep -v '^-' | sed '/^$/d' | tail -n 1)
            if [ -n "$title" ]; then
                tmux rename-window -- "$title"
            else
                tmux rename-window -- "$cmd"
            fi
            trap 'tmux set-window-option automatic-rename on 1>/dev/null' 2
            eval command "$cmd"
            local ret="$?"
            tmux set-window-option automatic-rename on 1>/dev/null
            return $ret
        fi
    fi
    eval command "$cmd"
}

ssh() {
    local args=$(printf ' %q' "$@")
    local ppid=$(ps -p $$ -o ppid= 2> /dev/null | tr -d ' ')
    if [[ "$@" =~ .*BatchMode=yes.*ls.*-d1FL.* ]]; then
        command ssh "$args"
        return
    fi

    case $TERM in
        *xterm*|rxvt*|(dt|k|E)term|*kitty*|screen*)
        print -Pn "\e]2;ssh $@\a"
        ;;
esac

__exec_command_with_tmux "ssh $args"
}

comment() {
    sed -i "$1"' s/^/#/' "$2"
}

ltrim() {
    local input
    input=$(get_stdin_and_args "$@")
    printf "%s" "`expr "$input" : "^[[:space:]]*\(.*[^[:space:]]\)"`"
}

rtrim() {
    local input
    input=$(get_stdin_and_args "$@")
    printf "%s" "`expr "$input" : "^\(.*[^[:space:]]\)[[:space:]]*$"`"
}

trim() {
    local input
    input=$(get_stdin_and_args "$@")
    printf "%s" "$(rtrim "$(ltrim "$input")")"
}

trim_whitespace() {
    local input
    input=$(get_stdin_and_args "$@")
    echo "$input" | tr -d ' '
}

timeshell() {
    TIMESHELL=1 zsh -c 'for i in $(seq 1 10); do time $SHELL -c -i exit; done'
}

## docker ##
dockerclean() {
    # remove first none images
    docker rmi -f $(docker images -a | grep "^<none>" | awk '{print $3}') 2> /dev/null;
    # now remove none container
    docker rmi -f $(docker ps -a -f status=exited -q) 2> /dev/null;
}

dockerrmi() {
# remove images by reference
docker rmi -f $(docker images --filter=reference="$1" -q) 2> /dev/null;
}

# Select a docker container to remove
drm() {
    local cid
    cid=$(docker ps -a | sed 1d | fzf -q "$1" | awk '{print $1}')

    [ -n "$cid" ] && docker rm "$cid"
}

# Select a running docker container to stop
ds() {
    local cid
    cid=$(docker ps | sed 1d | fzf -q "$1" | awk '{print $1}')

    [ -n "$cid" ] && docker stop "$cid"
}

# Displays user owned processes status.
psu() {
    ps -U "${1:-$LOGNAME}" -o 'pid,%cpu,%mem,command' "${(@)argv[2,-1]}"
}

# Create a new directory and enter it
mkd() {
    mkdir -p "$@" && cd "$_";
}

listen() {
    sudo lsof -iTCP:"$@" -sTCP:LISTEN;
}

# Determine size of a file or total size of a directory
fs() {
    if du -b /dev/null > /dev/null 2>&1; then
        local arg=-sbh;
    else
        local arg=-sh;
    fi
    if [[ -n "$@" ]]; then
        du $arg -- "$@";
    else
        du $arg .[^.]* ./*;
    fi;
}

venv() {
    name="${1:-.venv}"
    if [[ ! -d "$name" ]]; then
        uv venv "${PWD}/$name"
        source "$name/bin/activate"
    else
        source "$name/bin/activate"
    fi
}

# Check for virtualenvwrapper
if type workon >/dev/null 2>&1; then
  VENV_WRAPPER=true
else
  VENV_WRAPPER=false
fi

_venv_auto_activate() {
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        # Check if the current directory is inside the project directory
        if [[ "$PWD" != "$PROJECT_DIR"* ]]; then
            [ -n "$DEBUG" ] && echo -e "\n\e[1;33mDeactivating venv...\e[0m"
            deactivate
            unset PROJECT_DIR
        fi
        return
    fi

    if [[ -e ".venv" ]]; then
        # Check for symlink pointing to virtualenv
        if [ -L ".venv" ]; then
          _VENV_PATH=$(readlink .venv)
          _VENV_WRAPPER_ACTIVATE=false
        # Check for directory containing virtualenv
        elif [ -d ".venv" ]; then
          _VENV_PATH=$(pwd -P)/.venv
          _VENV_WRAPPER_ACTIVATE=false
        # Check for file containing name of virtualenv
        elif [ -f ".venv" -a $VENV_WRAPPER = "true" ]; then
          _VENV_PATH=$WORKON_HOME/$(cat .venv)
          _VENV_WRAPPER_ACTIVATE=true
        else
          return
        fi

        # Check to see if already activated to avoid redundant activating
        if [ "$VIRTUAL_ENV" != $_VENV_PATH ]; then
            [ -n "$DEBUG" ] && echo -e "\n\e[1;33mActivating venv...\e[0m"
            if $_VENV_WRAPPER_ACTIVATE; then
              _VENV_NAME=$(basename $_VENV_PATH)
              workon $_VENV_NAME
            else
              _VENV_NAME=$(basename `pwd`)
              VIRTUAL_ENV_DISABLE_PROMPT=1
              source .venv/bin/activate
            fi
            PROJECT_DIR="$PWD"
        fi
    fi
}

chpwd_functions+=(_venv_auto_activate)
precmd_functions=(_venv_auto_activate $precmd_functions)


show_keymaps() {
  bindkey -L | rg -v '^#' | fzf --preview '_fzf_complete_realpath {}' --preview-window up:50%
}
zle -N show_keymaps
bindkey '^P' show_keymaps
