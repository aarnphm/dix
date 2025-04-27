self: super: {
  flakeVersion = input: "${builtins.substring 0 8 (input.lastModifiedDate or input.lastModified or "19700101")}.${input.shortRev or "dirty"}";

  upgraded = selfPkg: superPkg:
    if builtins.compareVersions superPkg.version selfPkg.version < 1
    then selfPkg
    else (builtins.trace "note: upgrade ${selfPkg.name} < ${superPkg.name}, ignoring." superPkg);

  outdated = selfPkg: superPkg:
    if builtins.compareVersions superPkg.version selfPkg.version < 1
    then selfPkg
    else (builtins.trace "note: ${selfPkg.name} override is outdated!" selfPkg);

  isArm = builtins.match "aarch64-.*" super.stdenv.hostPlatform.system != null;

  writeProgram = name: env: src:
    super.runCommand name env ''
      export PATH=${super.lib.makeBinPath [super.coreutils super.gnused]}:$PATH
      dst=$out/bin/${name}
      mkdir -p $(dirname $dst)
      substitute ${src} $dst --subst-var-by SHELL ${super.stdenv.shell} ${builtins.concatStringsSep " " (super.lib.mapAttrsToList (n: v: "--subst-var-by '${n}' '${toString v}'") env)}
      chmod +x $dst
    '';

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
    with super;
      stdenv.mkDerivation {
        name = "${name}-${version}";
        version = "${version}";
        src = src;
        buildInputs = [unzip];
        nativeBuildInputs = [installShellFiles] ++ nativeBuildInputs;
        sourceRoot = sourceRoot;
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
        postInstall = postInstall;
        meta = with self.lib; {
          homepage = homepage;
          description = description;
          maintainers = with maintainers; [aarnphm];
          platforms = platforms.darwin;
        };
      };

  mkDerivationKeepSrc = {
    name,
    src,
    version,
  }:
    with super;
      stdenv.mkDerivation {
        inherit name src version;
        buildCommand = ''
          mkdir -p $out
          cp -a $src/. $out
        '';
        meta = {description = name;};
      };
}
