{ installDmg, fetchurl, lib }:
installDmg rec {
  name = "Arc";
  version = "1.46.0-50665";
  sourceRoot = "${name}.app";

  src = fetchurl {
    url = "https://releases.arc.net/release/${name}-${version}.dmg";
    hash = "sha256-k1guZWLeA9obSYRPSKObGhYYjRKxPBQ0wtAGSU2REjA=";
  };

  homepage = "https://arc.net/";
  description = "Arc, from the Browser Company";
}

