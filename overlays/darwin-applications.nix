self: super:
let
  isArm = builtins.match "aarch64-.*" super.stdenv.hostPlatform.system != null;
  arch = if isArm then "arm64" else "amd64";
in
{
  installDmg =
    { name
    , appname ? name
    , version
    , src
    , description
    , homepage
    , postInstall ? ""
    , sourceRoot ? "."
    , ...
    }:
      with super; stdenv.mkDerivation {
        name = "${name}-${version}";
        version = "${version}";
        src = src;
        buildInputs = with super; [ unzip ];
        sourceRoot = sourceRoot;
        phases = [ "unpackPhase" "installPhase" ];
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
          mkdir -p "$out/Applications/${appname}.app"
          cp -pR * "$out/Applications/${appname}.app"
        '';
        postInstall = postInstall;
        meta = with self.lib; {
          description = description;
          homepage = homepage;
          maintainers = with maintainers; [ aarnphm ];
          platforms = platforms.darwin;
        };
      };

  OrbStack = self.installDmg rec {
    name = "OrbStack";
    version = "1.6.1_17010";
    sourceRoot = "${name}.app";
    src = super.fetchurl {
      url = "https://cdn-updates.orbstack.dev/${arch}/${name}_v${version}_${arch}.dmg";
      hash = if isArm then "sha256-0ZhP1EA+8BOaCuXG5QYcdqopIcWmzHkT9HtVGzJKGFo=" else "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    description = "Fast, light, powerful way to run containers";
    homepage = "https://orbstack.dev/";
    postInstall =
      let
        contentPath = "$out/Applications/${name}.app/Contents";
        appPath = "${contentPath}/MacOS";
        binPath = "$out/bin";
        installBin = bin: ''
          install -Dm755 ${appPath}/xbin/${bin} ${binPath}/${bin}
        '';
      in
      ''
        ${installBin "docker"}
        ${installBin "docker-credential-osxkeychain"}
        ${installBin "docker-buildx"}
        ${installBin "docker-compose"}
        ${installBin "kubectl"}

        install -Dm755 ${appPath}/scli ${binPath}/orb
        install -Dm755 ${appPath}/scli ${binPath}/orbctl
      '';
  };

  Rectangle = self.installDmg rec {
    name = "Rectangle";
    version = "0.80";
    sourceRoot = "${name}.app";
    src = super.fetchurl {
      url = "https://github.com/rxhanson/Rectangle/releases/download/v${version}/${name}${version}.dmg";
      hash = "sha256-CmYhMnEhn3UK82RXuT1KQhAoK/0ewcUU6h73el2Lpw8=";
    };
    description = "Move and resize windows in macOS using keyboard shortcuts or snap areas";
    homepage = "https://rectangleapp.com/";
  };
}

