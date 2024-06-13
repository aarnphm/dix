{
  installDmg,
  fetchurl,
  isArm,
}:
installDmg rec {
  name = "Zed Preview";
  version = "0.139.3";
  sourceRoot = "${name}.app";
  src = fetchurl {
    url = "https://zed.dev/api/releases/preview/${version}/Zed-${
      if isArm
      then "aarch64"
      else "x86_64"
    }.dmg";
    hash = "sha256-66h6v0a5A/yLBnC5QWOTsSggImh02/xZ+TmxsRPqHt4=";
  };
  description = "Zed - Code at the speed of thoughts";
  homepage = "https://zed.dev/";
  postInstall = ''
    mkdir -p $out/bin
    ln -sf "$out/Applications/${name}.app/Contents/MacOS/zed" $out/bin/zed-preview
  '';
}
