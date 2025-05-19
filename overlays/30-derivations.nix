final: prev: let
  lambdaVersion = let
    envVersion = builtins.getEnv "LAMBDA_VERSION";
  in
    if envVersion != ""
    then envVersion
    else prev.flakeVersion;
in {
  inherit (prev.callPackage ./packages/dix-tools {}) bootstrap gvim unicopy pinentry-touchid ubuntu-nvidia aws-credentials git-forest;
  zsh-dix = prev.callPackage ./packages/zsh-dix {};
  lambda = prev.callPackage ./packages/lambda {version = lambdaVersion;};
}
