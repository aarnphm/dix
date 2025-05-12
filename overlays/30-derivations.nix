self: super: let
  lambdaVersion = let
    envVersion = builtins.getEnv "LAMBDA_VERSION";
    fallbackVersion = "0.0.0-dev";
  in
    if envVersion != ""
    then envVersion
    else fallbackVersion;
in {
  dix =
    super.dix
    or {}
    // {
      aws-credentials = super.callPackage ./packages/aws-credentials {};
      ubuntu-nvidia = super.callPackage ./packages/ubuntu-nvidia {};
      unicopy = super.callPackage ./packages/unicopy {};
      git-forest = super.callPackage ./packages/git-forest {};
      zsh-dix = super.callPackage ./packages/zsh-dix {};
      pinentry-touchid = super.callPackage ./packages/pinentry-touchid {};
      gvim = super.callPackage ./packages/gvim {};
      lambda = super.callPackage ./packages/lambda {
        version = lambdaVersion;
      };
      bootstrap = super.callPackage ./packages/bootstrap {};
    };
}
