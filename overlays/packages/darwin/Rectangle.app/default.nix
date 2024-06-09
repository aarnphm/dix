{ installDmg, fetchurl }:
installDmg rec {
  name = "Rectangle";
  version = "0.80";
  sourceRoot = "${name}.app";
  src = fetchurl {
    url = "https://github.com/rxhanson/Rectangle/releases/download/v${version}/${name}${version}.dmg";
    hash = "sha256-CmYhMnEhn3UK82RXuT1KQhAoK/0ewcUU6h73el2Lpw8=";
  };
  description = "Move and resize windows in macOS using keyboard shortcuts or snap areas";
  homepage = "https://rectangleapp.com/";
}
