{
  lib,
  stdenv,
  buildGoModule,
  makeWrapper,
  installShellFiles,
  bitwarden-cli,
  openssh,
  gh,
}:
buildGoModule rec {
  pname = "lambda";
  version = "0.1.0";

  src = ./.;

  ldflags = ["-s" "-w"];

  vendorHash = null;

  nativeBuildInputs = [makeWrapper installShellFiles];

  proxyVendor = true;

  buildInputs = [
    bitwarden-cli
    openssh
    gh
  ];

  postInstall =
    ''
      mkdir -p $out/bin
      install -Dm755 $GOPATH/bin/${pname} $out/bin/${pname}
      install -Dm755 $GOPATH/bin/${pname} $out/bin/lm
    ''
    + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd ${pname} \
        --bash <($out/bin/${pname} completion bash) \
        --fish <($out/bin/${pname} completion fish) \
        --zsh <($out/bin/${pname} completion zsh)

      installShellCompletion --cmd lm \
        --bash <($out/bin/lm completion bash) \
        --fish <($out/bin/lm completion fish) \
        --zsh <($out/bin/lm completion zsh)
    '';

  meta = with lib; {
    mainProgram = pname;
    description = "Lambda Cloud operations tool";
    homepage = "https://github.com/aarnphm/dix";
    license = licenses.asl20;
    maintainers = with maintainers; [aarnphm];
    platforms = platforms.unix;
  };
}
