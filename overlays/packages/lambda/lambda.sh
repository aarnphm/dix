#! @shell@

set -euo pipefail

ERROR_COLOR="\033[0;31m" # Red
LOG_COLOR="\033[0;32m"   # Green
WARN_COLOR="\033[0;34m"  # Blue
DEBUG_COLOR="\033[0;35m" # Purple
RESET_COLOR="\033[0m"

API_URL="https://cloud.lambda.ai/api/v1"
SSH_KEY="~/.ssh/id_ed25519-github"
DEFAULT_REGION="us-south-3"
REMOTE_USER="ubuntu"
REMOTE_PASSWORD="toor"
log() {
	local level=$1
	local caller=$2
	local message=$3

	# Convert caller to uppercase
	caller=$(echo "$caller" | tr '[:lower:]' '[:upper:]')

	# Set color based on log level
	local color=""
	case $level in
	"ERROR")
		color=$ERROR_COLOR
		;;
	"INFO")
		color=$LOG_COLOR
		;;
	"WARN" | "WARNING")
		color=$WARN_COLOR
		;;
	"DEBUG")
		color=$DEBUG_COLOR
		;;
	*)
		color=$RESET_COLOR
		;;
	esac

	# Print formatted log message
	echo -e "${color}[${caller}]${RESET_COLOR} ${message}"
}

log_info() {
	local message=$1
	log "INFO" "SYS" "$message"
}

log_warn() {
	local message=$1
	log "WARN" "SYS" "$message"
}

log_error() {
	local message=$1
	log "ERROR" "SYS" "$message"
}

log_debug() {
	local message=$1
	log "DEBUG" "SYS" "$message"
}

ensure_api_key() {
	if [[ -z "${LAMBDA_API_KEY:-}" ]]; then
		log_error "LAMBDA_API_KEY environment variable is not set." >&2
		exit 1
	fi
}

api_request() {
	local method="$1"
	local endpoint="$2"
	local data="${3:-}"
	local extra_args=()
	if [[ -n "$data" ]]; then
		extra_args+=(-H "Content-Type: application/json" -d "$data")
	fi

	@curl@ -s -X "$method" \
		-H "Authorization: Bearer ${LAMBDA_API_KEY}" \
		"${API_URL}${endpoint}" \
		"${extra_args[@]}"
}

get_instance_by_name_prefix() {
	local name_prefix="$1"
	api_request GET "/instances" | @jq@ -r --arg prefix "$name_prefix" '.data[] | select(.name | startswith($prefix))'
}

get_instance_by_exact_name() {
	local exact_name="$1"
	api_request GET "/instances" | @jq@ -r --arg name "$exact_name" '.data[] | select(.name == $name)'
}

