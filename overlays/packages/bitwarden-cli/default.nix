{
  stdenv,
  lib,
  runCommand,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_18,
  python311,
  darwin,
  xcbuild,
  installShellFiles,
}:
buildNpmPackage rec {
  pname = "bitwarden-cli";
  version = "2024.7.1";

  src = fetchFromGitHub {
    owner = "bitwarden";
    repo = "clients";
    rev = "cli-v${version}";
    hash = "sha256-ZnqvqPR1Xuf6huhD5kWlnu4XOAWn7yte3qxgU/HPhiQ=";
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
      xcbuild.xcrun
    ];

  makeCacheWritable = true;

  npmDepsHash = "sha256-lWlAc0ITSp7WwxM09umBo6qeRzjq4pJdC0RDUrZwcHY=";
  npmBuildScript = "build:oss:prod";
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
