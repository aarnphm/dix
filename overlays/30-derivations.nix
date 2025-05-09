self: super: {
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
      lambda = super.callPackage ./packages/lambda {};
      bootstrap = super.callPackage ./packages/bootstrap {};
    };
}
