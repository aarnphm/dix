function tflibs() {
    python -c "import tensorflow as tf;print(f'include: {tf.sysconfig.get_include()}\nlib: {tf.sysconfig.get_lib()}\n')"
}

function venv() {
    name="${1:-.venv}"
    if [[ ! -d "$name" ]]; then
        uv venv "${PWD}/$name"
        source "$name/bin/activate"
    else
        source "$name/bin/activate"
    fi
}

function rsign-discord() {
  find /Applications/Discord.app/Contents/Frameworks -d -type d -iname "*.app" | while read -r dir; do
    sudo codesign --remove-signature "$dir"
    sudo codesign --sign - "$dir"
  done
}

function path() {
    if (($+PATH)); then
        printf '%q\n' "$path[@]"
    else
        echo "PATH unset"
    fi
}

function fpath() {
    if (($+FPATH)); then
        printf '%q\n' "$fpath[@]"
    else
        echo "PATH unset"
    fi
}

function __exec_command_with_tmux() {
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

function ssh() {
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

function comment(){
sed -i "$1"' s/^/#/' "$2"
}

function ltrim() {
local input
input=$(get_stdin_and_args "$@")
printf "%s" "`expr "$input" : "^[[:space:]]*\(.*[^[:space:]]\)"`"
}

function rtrim() {
local input
input=$(get_stdin_and_args "$@")
printf "%s" "`expr "$input" : "^\(.*[^[:space:]]\)[[:space:]]*$"`"
}

function trim() {
local input
input=$(get_stdin_and_args "$@")
printf "%s" "$(rtrim "$(ltrim "$input")")"
}

function trim_all_whitespace() {
local input
input=$(get_stdin_and_args "$@")
echo "$input" | tr -d ' '
}

function timeshell() {
TIMESHELL=1 zsh -c 'for i in $(seq 1 10); do time $SHELL -c -i exit; done'
}

## docker ##
function dockerclean() {
# remove first none images
docker rmi -f $(docker images -a | grep "^<none>" | awk '{print $3}') 2> /dev/null;
# now remove none container
docker rmi -f $(docker ps -a -f status=exited -q) 2> /dev/null;
}

function dockerrmi() {
# remove images by reference
docker rmi -f $(docker images --filter=reference="$1" -q) 2> /dev/null;
}

# Select a docker container to remove
function drm() {
local cid
cid=$(docker ps -a | sed 1d | fzf -q "$1" | awk '{print $1}')

[ -n "$cid" ] && docker rm "$cid"
}

# Select a running docker container to stop
function ds() {
local cid
cid=$(docker ps | sed 1d | fzf -q "$1" | awk '{print $1}')

[ -n "$cid" ] && docker stop "$cid"
}

# Displays user owned processes status.
function psu {
ps -U "${1:-$LOGNAME}" -o 'pid,%cpu,%mem,command' "${(@)argv[2,-1]}"
}

# Create a new directory and enter it
function mkd() {
mkdir -p "$@" && cd "$_";
}

function listen {
sudo lsof -iTCP:"$@" -sTCP:LISTEN;
}

# Determine size of a file or total size of a directory
function fs() {
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