create_instance() {
	ensure_api_key
	local instance_spec="$1"
	local region="${2:-}" # Allow empty initial region, default logic handles it later

	if ! [[ "$instance_spec" =~ ^([1-9][0-9]*)x([a-zA-Z0-9_]+)$ ]]; then
		log_error "Invalid instance specification format. Use <number_gpus>x<gpu_type> (e.g., 1xA100, 2xH100_SXM5)." >&2
		exit 1
	fi

	local num_gpus="${BASH_REMATCH[1]}"
	local gpu_type="${BASH_REMATCH[2]}"
	local requested_instance_type_name="gpu_${num_gpus}x_${gpu_type}"
	local instance_name="aaron-${num_gpus}_${gpu_type}"

	log_info "Checking for existing instance named '$instance_name'"
	local existing_instance
	existing_instance=$(get_instance_by_exact_name "$instance_name")
	if [[ -n "$existing_instance" ]]; then
		local existing_status
		existing_status=$(echo "$existing_instance" | @jq@ -r '.status')
		log_warn "Instance named '$instance_name' already exists with status '$existing_status'"
		log_warn "You can connect to it using 'lambda connect $instance_name'" >&2
		exit 0
	fi

	log_info "Looking for instance type: ${requested_instance_type_name}"

	# Fetch details for the specific instance type requested
	local instance_type_details
	instance_type_details=$(api_request GET "/instance-types" | @jq@ -r --arg name "$requested_instance_type_name" '
	  .data[$name] // null # Select the specific type or return null if not found
	')

	if [[ "$instance_type_details" == "null" || -z "$instance_type_details" ]]; then
		log_error "Instance type '${requested_instance_type_name}' not found." >&2
		log_info "Available instance types (showing name, GPU count, GPU description, available regions):"
		api_request GET "/instance-types" | @jq@ -r '.data | keys[] as $k | .[$k] | {name: .instance_type.name, gpus: .instance_type.specs.gpus, description: .instance_type.gpu_description, available_regions: [.regions_with_capacity_available[].name]}'
		exit 1
	fi

	local instance_type_name
	instance_type_name=$(echo "$instance_type_details" | @jq@ -r '.instance_type.name')
	local available_regions_json
	available_regions_json=$(echo "$instance_type_details" | @jq@ -c '.regions_with_capacity_available') # Keep as JSON array

	log_info "Found instance type: $instance_type_name"

	# Determine the target region
	local target_region=""
	local region_specified_by_user=false
	if [[ -n "$region" ]]; then # Region was passed as argument
		region_specified_by_user=true
		# Check if the specified region is available for this instance type
		if echo "$available_regions_json" | @jq@ -e --arg region_name "$region" '.[] | select(.name == $region_name)' >/dev/null; then
			target_region="$region"
			log_info "Using user-specified region: $target_region (available for $instance_type_name)"
		else
			log_error "Requested instance type '$instance_type_name' is not available in the specified region '$region'." >&2
			log_info "Available regions for '$instance_type_name':"
			echo "$available_regions_json" | @jq@ -r '.[].name'
			exit 1
		fi
	else # Region was not specified, find a suitable default (prefer default, then first US)
		# Check if default region is available
		if echo "$available_regions_json" | @jq@ -e --arg region_name "$DEFAULT_REGION" '.[] | select(.name == $region_name)' >/dev/null; then
			target_region="$DEFAULT_REGION"
			log_info "Using default region: $target_region (available for $instance_type_name)"
		else
			# Find the first available US region
			target_region=$(echo "$available_regions_json" | @jq@ -r '(.[] | select(.name | startswith("us-")) | .name) // empty' | head -n 1)
			if [[ -n "$target_region" ]]; then
				log_info "Default region '$DEFAULT_REGION' not available for '$instance_type_name'. Using first available US region: $target_region"
			else
				log_error "Requested instance type '$instance_type_name' is not available in the default region ('$DEFAULT_REGION') or any other US region." >&2
				log_info "Available regions for '$instance_type_name':"
				echo "$available_regions_json" | @jq@ -r '.[].name'
				exit 1
			fi
		fi
		region="$target_region"
	fi

	local filesystem_name="aaron-${region}"

	log_info "Checking for existing filesystem '$filesystem_name' in region '$region'"
	local fs_name
	fs_name=$(api_request GET "/file-systems" | @jq@ -r --arg name "$filesystem_name" '.data[] | select(.name == $name) | .name')

	if [[ -z "$fs_name" ]]; then
		log_info "Filesystem '$filesystem_name' not found. Creating it"
		local create_fs_payload
		create_fs_payload=$(jq -n --arg name "$filesystem_name" --arg region "$region" \
			'{name: [$name], region_name: $region}')
		fs_name=$(api_request POST "/filesystems" "$create_fs_payload" | @jq@ -r '.data.name')
		if [[ -z "$fs_name" ]]; then
			log_error "Failed to create filesystem '$filesystem_name'." >&2
			exit 1
		fi
		log_info "Filesystem created with name: $fs_name"
	else
		log_info "Using existing filesystem '$fs_name'"
	fi

	log_info "Creating instance '$instance_name' ($instance_type_name) in region '$region' attached to filesystem '$fs_name'"

	local create_payload
	create_payload=$(jq -n --arg region "$region" --arg type "$instance_type_name" --arg name "$instance_name" --arg fs "$fs_name" \
		'{region_name: $region, instance_type_name: $type, ssh_key_names: ["aaron-mbp16"], name: $name, file_system_names: [$fs]}')

	local response
	response=$(api_request POST "/instance-operations/launch" "$create_payload")
	local instance_id
	instance_id=$(echo "$response" | @jq@ -r '.data.instance_ids[0]')

	if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
		log_info "Failed to launch instance." >&2
		log_debug "API Response: $response" >&2
		exit 1
	fi

	log_info "Instance launch initiated with ID: $instance_id. Waiting for IP address"

	local ip_address=""
	local status=""
	for i in {1..40}; do
		local instance_info
		instance_info=$(api_request GET "/instances" | @jq@ -r --arg id "$instance_id" '.data[] | select(.id == $id)')

		if [[ -z "$instance_info" ]]; then
			log_warn "Instance info not found in list yet. Waiting ($i/20)"
			sleep 30
			continue
		fi

		status=$(echo "$instance_info" | @jq@ -r '.status')
		ip_address=$(echo "$instance_info" | @jq@ -r '.ip // ""')

		if [[ "$status" == "active" && -n "$ip_address" && "$ip_address" != "null" ]]; then
			log_info "Instance is active!"
			break
		fi
		log_info "Current status: $status... ($i/20)"
		sleep 30
	done

	if [[ "$status" != "active" || -z "$ip_address" ]]; then
		log_error "Instance did not become active or failed to get IP address after 20 minutes." >&2
		exit 1
	fi

	log_info "Instance '$instance_name' created successfully."
	log_info "SSH Address: ${REMOTE_USER}@${ip_address}"
	log_info "Run: lambda connect $instance_name # To connect"
	log_info "Run: lambda setup $instance_name # To setup"
}

connect_instance() {
	ensure_api_key
	local instance_name="${1:-}"
	if [[ -z "$instance_name" ]]; then
		log_error "Instance name is required for connect." >&2
		log_info "Usage: lambda connect <instance_name>" >&2
		exit 1
	fi
	log_info "Looking for instance with name '$instance_name'"

	local instance_info
	instance_info=$(get_instance_by_exact_name "$instance_name")

	if [[ -z "$instance_info" ]]; then
		log_error "No instance found with name '$instance_name'." >&2
		# Suggest listing instances or checking the name
		# log_info "You can list running instances using 'lambda list' (if implemented)."
		exit 1
	fi

	# Check if the found instance is active
	local target_instance_status
	target_instance_status=$(echo "$instance_info" | @jq@ -r '.status')

	if [[ "$target_instance_status" != "active" ]]; then
		log_error "Instance '$instance_name' found, but it is not active (status: '$target_instance_status')." >&2
		exit 1
	fi

	local ip_address
	ip_address=$(echo "$instance_info" | @jq@ -r '.ip')

	if [[ -z "$ip_address" || "$ip_address" == "null" ]]; then
		log_error "Selected instance '$instance_name' is active but does not have an IP address yet. Please try again shortly." >&2
		exit 1
	fi

	log_info "Connecting to instance '$instance_name' (${ip_address})"
	@ssh@ -i "$SSH_KEY" "${REMOTE_USER}@${ip_address}"
}

delete_instance() {
	ensure_api_key
	local instance_name="$1"
	if [[ -z "$instance_name" ]]; then
		log_error "Instance name is required for delete." >&2
		log_info "Usage: lambda delete <instance_name>" >&2
		exit 1
	fi

	log_info "Looking for instance with name '$instance_name' to delete"
	local instance_info
	instance_info=$(get_instance_by_exact_name "$instance_name")

	if [[ -z "$instance_info" ]]; then
		log_error "No instance found with name '$instance_name'. Cannot delete." >&2
		exit 1
	fi

	local instance_id
	instance_id=$(echo "$instance_info" | @jq@ -r '.id')
	local instance_status
	instance_status=$(echo "$instance_info" | @jq@ -r '.status')

	log_warn "Found instance '$instance_name' (ID: $instance_id, Status: $instance_status). Proceeding with termination"

	local delete_payload
	delete_payload=$(jq -n --argjson ids "[\"$instance_id\"]" '{instance_ids: $ids}')

	local response
	response=$(api_request POST "/instance-operations/terminate" "$delete_payload")

	# Check the response - assuming success if the response contains the ID in terminated_instance_ids
	local terminated_id
	terminated_id=$(echo "$response" | @jq@ -r --arg id "$instance_id" '.data.terminated_instance_ids[]? | select(. == $id)')

	if [[ "$terminated_id" == "$instance_id" ]]; then
		log_info "Instance '$instance_name' (ID: $instance_id) termination initiated successfully."
	else
		log_error "Failed to initiate termination for instance '$instance_name' (ID: $instance_id)." >&2
		log_debug "API Response: $response" >&2
		exit 1
	fi
}

setup_instance() {
	ensure_api_key
	local instance_name="$1"
	if [[ -z "$instance_name" ]]; then
		log_error "Instance name is required for setup." >&2
		log_info "Usage: lambda setup <instance_name>" >&2
		exit 1
	fi

	log_info "Looking for instance with name '$instance_name'"
	local instance_info
	instance_info=$(get_instance_by_exact_name "$instance_name")

	if [[ -z "$instance_info" ]]; then
		log_error "No instance found with name '$instance_name'." >&2
		exit 1
	fi

	# Check if the found instance is active
	local target_instance_status
	target_instance_status=$(echo "$instance_info" | @jq@ -r '.status')
	if [[ "$target_instance_status" != "active" ]]; then
		log_error "Instance '$instance_name' found, but it is not active (status: '$target_instance_status'). Cannot setup." >&2
		exit 1
	fi

	local ip_address
	ip_address=$(echo "$instance_info" | @jq@ -r '.ip')

	if [[ -z "$ip_address" || "$ip_address" == "null" ]]; then
		log_error "Instance '$instance_name' is active but does not have an IP address. Cannot setup yet." >&2
		exit 1
	fi

	log_info "Preparing setup for instance '$instance_name' (${ip_address})"

	if ! @bw@ login --check --quiet; then
		log_error "Bitwarden vault is locked or not logged in. Please log in using 'bw login'." >&2
		exit 1
	fi

	local gh_token
	gh_token=$(@bw@ get notes pat-lambda)
	if [[ -z "$gh_token" ]]; then
		log_error "Failed to retrieve GITHUB_TOKEN (item 'pat-lambda' notes) from Bitwarden." >&2
		exit 1
	fi

	local remote_script_path="/tmp/setup_remote_${instance_name}.sh"
	local local_script_path
	local_script_path=$(mktemp)

	# Substitute variables in the template
	@sed@ \
		-e "s|#REMOTE_USER#|$REMOTE_USER|g" \
		-e "s|#REMOTE_PASSWORD#|$REMOTE_PASSWORD|g" \
		-e "s|#GH_TOKEN#|$gh_token|g" \
		@LAMBDA_SETUP_TEMPLATE@ >"$local_script_path"
	chmod +x "$local_script_path"
	log_debug "Remote script generated at $local_script_path"

	@scp@ -i "$SSH_KEY" "$HOME/bw.pass" "${REMOTE_USER}@${ip_address}:~/bw.pass"
	@scp@ -i "$SSH_KEY" "$HOME/.ssh/id_ed25519-github" "${REMOTE_USER}@${ip_address}:~/.ssh/id_ed25519-github"
	@scp@ -i "$SSH_KEY" "$BENTOML_HOME/.yatai.yaml" "${REMOTE_USER}@${ip_address}:~/.yatai.yaml"
	@scp@ -i "$SSH_KEY" "$local_script_path" "${REMOTE_USER}@${ip_address}:${remote_script_path}"

	log_info "Executing remote setup script on '$instance_name' This may take a while."
	# Use -t to allocate a pseudo-tty, which might help with interactive prompts if any occur (though shouldn't)
	@ssh@ -i "$SSH_KEY" -t "${REMOTE_USER}@${ip_address}" "INSTANCE_ID=${instance_name} bash ${remote_script_path}"

	log_info "Setup script finished execution on '$instance_name'."
	log_info "Cleaning up temporary files"

	log_info "Setup complete for instance '$instance_name'. You may need to reconnect to see all changes."
}

usage() {
	echo "Usage: lambda <command> [options]"
	echo
	echo "Commands:"
	echo "  create <gpus>x<type> [region]   Create a new Lambda Cloud instance (e.g., lambda create 1xA100 ${DEFAULT_REGION})"
	echo "                                     Requires LAMBDA_API_KEY env var."
	echo "  connect <instance_name>        Connect via SSH to the specified active instance."
	echo "                                     Requires LAMBDA_API_KEY env var."
	echo "  setup <instance_name>            Run the setup process on the specified active instance."
	echo "                                     Requires LAMBDA_API_KEY, Bitwarden CLI login, gh CLI."
	echo "  delete <instance_name>         Terminate the specified instance."
	echo "                                     Requires LAMBDA_API_KEY env var."
	echo "  help                           Show this help message."
}

main() {
	if [[ $# -eq 0 || "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
		usage
		exit 0
	fi

	local command="$1"
	shift

	case "$command" in
	create)
		if [[ $# -lt 1 ]]; then
			log_error "Missing instance specification for create." >&2
			usage
			exit 1
		fi
		create_instance "$@"
		;;
	connect)
		if [[ $# -lt 1 ]]; then
			log_error "Missing instance name for connect." >&2
			usage
			exit 1
		fi
		connect_instance "$@"
		;;
	setup)
		if [[ $# -lt 1 ]]; then
			log_error "Missing instance name for setup." >&2
			usage
			exit 1
		fi
		setup_instance "$@"
		;;
	delete)
		if [[ $# -lt 1 ]]; then
			log_error "Missing instance name for delete." >&2
			usage
			exit 1
		fi
		delete_instance "$@"
		;;
	*)
		log_error "Unknown command '$command'" >&2
		usage
		exit 1
		;;
	esac
}

main "$@"
