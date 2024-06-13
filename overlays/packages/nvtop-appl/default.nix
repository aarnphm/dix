{
  stdenv,
  lib,
  fetchFromGitHub,
  cmake,
  ncurses,
  udev,
  darwin,
}:
stdenv.mkDerivation rec {
  pname = "nvtop-appl";
  version = "3.1.0";

  src = fetchFromGitHub {
    owner = "Syllo";
    repo = "nvtop";
    rev = version;
    hash = "sha256-MkkBY2PR6FZnmRMqv9MWqwPWRgixfkUQW5TWJtHEzwA=";
  };

  nativeBuildInputs = [cmake];
  buildInputs =
    [ncurses udev]
    ++ (with darwin.apple_sdk.frameworks; [
      MetalKit
      IOKit
      Quartz
    ]);
  cmakeFlags = [
    "-DAPPLE_SUPPORT=ON"
  ];

  doCheck = true;

  meta = with lib; {
    mainProgram = "nvtop";
    description = "GPU & Accelerator process monitoring for AMD, Apple, Huawei, Intel, NVIDIA and Qualcomm";
    homepage = "https://github.com/Syllo/nvtop";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [aarnphm];
    platforms = platforms.darwin;
  };
}
