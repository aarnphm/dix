#! @shell@
set -e
set -o pipefail

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
  case "$(uname -s)" in
    Linux*)
      @xclip@ -selection clipboard
      ;;
    Darwin*)
      @pbcopy@
      ;;
    *)
      # Fallback to storing in a temporary file
      tmp_file=$(mktemp)
      cat >"$tmp_file"
      echo "Copied contents to $tmp_file"
      ;;
  esac
else
  # Running locally
  case "$(uname -s)" in
    Linux*)
      @xclip@ -selection clipboard
      ;;
    Darwin*)
      @pbcopy@
      ;;
    *)
      echo "Unsupported operating system." >&2
      return 1
      ;;
  esac
fi
