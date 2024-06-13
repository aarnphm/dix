{
  installDmg,
  isArm,
  fetchurl,
  lib,
}: let
  arch =
    if isArm
    then "arm64"
    else "amd64";
in
  installDmg rec {
    name = "OrbStack";
    version = "1.6.1_17010";
    sourceRoot = "${name}.app";

    src = fetchurl {
      url = "https://cdn-updates.orbstack.dev/${arch}/${name}_v${version}_${arch}.dmg";
      hash =
        if isArm
        then "sha256-0ZhP1EA+8BOaCuXG5QYcdqopIcWmzHkT9HtVGzJKGFo="
        else lib.fakeSha256;
    };

    homepage = "https://orbstack.dev/";
    description = "Fast, light, powerful way to run containers";

    postInstall = let
      contentPath = "$out/Applications/${name}.app/Contents";
      appPath = "${contentPath}/MacOS";
      binPath = "$out/bin";
      installBin = bin: ''
        ln -fs ${appPath}/xbin/${bin} ${binPath}/${bin}
      '';
    in
      lib.concatStringsSep "\n" [
        "mkdir -p ${binPath}"
        (installBin "docker")
        (installBin "docker-credential-osxkeychain")
        (installBin "docker-buildx")
        (installBin "docker-compose")
        (installBin "docker-buildx")
        (installBin "kubectl")
        "ln -fs ${appPath}/scli ${binPath}/orbctl"
        "ln -fs ${appPath}/scli ${binPath}/orb"
      ];
  }
