{
  stdenv,
  jq,
  lib,
  runCommand,
  substituteInPlace,
  dix,
  makeWrapper,
  bash,
  bitwarden-cli,
}: let
  inherit (lib) getExe;
  pname = "aws-credentials";
  version = "0.0.1";

  scriptContent = ''
    #!${getExe bash}

    set -eo pipefail

    usage() {
      echo "Usage: ${pname} [profile]"
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

    @@bw@@ unlock --check &>/dev/null || export BW_SESSION=''${BW_SESSION:-"$(@@bw@@ unlock --passwordenv BW_MASTER --raw)"}

    ACCESS_KEY_ID=$(@@bw@@ get item aws-''${PROFILE}-access-key-id | @@jq@@ -r '.notes')
    SECRET_ACCESS_KEY=$(@@bw@@ get item aws-''${PROFILE}-secret-access-key | @@jq@@ -r '.notes')

    cat <<EOF
    {
      "Version": 1,
      "AccessKeyId": "$ACCESS_KEY_ID",
      "SecretAccessKey": "$SECRET_ACCESS_KEY",
    }
    EOF
  '';

  awsScript = runCommand pname
    {
      nativeBuildInputs = [substituteInPlace];
      meta.mainProgram = pname;
    }
    '''
      mkdir -p $out/bin
      echo "${scriptContent}" > $out/bin/${pname}
      chmod +x $out/bin/${pname}
      substituteInPlace $out/bin/${pname} \
        --replace '@@bw@@' '${getExe bitwarden-cli}' \
        --replace '@@jq@@' '${getExe jq}'
    ''';
in
  stdenv.mkDerivation rec {
    inherit pname version;

    src = awsScript;

    strictDeps = true;
    nativeBuildInputs = [makeWrapper];
    buildInputs = [bash jq bitwarden-cli];

    installPhase = ''
      mkdir -p $out/bin
      ln -s $src/bin/${pname} $out/bin/${pname}
    '';

    postFixup = ''
      wrapProgram $out/bin/${pname} \
        --prefix PATH : "${lib.makeBinPath [bitwarden-cli bash jq]}"
    '';

    meta = with lib; {
      mainProgram = "${pname}";
      description = "AWS credentials retriever";
      homepage = "https://github.com/aarnphm/dix";
      license = licenses.asl20;
      maintainers = with maintainers; [aarnphm];
      platforms = platforms.unix;
    };
  }
