{ installDmg, runCommand, fetchurl }:
installDmg rec {
  name = "Discord";
  version = "0.0.306";
  sourceRoot = "${name}.app";
  src = fetchurl {
    url = "https://dl.discordapp.net/apps/osx/${version}/${name}.dmg";
    hash = "sha256-bcB//LqJ4pKUSJQj3LFWqbeeCzRHMbYbQvsPNaOiTOE=";
  };
  nativeBuildInputs = [
    (runCommand "codesignHost" { } ''
      mkdir -p $out/bin
      ln -s /usr/bin/codesign $out/bin
    '')
  ];
  description = "GROUP CHAT. THAT’S ALL FUN GAMES";
  homepage = "https://discord.com/";
  postInstall = ''
    find $out/Applications/${name}.app/Contents/Frameworks -d -type d -iname "*.app" | while read -r dir; do
      codesign --remove-signature "$dir"
      codesign --sign - "$dir"
    done
  '';
}
