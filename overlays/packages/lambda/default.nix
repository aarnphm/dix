{
  lib,
  stdenv,
  buildGoModule,
  installShellFiles,
  openssh,
  gh,
  version ? "0.0.0",
  ...
}:
buildGoModule rec {
  pname = "lm";
  inherit version;

  src = ./.;

  ldflags = ["-s" "-w" "-X main.version=${version}"];

  vendorHash = null;

  nativeBuildInputs = [installShellFiles];

  proxyVendor = true;

  buildInputs = [
    openssh
    gh
  ];

  passthru = {
    inherit version;
  };

  postInstall =
    ''
      mkdir -p $out/bin
      install -Dm755 $GOPATH/bin/lambda $out/bin/${pname}
    ''
    + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd ${pname} \
        --bash <($out/bin/${pname} completion bash) \
        --fish <($out/bin/${pname} completion fish) \
        --zsh <($out/bin/${pname} completion zsh)
    '';

  meta = with lib; {
    description = "Lambda Cloud operations tool";
    homepage = "https://github.com/aarnphm/detachtools";
    license = licenses.asl20;
    maintainers = with maintainers; [aarnphm];
    platforms = platforms.unix;
  };
}
