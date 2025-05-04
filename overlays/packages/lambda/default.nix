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

  preBuild = ''
    go mod tidy
    go mod vendor
  '';
  # buildPhase = ''
  #   runHook preBuild
  #
  #   runHook postBuild
  # '';
  # installPhase = ''
  #   runHook preInstall
  #
  #   install -Dm555 ${pname} $out/bin/${pname}
  #
  #   runHook postInstall
  # '';

  postFixup = ''
    wrapProgram $out/bin/${pname} \
      --prefix PATH : "${lib.makeBinPath buildInputs}"
  '';

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd ${pname} \
      --bash <($out/bin/${pname} completion bash) \
      --fish <($out/bin/${pname} completion fish) \
      --zsh <($out/bin/${pname} completion zsh)
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
