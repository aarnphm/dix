self: super: {
  dix = super.recurseIntoAttrs (super.dix or {});

  zed-editor =
    if super.stdenv.isDarwin
    then null
    else super.recurseIntoAttrs super.zed-editor;

  julia_19 =
    if super.stdenv.isDarwin
    then null
    else super.recurseIntoAttrs super.julia_19;

  bitwarden-cli =
    if super.stdenv.isDarwin
    then
      super.bitwarden-cli.overrideAttrs (
        oldAttrs: {
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [super.llvmPackages_18.stdenv.cc];
          stdenv = super.llvmPackages_18.stdenv;
        }
      )
    else super.recurseIntoAttrs super.bitwarden-cli;
}
