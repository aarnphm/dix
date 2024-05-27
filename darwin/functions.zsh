function tflibs() {
    python -c "import tensorflow as tf;print(f'include: {tf.sysconfig.get_include()}\nlib: {tf.sysconfig.get_lib()}\n')"
}

function venv() {
    name="${1:-venv}"
    if [[ ! -d "$name" ]]; then
        pip freeze | grep "virtualenv" &>/dev/null || pip install virtualenv;
        python -m virtualenv "$name" --download
        source "$name/bin/activate"
        pip install "protobuf<3.20"
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

function print_default() {
echo -e "$*"
}

function print_info() {
echo -e "\e[1;36m$*\e[m" # cyan
}

function print_notice() {
echo -e "\e[1;35m$*\e[m" # magenta
}

function print_success() {
echo -e "\e[1;32m$*\e[m" # green
}

function print_warning() {
echo -e "\e[1;33m$*\e[m" # yellow
}

function print_error() {
echo -e "\e[1;31m$*\e[m" # red
}

function print_debug() {
echo -e "\e[1;34m$*\e[m" # blue
}

#==============================================================#
##         New Commands                                      ##
#==============================================================#

function comment(){
sed -i "$1"' s/^/#/' "$2"
}

function 256color() {
clear
for code in {000..255}; do
    print -nP -- "%F{$code}$code %f";
    if [ $((${code} % 16)) -eq 15 ]; then
        echo ""
    fi
done
}

function ascii_color_code() {
seq 30 47 | xargs -i{} printf "\x1b[%dm#\x1b[0m %d\n" {} {}
}


function find_no_new_line_at_end_of_file() {
find * -type f -print0 | xargs -0 -L1 bash -c 'test "$(tail -c 1 "$0")" && echo "No new line at end of $0"'
}


function get_stdin_and_args() {
local __str
if [ -p /dev/stdin ]; then
    if [ "`echo $@`" == "" ]; then
        __str=`cat -`
    else
        __str="$@"
    fi
else
    __str="$@"
fi
echo "$__str"
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

function convert_ascii_to_hex() {
echo -n "$@" | xxd -ps -c 200
}

function convert_hex_to_ascii() {
echo -n "$@" | xxd -ps -r
}

function convert_hex_to_formatted_hex() {
echo -n "$@" | sed 's/[[:xdigit:]]\{2\}/\\x&/g'
}


function zsh-profiler() {
ZSHRC_PROFILE=1 zsh -i -c zprof
}

function zsh-detailed() {
logf=$(ls -tm $ZDATADIR/logs | head -n1)
sed -i '0,/PROFILE_STARTUP/s/false/true/' $ZDOTDIR/.zshrc
dtime="$HOME/.local/bin/sort-timings-zsh $ZDATADIR/logs/$logf | head"
echo "Getting runtime..."
zsh -i -c $dtime
echo "done."
sed -i '0,/PROFILE_STARTUP/s/true/false/' $ZDOTDIR/.zshrc
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
