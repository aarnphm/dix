{ stdenv, fetchurl, unzip, lib, isArm }:
stdenv.mkDerivation (finalAttrs: {
  pname = "pinentry-touchid";
  version = "0.0.3";

  src = fetchurl {
    url = "https://github.com/jorgelbg/pinentry-touchid/releases/download/v${finalAttrs.version}/pinentry-touchid_${finalAttrs.version}_macos_${if isArm then "arm64" else "amd64"}.tar.gz";
    sha256 = "sha256-bxwkoC6DbORe6uQCeFMoqYngq6ZKsjrj7SUdgmm9d3I=";
  };
  sourceRoot = ".";

  buildInputs = [ unzip ];
  unpackCmd = ''
    unzip $curSrc pinentry-touchid
  '';
  installPhase = ''
    ls -rthla
    mkdir -p $out/bin
    cp pinentry-touchid $out/bin/
  '';

  meta = with lib; {
    description = "Pinentry TouchID for Mac";
    license = licenses.asl20;
    homepage = "https://github.com/jorgelbg/pinentry-touchid";
    platforms = platforms.darwin;
    mainProgram = "pinentry-touchid";
  };
})
