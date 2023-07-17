{ pkgs, stdenv, fetchurl }:

let
  toGoKernel = platform:
    if platform.isDarwin then "darwin"
    else platform.parsed.kernel.name;
  hashes = {
    # Use `print-hashes.sh ${version}` to generate the list below
    # https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/development/compilers/go/print-hashes.sh
    darwin-amd64 = "777025500f62d14bb5a4923072cd97431887961d24de08433a60c2fe1120531d";
    darwin-arm64 = "32864d6fe888714ca7b421b5997269c7f6349d7e2675c3a399133e521787608b";
    linux-386 = "1420582fb43a15dbe94760fdd92171315414c4afc21ffe9d3b5875f9386ebe53";
    linux-amd64 = "5a9ebcc65c1cce56e0d2dc616aff4c4cedcfbda8cc6f0288cc08cda3b18dcbf1";
    linux-arm64 = "17700b6e5108e2a2c3b1a43cd865d3f9c66b7f1c5f0cec26d3672cc131cc0994";
    linux-armv6l = "ee8550213c62812f90dbfd3d098195adedd450379fd4d3bb2c85607fd5a2d283";
    linux-ppc64le = "bccbf89c83e0aab2911e57217159bf0fc49bb07c6eebd2c23ae30af18fc5368b";
    linux-s390x = "4460deffbc01fe5f31fe226d296e366c0d6059b280743aea49bf81ab62ab8be8";
  };

  toGoCPU = platform: {
    "i686" = "386";
    "x86_64" = "amd64";
    "aarch64" = "arm64";
    "armv6l" = "armv6l";
    "armv7l" = "armv6l";
    "powerpc64le" = "ppc64le";
  }.${platform.parsed.cpu.name} or (throw "Unsupported CPU ${platform.parsed.cpu.name}");

  version = "1.20";

  toGoPlatform = platform: "${toGoKernel platform}-${toGoCPU platform}";

  platform = toGoPlatform stdenv.hostPlatform;
in
stdenv.mkDerivation {
  pname = "go";
  version = version;
  src = fetchurl {
    url = "https://golang.org/dl/go${version}.${platform}.tar.gz";
    sha256 = hashes.${platform} or (throw "Missing Go bootstrap hash for platform ${platform}");
  };
  builder = ./go-install.sh;
  system = builtins.currentSystem;
}
