#! @shell@

set -eo pipefail

usage() {
	echo "Usage: @pname@ [profile]"
	echo
	echo "Note: profile will be used to be retrieved from bitwarden aws-{profile}-...."
}

# Check if no options are passed
if [ $# -eq 0 ]; then
	usage
	exit 1
fi

if [ $# -gt 1 ]; then
	echo "Error: Too many arguments provided."
	usage
	exit 1
fi

# Assign the profile argument to a variable
PROFILE="$1"

@bw@ unlock --check &>/dev/null || export BW_SESSION=${BW_SESSION:-"$(@bw@ unlock --passwordenv BW_MASTER --raw)"}

ACCESS_KEY_ID=$(@bw@ get item aws-${PROFILE}-access-key-id | @jq@ -r '.notes')
SECRET_ACCESS_KEY=$(@bw@ get item aws-${PROFILE}-secret-access-key | @jq@ -r '.notes')

cat <<EOF
{
  "Version": 1,
  "AccessKeyId": "$ACCESS_KEY_ID",
  "SecretAccessKey": "$SECRET_ACCESS_KEY",
}
EOF
