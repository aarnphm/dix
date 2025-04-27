{
  stdenv,
  lib,
  runCommand,
  substituteInPlace,
  bash,
  coreutils,
  xclip,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "unicopy";
  version = "0.0.1";
  inherit (lib) getExe;

  pbcopyDarwin = runCommand "impureHostDarwinCopy" {meta.mainProgram = "pbcopy";} ''\
    mkdir -p $out/bin
    ln -s /usr/bin/pbcopy $out/bin
  '';

  scriptContent = ''
    #!${getExe bash}
    set -e
    set -o pipefail

    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
      case "$(uname -s)" in
        Linux*)
          @@xclip@@ -selection clipboard
          ;;
        Darwin*)
          @@pbcopy@@
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
          @@xclip@@ -selection clipboard
          ;;
        Darwin*)
          @@pbcopy@@
          ;;
        *)
          echo "Unsupported operating system." >&2
          return 1
          ;;
      esac
    fi
  '';

  unicopyScript = runCommand "copy" {
    nativeBuildInputs = [substituteInPlace];
    meta.mainProgram = "copy";
  } ''
    mkdir -p $out/bin
    echo "${scriptContent}" > $out/bin/copy
    chmod +x $out/bin/copy
    substituteInPlace $out/bin/copy \
      --replace '@@xclip@@' '${getExe xclip}' \
      --replace '@@pbcopy@@' '${getExe pbcopyDarwin}'
  '';

  src = unicopyScript;

  strictDeps = true;
  buildInputs = [bash coreutils xclip];

  unpackPhase = "true";

  installPhase = ''
    mkdir -p $out/bin
    ln -s $src/bin/copy $out/bin/copy
  '';

  meta = {
    mainProgram = "copy";
    description = "copy, but universal";
    homepage = "https://github.com/aarnphm/dix";
    maintainers = with lib.maintainers; [aarnphm];
    platforms = lib.platforms.unix;
  };
})
