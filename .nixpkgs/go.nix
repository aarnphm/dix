{ pkgs, stdenv, fetchurl }:

let
  toGoKernel = platform:
    if platform.isDarwin then "darwin"
    else platform.parsed.kernel.name;
  hashes = {
    # Use `print-hashes.sh ${version}` to generate the list below
    # https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/development/compilers/go/print-hashes.sh
    darwin-amd64 = "1f5f539ce0baa8b65f196ee219abf73a7d9cf558ba9128cc0fe4833da18b04f2";
    darwin-arm64 = "6c7df9a2405f09aa9bab55c93c9c4ce41d3e58127d626bc1825ba5d0a0045d5c";
    linux-386 = "956b01369102eae9f2b714616056c3576c707ce401f41b60385db2595edafbb1";
    linux-amd64 = "e54bec97a1a5d230fc2f9ad0880fcbabb5888f30ed9666eca4a91c5a32e86cbc";
    linux-arm64 = "fc4ad28d0501eaa9c9d6190de3888c9d44d8b5fb02183ce4ae93713f67b8a35b";
    linux-armv6l = "570dc8df875b274981eaeabe228d0774985de42e533ffc8c7ff0c9a55174f697";
    linux-ppc64le = "7d1791ec63cda9b41ca5990477236142ffab9b86cc30d99f50bd8c4598406b30";
    linux-s390x = "6646779524f2ce630efd8a55a29993591f763bb717011f16146b3e9bae7bba17";

  };

  toGoCPU = platform: {
    "i686" = "386";
    "x86_64" = "amd64";
    "aarch64" = "arm64";
    "armv6l" = "armv6l";
    "armv7l" = "armv6l";
    "powerpc64le" = "ppc64le";
  }.${platform.parsed.cpu.name} or (throw "Unsupported CPU ${platform.parsed.cpu.name}");

  version = "1.18.2";

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
