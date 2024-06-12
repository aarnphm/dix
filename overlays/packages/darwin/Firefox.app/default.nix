{ installDmg, fetchurl }:
installDmg rec {
  name = "Firefox";
  version = "127.0";
  sourceRoot = "Firefox.app";
  src = fetchurl {
    name = "${name}-${version}.dmg";
    url = "https://download-installer.cdn.mozilla.net/pub/firefox/releases/${version}/mac/en-US/${name}%20${version}.dmg";
    hash = "sha256-PDDLyK4q0NxErDKiZshxvQhmyiwodrRkyGGTrl/+bm0=";
  };
  postInstall = ''
    mkdir -p $out/bin
    ln -fs $out/Applications/${name}.app/Content/MacOS/firefox $out/bin/firefox
  '';
  description = "The Firefox web browser";
  homepage = "https://www.mozilla.org/en-US/firefox/";
}
