{
  stdenv,
  lib,
  runCommand,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_18,
  python311,
  darwin,
  installShellFiles,
}:
buildNpmPackage rec {
  pname = "bitwarden-cli";
  version = "2024.4.1";

  src = fetchFromGitHub {
    owner = "bitwarden";
    repo = "clients";
    rev = "cli-v${version}";
    hash = "sha256-Dz7EActqXd97kNxEaNINj2O6TLZWEgHHg1lOIa2+Lt4=";
  };

  nodejs = nodejs_18;

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  nativeBuildInputs =
    [
      python311
      installShellFiles
    ]
    ++ lib.optionals stdenv.isDarwin [
      darwin.cctools
      (runCommand "xcrunHost" {} ''
        mkdir -p $out/bin
        ln -s /usr/bin/xcrun $out/bin
      '')
    ];

  makeCacheWritable = true;

  npmDepsHash = "sha256-fjYez3nSDsG5kYtrun3CkDCz1GNAjNlwPzEL+/9qQRU=";
  npmBuildScript = "build:prod";
  npmWorkspace = "apps/cli";
  npmFlags = ["--legacy-peer-deps"];

  postInstall = ''
    installShellCompletion --zsh --name _bw <($out/bin/bw completion --shell zsh)
  '';

  meta = with lib; {
    mainProgram = "bw";
    changelog = "https://github.com/bitwarden/clients/releases/tag/${src.rev}";
    description = "A secure and free password manager for all of your devices";
    homepage = "https://bitwarden.com";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [aarnphm];
    platforms = platforms.unix;
  };
}
