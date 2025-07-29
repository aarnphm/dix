{
  writeProgram,
  writeShellApplication,
  lib,
  fetchurl,
  isArm,
  makeWrapper,
  flakeVersion,
  runCommand,
  coreutils,
  gh,
  unzip,
  stdenv,
  neovide,
  xclip,
  bash,
  nix,
  git,
  jq,
  bitwarden-cli,
  apt,
  perl,
  perl540Packages,
  pkg-config,
  installShellFiles,
}: let
  inherit (lib) getExe makeBinPath;
  version = flakeVersion;
in {
  aws-credentials =
    writeProgram "aws-credentials" rec {
      inherit version;
      pname = "aws-credentials";
      replacements = {
        inherit (stdenv) shell;
        inherit pname;
        bw = getExe bitwarden-cli;
        jq = getExe jq;
      };
    }
    ./aws-credentials.sh;

  bootstrap =
    writeProgram "bootstrap" {
      inherit version;
      replacements = {
        inherit (stdenv) shell;
        FLAKE_URI_BASE = "github:aarnphm/detachtools";
      };
    }
    ./bootstrap.sh;

  git-forest = stdenv.mkDerivation (finalAttrs: {
    pname = "git-forest";
    version = flakeVersion;

    src = ./git-forest;

    nativeBuildInputs = [makeWrapper pkg-config];
    buildInputs = [perl git];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp ${finalAttrs.src} $out/bin/git-forest
      chmod +x $out/bin/git-forest
      wrapProgram $out/bin/git-forest \
        --prefix PATH : ${makeBinPath [git perl]} \
        --prefix PERL5LIB : "${with perl540Packages; makePerlPath [Git Error]}"

      runHook postInstall
    '';

    meta = {
      description = "git-forest, nicer way to see commit-history tree";
      homepage = "https://github.com/aarnphm/detachtools";
      maintainers = with lib.maintainers; [aarnphm];
      platforms = lib.platforms.unix;
    };
  });

  gvim =
    writeProgram "gvim" {
      inherit version;
      replacements = {
        inherit (stdenv) shell;
        neovide = getExe neovide;
      };
    }
    ./gvim.sh;

  unicopy =
    writeProgram "unicopy" {
      inherit version;
      replacements = {
        inherit (stdenv) shell;
        xclip = getExe xclip;
        pbcopy = getExe (
          runCommand "impureHostDarwinCopy"
          {
            meta = {mainProgram = "pbcopy";};
          }
          ''
            mkdir -p $out/bin
            ln -s /usr/bin/pbcopy $out/bin
          ''
        );
      };
      meta = {
        mainProgram = "unicopy";
        description = "copy with a twist";
        homepage = "https://github.com/aarnphm/detachtools";
        license = lib.licenses.asl20;
        maintainers = with lib.maintainers; [aarnphm];
      };
    }
    ./copy.sh;

  pinentry-touchid = stdenv.mkDerivation (finalAttrs: {
    version = "0.0.3";
    name = "pinentry-touchid";

    src = fetchurl {
      url = "https://github.com/jorgelbg/pinentry-touchid/releases/download/v${finalAttrs.version}/pinentry-touchid_${finalAttrs.version}_macos_${
        if isArm
        then "arm64"
        else "amd64"
      }.tar.gz";
      sha256 = "sha256-bxwkoC6DbORe6uQCeFMoqYngq6ZKsjrj7SUdgmm9d3I=";
    };
    sourceRoot = ".";

    buildInputs = [unzip];
    unpackCmd = ''
      unzip $curSrc pinentry-touchid
    '';
    installPhase = ''
      ls -rthla
      mkdir -p $out/bin
      cp pinentry-touchid $out/bin/
    '';

    meta = with lib; {
      description = "Pinentry TouchID for Mac";
      license = licenses.asl20;
      homepage = "https://github.com/jorgelbg/pinentry-touchid";
      platforms = platforms.darwin;
      mainProgram = "pinentry-touchid";
    };
  });

  nebius = stdenv.mkDerivation (finalAttrs: let
    pname = "nebius";
    version = "0.12.89";
    os =
      if stdenv.isDarwin
      then "darwin"
      else "linux";
    arch =
      if stdenv.hostPlatform.isAarch64
      then "arm64"
      else "x86_64";
  in {
    inherit pname version;

    src = fetchurl {
      url = "https://storage.eu-north1.nebius.cloud/cli/release/${version}/${os}/${arch}/${pname}";
      sha256 = "sha256-5L/ZjUa/7VmECU3RowsW4DCErLzc0QYp/CnpZK8UJtM="; # lib.fakeSha256;
    };

    dontUnpack = true;

    nativeBuildInputs = [installShellFiles];

    installPhase =
      ''
        runHook preInstall
        install -Dm755 $src $out/bin/${pname}
      ''
      + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
        installShellCompletion --cmd ${pname} \
          --bash <($out/bin/${pname} completion bash) \
          --fish <($out/bin/${pname} completion fish) \
          --zsh <($out/bin/${pname} completion zsh)
      ''
      + ''
        runHook postInstall
      '';

    meta = with lib; {
      description = "Nebius CLI";
      homepage = "https://nebius.ai";
      license = licenses.asl20;
      maintainers = with maintainers; [aarnphm];
      platforms = platforms.unix;
      mainProgram = pname;
    };
  });

  ubuntu-nvidia = writeShellApplication rec {
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
  };
}
