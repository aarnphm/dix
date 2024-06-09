self: super:
let
  isArm = with import ./helpers.nix; checkArm super;
in
{
  installDmg = { name, appname ? name, version, src, description, homepage, postInstall ? "", sourceRoot ? ".", ... }:
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

  dix = super.dix or { } //
    {
      OrbStack =
        let
          arch = if isArm then "arm64" else "amd64";
        in
        self.installDmg rec {
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

              installShellCompletion --zsh --cmd orbctl <($out/bin/orbctl completion zsh)
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

      Bitwarden = with super;
        let
          description = "A secure and free password manager for all of your devices";
          electron = electron_28;
          version = "2024.5.0";
          pname = "Bitwarden";
        in
        with super; buildNpmPackage rec {
          inherit pname version;

          src = fetchFromGitHub {
            owner = "bitwarden";
            repo = "clients";
            rev = "desktop-v${version}";
            # hash = "sha256-UzVzo8tq719W2EwUE4NfvUrqhb61fvd60EGkavQmv3Q=";
          };
          patches = [
            ./electron-builder-package-lock.patch
          ];

          # The nested package-lock.json from upstream is out-of-date, so copy the
          # lock metadata from the root package-lock.json.
          postPatch = ''
            cat {,apps/desktop/src/}package-lock.json \
              | ${lib.getExe jq} -s '
                .[1].packages."".dependencies.argon2 = .[0].packages."".dependencies.argon2
                  | .[0].packages."" = .[1].packages.""
                  | .[1].packages = .[0].packages
                  | .[1]
                ' \
              | ${moreutils}/bin/sponge apps/desktop/src/package-lock.json
          '';

          nodejs = nodejs_18;

          makeCacheWritable = true;
          npmFlags = [ "--legacy-peer-deps" ];
          npmWorkspace = "apps/desktop";
          # npmDepsHash = "sha256-qkg1psct/ekIXB6QmJX1n/UOKUhYSD9Su7t/b4/4miM=";

          cargoDeps = rustPlatform.fetchCargoTarball {
            name = "${pname}-${version}";
            inherit src;
            patches = map
              (patch: runCommand
                (builtins.baseNameOf patch)
                { nativeBuildInputs = [ patchutils_0_4_2 ]; }
                ''
                  < ${patch} filterdiff -p1 --include=${lib.escapeShellArg cargoRoot}'/*' > $out
                ''
              )
              patches;
            patchFlags = [ "-p4" ];
            sourceRoot = "${src.name}/${cargoRoot}";
            hash = lib.fakeSha256;
          };
          cargoRoot = "apps/desktop/desktop_native";

          env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

          nativeBuildInputs = [
            cargo
            copyDesktopItems
            jq
            makeWrapper
            moreutils
            napi-rs-cli
            pkg-config
            python3
            rustc
            rustPlatform.cargoCheckHook
            rustPlatform.cargoSetupHook
          ];

          buildInputs = [
            glib
            gtk3
            libsecret
          ];

          preBuild = ''
            if [[ $(jq --raw-output '.devDependencies.electron' < package.json | grep -E --only-matching '^[0-9]+') != ${lib.escapeShellArg (lib.versions.major electron.version)} ]]; then
              echo 'ERROR: electron version mismatch'
              exit 1
            fi
          '';

          postBuild = ''
            pushd apps/desktop

            ls -rthla && exit 1

            # desktop_native/index.js loads a file of that name regarldess of the libc being used
            mv desktop_native/desktop_native.* desktop_native/desktop_native.linux-x64-musl.node

            npm exec electron-builder -- \
              --dir \
              -c.electronDist=${electron}/libexec/electron \
              -c.electronVersion=${electron.version}

            popd
          '';

          doCheck = false;

          # nativeCheckInputs = [
          #   dbus
          #   (gnome.gnome-keyring.override { useWrappedDaemon = false; })
          # ];
          #
          # checkFlags = [
          #   "--skip=password::password::tests::test"
          # ];
          #
          # checkPhase = ''
          #   runHook preCheck
          #
          #   pushd ${cargoRoot}
          #   export HOME=$(mktemp -d)
          #   export -f cargoCheckHook runHook _eval _callImplicitHook
          #   export cargoCheckType=release
          #   dbus-run-session \
          #     --config-file=${dbus}/share/dbus-1/session.conf \
          #     -- bash -e -c cargoCheckHook
          #   popd
          #
          #   runHook postCheck
          # '';

          installPhase = ''
            runHook preInstall

            mkdir $out

            pushd apps/desktop/dist/linux-unpacked
            mkdir -p $out/opt/Bitwarden
            cp -r locales resources{,.pak} $out/opt/Bitwarden
            popd

            makeWrapper '${electron}/bin/electron' "$out/bin/bitwarden" \
              --add-flags $out/opt/Bitwarden/resources/app.asar \
              --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
              --set-default ELECTRON_IS_DEV 0 \
              --inherit-argv0

            pushd apps/desktop/resources/icons
            for icon in *.png; do
              dir=$out/share/icons/hicolor/"''${icon%.png}"/apps
              mkdir -p "$dir"
              cp "$icon" "$dir"/${icon}.png
            done
            popd

            runHook postInstall
          '';

          meta = {
            changelog = "https://github.com/bitwarden/clients/releases/tag/${src.rev}";
            inherit description;
            homepage = "https://bitwarden.com";
            license = lib.licenses.gpl3;
            platforms = lib.platforms.darwin;
            mainProgram = "bitwarden";
          };
        };

      Discord = self.installDmg rec {
        name = "Discord";
        version = "0.0.306";
        sourceRoot = "${name}.app";
        src = super.fetchurl {
          url = "https://dl.discordapp.net/apps/osx/${version}/${name}.dmg";
          hash = "sha256-bcB//LqJ4pKUSJQj3LFWqbeeCzRHMbYbQvsPNaOiTOE=";
        };
        description = "GROUP CHAT. THAT’S ALL FUN GAMES";
        homepage = "https://discord.com/";
        postInstall = ''
          find $out/Applications/${name}.app/Contents/Frameworks -d -type d -iname "*.app" | while read -r dir; do
            /usr/bin/codesign --remove-signature "$dir"
            codesign --sign - "$dir"
          done
        '';
      };

      pinentry-touchid = super.stdenv.mkDerivation (finalAttrs: {
        pname = "pinentry-touchid";
        version = "0.0.3";

        src = super.fetchurl {
          url = "https://github.com/jorgelbg/pinentry-touchid/releases/download/v${finalAttrs.version}/pinentry-touchid_${finalAttrs.version}_macos_${if isArm then "arm64" else "amd64"}.tar.gz";
          sha256 = "sha256-bxwkoC6DbORe6uQCeFMoqYngq6ZKsjrj7SUdgmm9d3I=";
        };
        sourceRoot = ".";

        buildInputs = with super; [ unzip ];
        unpackCmd = ''
          unzip $curSrc pinentry-touchid
        '';
        installPhase = ''
          ls -rthla
          mkdir -p $out/bin
          cp pinentry-touchid $out/bin/
        '';

        meta = {
          description = "Pinentry TouchID for Mac";
          license = super.lib.licenses.asl20;
          homepage = "https://github.com/jorgelbg/pinentry-touchid";
          platforms = super.lib.platforms.darwin;
          mainProgram = "pinentry-touchid";
        };
      });
    };
}

