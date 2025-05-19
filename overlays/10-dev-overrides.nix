final: prev: {
  flakeVersion = (
    if (final ? lastModifiedDate && final ? rev) # Check rev to see if we are on a clean commit
    then
      (
        let
          year = builtins.substring 0 4 final.lastModifiedDate;
          month = builtins.substring 4 2 final.lastModifiedDate;
          day = builtins.substring 6 2 final.lastModifiedDate;
        in "unstable-${year}-${month}-${day}"
      )
    else "dirty"
  );

  upgraded = selfPkg: superPkg:
    if builtins.compareVersions superPkg.version selfPkg.version < 1
    then selfPkg
    else (builtins.trace "note: upgrade ${selfPkg.name} < ${superPkg.name}, ignoring." superPkg);

  outdated = selfPkg: superPkg:
    if builtins.compareVersions superPkg.version selfPkg.version < 1
    then selfPkg
    else (builtins.trace "note: ${selfPkg.name} override is outdated!" selfPkg);

  isArm = builtins.match "aarch64-.*" prev.stdenv.hostPlatform.system != null;

  concatStringsSepNewLine = iterables: prev.lib.concatStringsSep "\n" iterables;

  writeProgram = name: env: src:
    prev.replaceVarsWith ({
        inherit name src;
        dir = "bin";
        isExecutable = true;
        meta.mainProgram = name;
      }
      // env);

  installDmg = {
    name,
    appname ? name,
    version,
    src,
    description,
    homepage,
    nativeBuildInputs ? [],
    postInstall ? "",
    sourceRoot ? ".",
    ...
  }:
    with prev;
      stdenv.mkDerivation {
        inherit src sourceRoot postInstall;
        name = "${name}-${version}";
        version = "${version}";
        buildInputs = [unzip];
        nativeBuildInputs = [installShellFiles] ++ nativeBuildInputs;
        phases = ["unpackPhase" "installPhase"];
        unpackCmd = ''
          echo "File to unpack: $curSrc"
          echo "Current source: $(ls -rthla $curSrc)"
          if ! [[ "$curSrc" =~ \.dmg$ ]]; then return 1; fi
          mnt=$(mktemp -d -t ci-XXXXXXXXXX)

          function finish {
            echo "Detaching $mnt"
            /usr/bin/hdiutil detach $mnt -force
            rm -rf $mnt
          }
          trap finish EXIT

          echo "Attaching $mnt"
          /usr/bin/hdiutil attach -nobrowse -readonly $src -mountpoint $mnt

          echo "What's in the mount dir"?
          ls -la $mnt/

          echo "Copying contents"
          shopt -s extglob
          DEST="$PWD"
          (cd "$mnt"; cp -a !(Applications) "$DEST/")
        '';
        installPhase = ''
          runHook preInstall

          mkdir -p "$out/Applications/${appname}.app"
          cp -pR * "$out/Applications/${appname}.app"

          runHook postInstall
        '';
        meta = with final.lib; {
          inherit homepage description;
          maintainers = with maintainers; [aarnphm];
          platforms = platforms.darwin;
        };
      };

  mkDerivationKeepSrc = {
    name,
    src,
    version,
  }:
    with prev;
      stdenv.mkDerivation {
        inherit name src version;
        buildCommand = ''
          mkdir -p $out
          cp -a $src/. $out
        '';
        meta = {description = name;};
      };
}
