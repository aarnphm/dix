self: super:
{
  dix = super.dix or { } //
    {
      OrbStack = super.callPackage (import ./packages/darwin/OrbStack.app) { };

      Rectangle = super.callPackage (import ./packages/darwin/Rectangle.app) { };

      Discord = super.callPackage (import ./packages/darwin/Discord.app) { };

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

    };
}

