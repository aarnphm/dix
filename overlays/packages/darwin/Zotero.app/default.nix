{ installDmg, fetchurl }:
installDmg rec {
  name = "Zotero";
  version = "6.0.37";
  sourceRoot = "${name}.app";
  src = fetchurl {
    name = "${name}-${version}.dmg";
    url = "https://www.zotero.org/download/client/dl?channel=release&platform=mac&version=${version}";
    hash = "sha256-sFDwp3YSLBFMIrp+8OBDDFJKj7GJ3WjMc2J2EqPRQNU=";
  };
  description = ''
    Zotero is a free, easy-to-use tool to help you collect, organize, cite,
    and share your research sources
  '';
  homepage = "https://www.zotero.org";
}
