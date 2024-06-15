{
  writeShellApplication,
  apt,
  runCommand,
}:
writeShellApplication rec {
  name = "ubuntu-nvidia";
  runtimeInputs = [
    apt
    (runCommand "ubuntuDriverHost" {} ''
      mkdir -p $out/bin
      ln -s /usr/bin/ubuntu-drivers $out/bin
    '')
  ];
  text = ''
    if ! command -v ubuntu-drivers &>/dev/null; then
      echo "This derivation is designed to be run on Ubuntu only."
      exit 1
    fi

    if [ $# -ne 1 ]; then
      AVAILABLE_DRIVERS=$(ubuntu-drivers list)

      echo ""
      echo "Usage: ${name} <driver_name>"
      echo ""
      echo "Available drivers:"
      echo ""
      echo "$AVAILABLE_DRIVERS"
      exit 1
    fi

    DEBUG="''${DEBUG:-false}"

    # check if DEBUG is set, then use set -x, otherwise ignore
    if [ "$DEBUG" = true ]; then
      set -x
      echo "running path: $0"
    fi

    DRIVER_NAME="nvidia-driver-$1"
    DRIVER_PACKAGE="nvidia:$1"
    UTILS_PACKAGE="nvidia-utils-$1"

    # Use ubuntu-drivers to find the appropriate driver package
    NVIDIA_PACKAGE="$(ubuntu-drivers devices | grep "$DRIVER_NAME" | awk '{print $3}')"

    if [ -z "$NVIDIA_PACKAGE" ]; then
      echo "Error: Driver '$DRIVER_NAME' not found."
      exit 1
    fi

    # Check if the driver name contains "-server"
    if [[ "$DRIVER_NAME" == *"-server"* ]]; then
      GPGPU_FLAG="--gpgpu"
    else
      GPGPU_FLAG=""
    fi

    # Install the NVIDIA driver package using apt
    sudo ubuntu-drivers install "$GPGPU_FLAG" "$DRIVER_PACKAGE"
    sudo apt update && sudo apt install -y "$UTILS_PACKAGE"

    echo "NVIDIA driver '$DRIVER_NAME' has been installed."
    echo "Please reboot your system for the changes to take effect."
  '';
}
