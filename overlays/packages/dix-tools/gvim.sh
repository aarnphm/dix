#! @shell@
set -euo pipefail

port=6666
remote_address=""
file_path_arg=""
use_terminal_nvim=false

show_usage() {
	echo "Usage: gvim [options] [file_path]"
	echo
	echo "Options:"
	echo "  --address <user@ip>   Connect to nvim running on a remote server."
	echo "                          If specified, [file_path] will be opened on the remote server."
	echo "  --term                Use 'nvim --server' in the terminal instead of Neovide to connect."
	echo "  -h, --help            Show this help message and exit."
	echo
	echo "Arguments:"
	echo "  [file_path]           Optional. Path to the file to open. Local if --address is not used,"
	echo "                        remote if --address is used."
	echo
	echo "Examples:"
	echo "  gvim my_local_file.txt"
	echo "  gvim --address user@example.com /path/to/remote/file.txt"
	echo "  gvim --address user@example.com --term /path/to/remote/file.txt"
	echo "  gvim --term my_local_file.txt"
	echo "  gvim -h"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
	-h | --help)
		show_usage
		exit 0
		;;
	--address)
		if [[ -z "$2" ]]; then
			echo "Error: --address requires an argument." >&2
			show_usage
			exit 1
		fi
		remote_address="$2"
		shift
		shift
		;;
	--term)
		use_terminal_nvim=true
		shift
		;;
	*)
		if [[ "$key" == -* ]]; then
			echo "Error: Unknown option: $1" >&2
			show_usage
			exit 1
		fi
		if [[ -z "$file_path_arg" ]]; then
			file_path_arg="$1"
		else
			echo "Error: Multiple file paths specified or unknown argument: $1" >&2
			show_usage
			exit 1
		fi
		shift
		;;
	esac
done

if [ -n "$remote_address" ]; then
	echo "Remote mode: address '$remote_address', file '$file_path_arg'"

	remote_ip="${remote_address##*@}"
	nvim_listen_address="0.0.0.0"

	echo "Checking for existing nvim instance on $remote_address:$port"
	if ssh "$remote_address" "nc -z localhost $port" >/dev/null 2>&1; then
		echo "Existing nvim instance detected on $remote_address:$port. Skipping nvim startup."
	else
		echo "No existing nvim instance found. Starting nvim on $remote_address"
		nvim_exec_cmd_parts=("nvim" "--headless" "--listen" "${nvim_listen_address}:${port}")
		if [ -n "$file_path_arg" ]; then
			# Escape single quotes for the remote sh -c execution context
			escaped_file_path_for_sh_c=$(echo "$file_path_arg" | sed "s/'/'\\''/g")
			nvim_exec_cmd_parts+=("'${escaped_file_path_for_sh_c}'")
		fi

		# Join parts to form the command nvim will execute
		nvim_final_command=""
		for part in "${nvim_exec_cmd_parts[@]}"; do
			nvim_final_command="$nvim_final_command $part"
		done
		nvim_final_command="${nvim_final_command# }"

		env_literal='if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; elif [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; fi; '

		echo "Command: ${nvim_final_command}"
		ssh "$remote_address" "bash -c '${env_literal}nohup ${nvim_final_command} > ~/.gvim_remote_nvim.log 2>&1 &'"

		echo -n "Waiting for nvim to start on $remote_address (port $port)"
		max_retries=30 # Approx 15 seconds timeout (30 * 0.5s)
		retries=0
		until ssh "$remote_address" "nc -z localhost $port"; do
			sleep 0.5
			retries=$((retries + 1))
			if [ "$retries" -ge "$max_retries" ]; then
				echo
				echo "Error: Timeout waiting for remote nvim on $remote_address." >&2
				echo "Check ~/.gvim_remote_nvim.log on the remote host for nvim errors." >&2
				show_usage
				exit 1
			fi
			echo -n "."
		done
		echo
		echo "Remote nvim is listening on $remote_address (port $port)."
	fi

	if [ "$use_terminal_nvim" = true ]; then
		echo "Connecting with nvim (terminal): nvim --server ${remote_ip}:${port}${file_path_arg:+ --remote \"$file_path_arg\"}"
		nvim --server "${remote_ip}:${port}" ${file_path_arg:+--remote "$file_path_arg"}
		echo "Terminal nvim client exited. The remote nvim process on $remote_address might still be running."
	else
		neovide_base_cmd_remote="@neovide@ --remote-tcp=\"${remote_ip}:${port}\""
		if [ -n "$file_path_arg" ]; then
			echo "Spawning Neovide: $neovide_base_cmd_remote \"$file_path_arg\""
			@neovide@ --remote-tcp="${remote_ip}:${port}" "$file_path_arg"
		else
			echo "Spawning Neovide: $neovide_base_cmd_remote"
			@neovide@ --remote-tcp="${remote_ip}:${port}"
		fi
		echo "Neovide exited. The remote nvim process on $remote_address might still be running."
	fi

	echo "You may need to manually kill it, e.g.:"
	echo "ssh $remote_address \"pkill -f 'nvim.*--listen ${nvim_listen_address}:${port}'\""

else
	echo "Local mode: file '$file_path_arg'"
	nvim_listen_address="127.0.0.1"

	# Check if nvim is already running locally
	echo "Checking for existing local nvim instance on $nvim_listen_address:$port"
	if nc -z $nvim_listen_address $port >/dev/null 2>&1; then
		echo "Existing local nvim instance detected on $nvim_listen_address:$port. Skipping nvim startup."
	else
		echo "No existing local nvim instance found. Starting local nvim"
		if [ -n "$file_path_arg" ]; then
			nvim --headless --listen "$nvim_listen_address:$port" "$file_path_arg" &
		else
			nvim --headless --listen "$nvim_listen_address:$port" &
		fi

		echo -n "Waiting for local nvim to start (listening on $nvim_listen_address:$port)"
		max_local_retries=50 # Approx 5 seconds (50 * 0.1s)
		local_retries=0
		while ! nc -z $nvim_listen_address $port; do
			sleep 0.1
			echo -n "."
			local_retries=$((local_retries + 1))
			if [ "$local_retries" -ge "$max_local_retries" ]; then
				echo
				echo "Error: Timeout waiting for local nvim to start." >&2
				exit 1
			fi
		done
		echo
		echo "Local nvim is listening."
	fi

	if [ "$use_terminal_nvim" = true ]; then
		echo "Connecting with nvim (terminal): nvim --server ${nvim_listen_address}:${port}${file_path_arg:+ --remote \"$file_path_arg\"}"
		nvim --server "${nvim_listen_address}:${port}" ${file_path_arg:+--remote "$file_path_arg"}
		echo "Terminal nvim client exited. Local nvim process might still be running."
	else
		neovide_base_cmd_local="@neovide@ --server=\"${nvim_listen_address}:${port}\""
		if [ -n "$file_path_arg" ]; then
			echo "Spawning Neovide: $neovide_base_cmd_local \"$file_path_arg\""
			@neovide@ --server="${nvim_listen_address}:${port}" "$file_path_arg"
		else
			echo "Spawning Neovide: $neovide_base_cmd_local"
			@neovide@ --server="${nvim_listen_address}:${port}"
		fi
		echo "Neovide exited. Local nvim process might still be running."
	fi
fi
