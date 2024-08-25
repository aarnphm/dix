#! @shell@
set -e
set -o pipefail

file_path="$1"
port=6666

if [ -n "$file_path" ]; then
	@nvim@ --headless --listen 127.0.0.1:$port "$file_path" &
else
	@nvim@ --headless --listen 127.0.0.1:$port &
fi

# Wait for nvim to start and listen on the port
while ! nc -z 127.0.0.1 $port; do
	sleep 0.1
done

# Spawn neovide and connect to the nvim server
@neovide@ --server=127.0.0.1:$port
