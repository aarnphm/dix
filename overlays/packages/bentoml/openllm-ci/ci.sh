#! @shell@

set -eo pipefail

usage() {
  echo "Usage: @pname@ [--pr <pr_number> | --head] [--debug]"
  echo
  echo "Options:"
  echo "  --pr <pr_number>    Checkout the specified pull request using gh cli"
  echo "  --head              Switch to the main branch of the repository"
  echo "  --help | -h         Show this help message"
  echo
  echo "Note: --pr and --head are mutually exclusive."
}

# Check if no options are passed
if [ $# -eq 0 ]; then
  usage
  exit 1
fi

DEBUG=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --pr)
      PR_NUMBER="$2"
      shift 2
      ;;
    --head)
      HEAD=true
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    --debug)
      DEBUG=true
      shift
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [ "$DEBUG" = true ]; then
  set -x
  echo "running path: $0"
fi

# Ensure that --pr and --head are mutually exclusive
if [[ -n "${PR_NUMBER:-}" && "${HEAD:-}" = true ]]; then
  echo "Error: --pr and --head are mutually exclusive"
  exit 1
fi

@gh@ auth status &>/dev/null || (
  echo "gh is not setup correctly; run gh auth login first then try again"
  exit 1
)

# Check if the openllm directory exists, clone if it doesn't
@coreutils@/bin/mkdir -p "$HOME/workspace"
OPENLLM_DIR=$HOME/workspace/openllm

if [ ! -d "$OPENLLM_DIR" ]; then
  echo "OpenLLM directory does not exist. Cloning the repository..."
  @gh@ repo clone bentoml/OpenLLM "$OPENLLM_DIR"
fi

pushd "$OPENLLM_DIR" 2>/dev/null

# Checkout the specified PR or switch to the main branch
if [[ -n "${PR_NUMBER:-}" ]]; then
  @gh@ pr checkout "$PR_NUMBER"
elif [[ "${HEAD:-}" = true ]]; then
  @git@ switch main
fi

@shell@ "$OPENLLM_DIR/local.sh"
source "$OPENLLM_DIR/.venv/bin/activate"

@hatch@ run tests:python

popd 2>/dev/null
